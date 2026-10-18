defmodule Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags do
  @moduledoc """
  Canonical, mode-scoped status calculation selections.

  Source identities include empty selections and explicitly unavailable rows,
  so an absent calculated producer cannot silently look like a live-only effect.
  Runtime catalogs use the normal database overlay and cache boundaries.
  Overlay rows are complete records: `available` and `scripted` must be booleans.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects

  @typedoc "A validated calculation flag retaining its database spelling."
  @type flag :: String.t()

  @flags ~w(None Base MaxHp MaxSp Str Agi Vit Int Dex Luk Batk Watk Matk Hit Flee
    Def Def2 Mdef Mdef2 Speed Aspd Dspd Cri Flee2 Atk_Ele Def_Ele Mode Size Race
    Range Regen MaxAp Pow Sta Wis Spl Con Crt Patk Smatk Res Mres Hplus Crate Dye)
  @all_flags List.delete(@flags, "Dye")
  @engine_only ~w(sc_arcane_charge sc_riding sc_falcon sc_gangsterparadise
    sc_guild_aura_source sc_intimidate sc_soulchange_marker sc_devoted_by)
  @aliases %{
    "sc_gospel" => ["sc_gospel_slow"],
    "sc_basilica" => ["sc_basilica_buff", "sc_basilica_caster"],
    "sc_fortune" => ["sc_fortunekiss"],
    "sc_service4u" => ["sc_serviceforyou"],
    "sc_assncros" => ["sc_assncross"],
    "sc_battleorders" => ["sc_battleorder"],
    "sc_leadership" => ["sc_gd_leadership"],
    "sc_soulcold" => ["sc_gd_soulcold"],
    "sc_glorywounds" => ["sc_gd_glorywounds"],
    "sc_hawkeyes" => ["sc_gd_hawkeyes"],
    "sc_autocounter" => ["sc_auto_counter"]
  }

  @doc "Returns the full calculation vocabulary selected by All, including Base but not Dye."
  @spec all() :: [flag()]
  def all, do: @all_flags

  @doc "Returns the selection for a committed apply, removal or armed transition."
  @spec for_event(atom(), :apply | :removed | :armed) :: [flag()]
  def for_event(:sc_intravision, :removed), do: ["All"]

  def for_event(:sc_magicpower, :armed) do
    if GameMode.mode() == :pre_renewal, do: selection(:sc_magicpower), else: []
  end

  def for_event(_id, :armed), do: []
  def for_event(id, event) when event in [:apply, :removed], do: selection(id)

  @doc "Whether the active catalog admits a source status on a monster."
  @spec monster_eligible?(atom()) :: boolean()
  def monster_eligible?(id) when id in [:sc_arcane_charge, :sc_riding], do: false

  def monster_eligible?(id) do
    case Map.get(index(), Atom.to_string(id)) do
      nil -> true
      row -> row["available"] and not row["scripted"]
    end
  end

  @doc "Reloads and validates the active mode's calculation catalog."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(__MODULE__, load())
    :ok
  end

  @doc "Validates selections and complete identity coverage for supplied definitions."
  @spec build_index!([map()], [map()]) :: %{String.t() => [flag()]}
  def build_index!(rows, definitions) do
    selections =
      Map.new(rows, fn row ->
        id = Map.fetch!(row, "id")

        unless is_binary(id) and String.starts_with?(id, "sc_"),
          do: raise(ArgumentError, "invalid status identity #{inspect(id)}")

        flags = row |> Map.fetch!("flags") |> Map.new(&{&1, true}) |> normalize_flags!()

        unless is_boolean(row["available"]) and is_boolean(row["scripted"]),
          do: raise(ArgumentError, "invalid status admission facts for #{id}")

        {id, flags}
      end)

    Enum.each(definitions, fn definition ->
      id = Atom.to_string(definition.id)

      unless id in @engine_only or :mob not in definition.target_types or
               Map.has_key?(selections, id),
             do: raise(ArgumentError, "missing monster status classification #{id}")
    end)

    selections
  end

  @doc "Checks that each explicit identity override has a source row."
  @spec validate_aliases!([String.t()]) :: :ok
  def validate_aliases!(ids) do
    for source <- Map.keys(@aliases),
        source not in ids,
        do: raise(ArgumentError, "unresolved status override #{source}")

    :ok
  end

  defp selection(id) do
    case Map.get(index(), Atom.to_string(id)) do
      nil -> []
      row -> Map.fetch!(row, "flags")
    end
  end

  defp index do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        loaded = load()
        :persistent_term.put(__MODULE__, loaded)
        loaded

      loaded ->
        loaded
    end
  end

  defp load do
    rows =
      DataLoader.load("status_calc_flags.yml", "status_calc_flags_v1.etf", fn sources ->
        sources |> Enum.flat_map(&DataLoader.parse_file/1) |> DataLoader.merge_by_key(& &1["id"])
      end)

    selections = build_index!(rows, Enum.map(Effects.all(), & &1.metadata()))

    Map.new(rows, fn row ->
      {row["id"], Map.put(row, "flags", Map.fetch!(selections, row["id"]))}
    end)
  end

  @doc "Returns the canonical identity and explicit split/renamed runtime identities."
  @spec ids_for_source(String.t()) :: [String.t()]
  def ids_for_source(name) when is_binary(name) and name != "" do
    id = "sc_" <> String.downcase(name)
    [id | Map.get(@aliases, id, [])]
  end

  @doc "Normalizes enabled flags, including an All selection's explicit exclusions."
  @spec normalize_flags!(map()) :: [flag()]
  def normalize_flags!(flags) when is_map(flags) do
    flags =
      Map.new(flags, fn {name, enabled} ->
        canonical =
          if is_binary(name),
            do: Enum.find(["All" | @flags], &(String.downcase(&1) == String.downcase(name)))

        unless not is_nil(canonical) and is_boolean(enabled),
          do: raise(ArgumentError, "invalid status calculation flag #{inspect({name, enabled})}")

        {canonical, enabled}
      end)

    initial = if flags["All"] == true, do: MapSet.new(@all_flags), else: MapSet.new()

    selected =
      flags
      |> Map.delete("All")
      |> Enum.reduce(initial, fn
        {name, true}, selected -> MapSet.put(selected, name)
        {name, false}, selected -> MapSet.delete(selected, name)
      end)

    if selected == MapSet.new(@all_flags), do: ["All"], else: Enum.sort(selected)
  end
end
