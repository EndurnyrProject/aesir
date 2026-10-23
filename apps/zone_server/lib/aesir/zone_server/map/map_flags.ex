defmodule Aesir.ZoneServer.Map.MapFlags do
  @moduledoc """
  General per-map flag layer.

  Static per-map flags are loaded once into `:persistent_term` from
  `Aesir.ZoneServer.Mmo.Woe.CastleDb` (every castle map carries
  `gvg_castle`, `nosave`, `noteleport`, `nowarp`, and `noreturn`) and
  `StaticFlags` (per-map PvP flags from `priv/db/map_flags.yml`, and the GvG,
  castle, GvG dungeon, battleground and skill-restriction (`noskill`,
  `noteleport`, `nowarp`, `noicewall`) flags imported from the mode's mapflag
  scripts, whose restricted zones `zone/1` reads) and
  `PortalAccess` (mode-scoped memo and job-entry flags), plus a
  small runtime ETS overlay (`:map_flag_overrides`) carries flags toggled at
  runtime (WoE's `gvg`). `get/2` merges overlay over static; `reload/0`
  rebuilds the static index after the castle or flag data changes.

  Valued flags live beside them: `invincible_time/1` reads the per-map player
  invincible time from the mode-scoped `map_invincible_time.yml`, loaded on
  first use and again after `reload/0`.

  The overlay also carries the global agit state (`set_agit/1`), so the
  derived predicates `versus?/1` and `gvg?/1` can count a castle as a siege
  map only while WoE runs.

  Only `@flags` are accepted. The WoE-consumed subset (`gvg`, `gvg_castle`,
  `nosave`, `noteleport`, `nowarp`, `noreturn`) drives behavior this phase;
  `pvp`, `pvp_noparty`, and `pvp_noguild` are consumed by the targeting layer to
  resolve player-versus-player hostility; `nomobloot` and `nomvploot` suppress a
  dead monster's ordinary and MVP drop pools; `noskill`, `noteleport`, `nowarp`
  and `noicewall` refuse a player's skill request; and any other atom is
  rejected so typos stay inert.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Map.MapFlags.StaticFlags
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @pt_key __MODULE__
  @invincible_key {__MODULE__, :invincible_time}
  @zone_key {__MODULE__, :zone}

  @typedoc """
  A map flag. The WoE set drives castle behavior; the PvP set drives
  player-versus-player hostility. `:nochat` forbids creating chat rooms on the map.
  """
  @type flag ::
          :gvg
          | :gvg_castle
          | :nosave
          | :noteleport
          | :nowarp
          | :noreturn
          | :pvp
          | :pvp_noparty
          | :pvp_noguild
          | :nochat
          | :nomemo
          | :nowarpto
          | :gvg_te
          | :gvg_te_castle
          | :nomobloot
          | :nomvploot
          | :gvg_dungeon
          | :battleground
          | :noskill
          | :noicewall
  @type map_name :: String.t()

  @flags [
    :gvg,
    :gvg_castle,
    :nosave,
    :noteleport,
    :nowarp,
    :noreturn,
    :pvp,
    :pvp_noparty,
    :pvp_noguild,
    :nochat,
    :nomemo,
    :nowarpto,
    :gvg_te,
    :gvg_te_castle,
    :nomobloot,
    :nomvploot,
    :gvg_dungeon,
    :battleground,
    :noskill,
    :noicewall
  ]
  @static_woe_flags [:gvg_castle, :nosave, :noteleport, :nowarp, :noreturn]

  @doc """
  Returns the canonical set of accepted map flags.

  Exposed for `StaticFlags` so the YAML loader validates against the same
  `@flags` whitelist the runtime overlay enforces — one source only.
  """
  @spec whitelist() :: [flag()]
  def whitelist, do: @flags

  @doc """
  Rebuilds the static `:persistent_term` index from `CastleDb` and
  `StaticFlags`.
  """
  @spec reload() :: :ok
  def reload do
    PortalAccess.reload()
    :persistent_term.put(@pt_key, build_static())
    :persistent_term.erase(@invincible_key)
    :persistent_term.erase(@zone_key)
    :ok
  end

  @doc """
  Returns the map's restricted-zone mask: bit `1 << (n + 4)` for each
  `restricted <n>` zone the mapflag scripts give it, `0` for none.
  """
  @spec zone(map_name()) :: non_neg_integer()
  def zone(map_name) do
    @zone_key
    |> :persistent_term.get(nil)
    |> case do
      nil ->
        zones = StaticFlags.load_zones()
        :persistent_term.put(@zone_key, zones)
        zones

      zones ->
        zones
    end
    |> Map.get(map_name, 0)
  end

  @doc """
  Returns the player invincible time the map sets, in milliseconds, or `nil`
  when the map sets none.
  """
  @spec invincible_time(map_name()) :: non_neg_integer() | nil
  def invincible_time(map_name) do
    @invincible_key
    |> :persistent_term.get(nil)
    |> case do
      nil ->
        times = load_invincible_times()
        :persistent_term.put(@invincible_key, times)
        times

      times ->
        times
    end
    |> Map.get(map_name)
  end

  @doc """
  Returns whether `flag` is set on `map_name`.

  A runtime overlay entry wins over the static value; unset flags are `false`.
  """
  @spec get(map_name(), flag()) :: boolean()
  def get(map_name, flag) when flag in @flags do
    case :ets.lookup(overlay_table(), {map_name, flag}) do
      [{_, value}] -> value
      [] -> static(map_name, flag)
    end
  end

  def get(_map_name, _flag), do: false

  @doc """
  Sets a runtime overlay flag. WoE toggles `:gvg` here.
  """
  @spec set_runtime(map_name(), flag(), boolean()) :: :ok
  def set_runtime(map_name, flag, value) when flag in @flags do
    previous = get(map_name, flag)
    :ets.insert(overlay_table(), {{map_name, flag}, value})
    notify_gvg_transition(map_name, flag, previous, get(map_name, flag))
    :ok
  end

  def set_runtime(_map_name, _flag, _value), do: :ok

  @doc """
  Clears a runtime overlay flag, reverting to the static value.
  """
  @spec clear_runtime(map_name(), flag()) :: :ok
  def clear_runtime(map_name, flag) when flag in @flags do
    previous = get(map_name, flag)
    :ets.delete(overlay_table(), {map_name, flag})
    notify_gvg_transition(map_name, flag, previous, get(map_name, flag))
    :ok
  end

  def clear_runtime(_map_name, _flag), do: :ok

  @doc "Records whether the agit (War of Emperium) window is running."
  @spec set_agit(boolean()) :: :ok
  def set_agit(active?) when is_boolean(active?) do
    :ets.insert(overlay_table(), {:agit, active?})
    :ok
  end

  @doc "Whether the agit (War of Emperium) window is running."
  @spec agit?() :: boolean()
  def agit? do
    case :ets.lookup(overlay_table(), :agit) do
      [{:agit, active?}] -> active?
      [] -> false
    end
  end

  @doc """
  Whether players may hit each other on `map_name`: a PvP or GvG map, or a
  castle while the agit runs.
  """
  @spec versus?(map_name()) :: boolean()
  def versus?(map_name), do: get(map_name, :pvp) or gvg?(map_name)

  @doc "Whether `map_name` is a GvG map: the `gvg` flag, or a castle while the agit runs."
  @spec gvg?(map_name()) :: boolean()
  def gvg?(map_name), do: get(map_name, :gvg) or (agit?() and get(map_name, :gvg_castle))

  @doc """
  Whether `map_name` is versus ground whether or not the agit runs: a PvP,
  GvG, GvG dungeon, castle or battleground map.
  """
  @spec vs2?(map_name()) :: boolean()
  def vs2?(map_name) do
    Enum.any?(
      [:pvp, :gvg_dungeon, :gvg, :gvg_castle, :gvg_te, :gvg_te_castle, :battleground],
      &get(map_name, &1)
    )
  end

  @doc "Whether `map_name` is a GvG map or castle, either kind, whether or not the agit runs."
  @spec gvg2?(map_name()) :: boolean()
  def gvg2?(map_name), do: gvg2_no_te?(map_name) or gvg2_te?(map_name)

  @doc "Whether `map_name` is a War of Emperium TE map or castle."
  @spec gvg2_te?(map_name()) :: boolean()
  def gvg2_te?(map_name), do: get(map_name, :gvg_te) or get(map_name, :gvg_te_castle)

  @doc "Whether `map_name` is a GvG map or castle outside War of Emperium TE."
  @spec gvg2_no_te?(map_name()) :: boolean()
  def gvg2_no_te?(map_name), do: get(map_name, :gvg) or get(map_name, :gvg_castle)

  @doc """
  Merged view of a map's known flags: static flags overlaid by runtime values.
  """
  @spec flags(map_name()) :: %{flag() => boolean()}
  def flags(map_name) do
    overlay =
      :ets.match_object(overlay_table(), {{map_name, :_}, :_})
      |> Map.new(fn {{_map, flag}, value} -> {flag, value} end)

    Map.merge(static(map_name), overlay)
  end

  @spec static(map_name()) :: %{flag() => true}
  defp static(map_name), do: Map.get(static_index(), map_name, %{})

  defp static(map_name, flag) do
    case static(map_name) do
      %{^flag => true} -> true
      _ -> false
    end
  end

  @spec build_static() :: %{map_name() => %{flag() => true}}
  defp build_static do
    castle_flags =
      Map.new(CastleDb.all(), fn castle ->
        {castle.map, Map.new(@static_woe_flags, fn flag -> {flag, true} end)}
      end)

    Map.merge(
      castle_flags,
      Map.merge(PortalAccess.map_flags(), StaticFlags.load(), fn _map, access, extra ->
        Map.merge(access, extra)
      end),
      fn _map, woe, extra -> Map.merge(woe, extra) end
    )
  end

  @spec load_invincible_times() :: %{map_name() => non_neg_integer()}
  defp load_invincible_times do
    "map_invincible_time.yml"
    |> Source.sources()
    |> Enum.flat_map(&YamlElixir.read_from_file!/1)
    |> DataLoader.merge_by_key(& &1["map"])
    |> Map.new(&invincible_time_row!/1)
  end

  defp invincible_time_row!(%{"map" => map_name, "time" => time})
       when is_binary(map_name) and is_integer(time) and time >= 0,
       do: {map_name, time}

  defp invincible_time_row!(row),
    do: raise(ArgumentError, "invalid map_invincible_time.yml row: #{inspect(row)}")

  @spec static_index() :: %{map_name() => %{flag() => true}}
  defp static_index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build_static()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  defp notify_gvg_transition(map_name, :gvg, previous, current) when previous != current do
    UnitRegistry.list_players()
    |> Enum.each(fn player_id ->
      case UnitRegistry.get_unit(:player, player_id) do
        {:ok, {_module, %PlayerState{map_name: ^map_name}, pid}} when is_pid(pid) ->
          PlayerSession.recalculate_stats(pid, false)

        _other ->
          :ok
      end
    end)
  end

  defp notify_gvg_transition(_map_name, _flag, _previous, _current), do: :ok

  @spec overlay_table() :: :ets.tid()
  defp overlay_table, do: table_for(:map_flag_overrides)
end
