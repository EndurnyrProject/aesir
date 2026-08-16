defmodule Aesir.ZoneServer.Map.MapFlags do
  @moduledoc """
  General per-map flag layer.

  Static per-map flags are loaded once into `:persistent_term` from
  `Aesir.ZoneServer.Mmo.Woe.CastleDb` — every castle map carries
  `gvg_castle`, `nosave`, `noteleport`, `nowarp`, and `noreturn` — and a
  small runtime ETS overlay (`:map_flag_overrides`) carries flags toggled at
  runtime (WoE's `gvg`). `get/2` merges overlay over static; `reload/0`
  rebuilds the static index after the castle data changes.

  Only `@flags` are accepted. The WoE-consumed subset (`gvg`, `gvg_castle`,
  `nosave`, `noteleport`, `nowarp`, `noreturn`) drives behavior this phase;
  `pvp` is stored but unconsumed, and any other atom is rejected so typos
  stay inert.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @pt_key __MODULE__

  @typedoc "A map flag. Only the WoE set is behaviorally meaningful."
  @type flag :: :gvg | :gvg_castle | :nosave | :noteleport | :nowarp | :noreturn | :pvp
  @type map_name :: String.t()

  @flags [:gvg, :gvg_castle, :nosave, :noteleport, :nowarp, :noreturn, :pvp]
  @static_woe_flags [:gvg_castle, :nosave, :noteleport, :nowarp, :noreturn]

  @doc """
  Rebuilds the static `:persistent_term` index from `CastleDb`.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build_static())
    :ok
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
    :ets.insert(overlay_table(), {{map_name, flag}, value})
    :ok
  end

  def set_runtime(_map_name, _flag, _value), do: :ok

  @doc """
  Clears a runtime overlay flag, reverting to the static value.
  """
  @spec clear_runtime(map_name(), flag()) :: :ok
  def clear_runtime(map_name, flag) when flag in @flags do
    :ets.delete(overlay_table(), {map_name, flag})
    :ok
  end

  def clear_runtime(_map_name, _flag), do: :ok

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
    Map.new(CastleDb.all(), fn castle ->
      {castle.map, Map.new(@static_woe_flags, fn flag -> {flag, true} end)}
    end)
  end

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

  @spec overlay_table() :: :ets.tid()
  defp overlay_table, do: table_for(:map_flag_overrides)
end
