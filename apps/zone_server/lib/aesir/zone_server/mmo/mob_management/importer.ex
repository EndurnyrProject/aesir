defmodule Aesir.ZoneServer.Mmo.MobManagement.Importer do
  @moduledoc """
  Maps a parsed rAthena `mob_db` entry (string-keyed map, CamelCase keys) into a
  `MobDefinition`. Used by the one-time `mix aesir.import.mobs` task; not on any
  runtime path.

  Modes come from three sources, unioned and deduped: `Class: Boss` (`:boss`),
  an explicit `Modes.Aggressive` flag (`:aggressive`), and the mode set derived
  from the `Ai` value via `MobMode`. `MvpExp` and `MvpDrops` are parsed onto
  `mvp_exp`/`mvp_drops` and stay strictly separate from the normal `drops`
  list. `RaceGroups`, resistances and `DamageTaken` are still dropped - they
  have no consumer yet.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode

  @sizes %{"small" => :small, "medium" => :medium, "large" => :large}

  @races %{
    "formless" => :formless,
    "undead" => :undead,
    "brute" => :brute,
    "plant" => :plant,
    "insect" => :insect,
    "fish" => :fish,
    "demon" => :demon,
    "demihuman" => :demi_human,
    "angel" => :angel,
    "dragon" => :dragon,
    "player" => :player,
    "player_human" => :player,
    "player_doram" => :player
  }

  @elements %{
    "neutral" => :neutral,
    "water" => :water,
    "earth" => :earth,
    "fire" => :fire,
    "wind" => :wind,
    "poison" => :poison,
    "holy" => :holy,
    # rAthena's "Dark" (ELE_DARK, index 7) is what the rest of the codebase
    # calls :shadow (see MobState.extract_element_type/1).
    "dark" => :shadow,
    "ghost" => :ghost,
    "undead" => :undead
  }

  @always [:id, :aegis_name, :name]
  @defaults Map.from_struct(struct(MobDefinition, %{}))

  @spec to_yaml_map(MobDefinition.t()) :: map()
  def to_yaml_map(%MobDefinition{element: {element, level}} = definition) do
    definition
    |> Map.from_struct()
    |> Map.delete(:element)
    |> Enum.filter(fn {field, value} ->
      field in @always or value != Map.fetch!(@defaults, field)
    end)
    |> Map.new(fn {field, value} -> {Atom.to_string(field), encode_value(field, value)} end)
    |> Map.put("element", Atom.to_string(element))
    |> Map.put("element_level", level)
  end

  @spec encode_value(atom(), term()) :: term()
  defp encode_value(field, value) when field in [:size, :race], do: Atom.to_string(value)
  defp encode_value(:modes, value), do: Enum.map(value, &Atom.to_string/1)
  defp encode_value(:stats, value), do: Map.new(value, fn {k, v} -> {Atom.to_string(k), v} end)

  defp encode_value(field, value) when field in [:drops, :mvp_drops],
    do: Enum.map(value, &drop_to_map/1)

  defp encode_value(_field, value), do: value

  @spec drop_to_map(MobDrop.t()) :: map()
  defp drop_to_map(%MobDrop{} = drop) do
    drop
    |> Map.from_struct()
    |> Enum.reject(fn {k, v} -> is_nil(v) or (k == :steal_protected and v == false) end)
    |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)
  end

  @spec to_definition(map()) :: {:ok, MobDefinition.t()} | {:error, term()}
  def to_definition(entry) do
    with {:ok, size} <- fetch_enum(@sizes, Map.get(entry, "Size", "Small"), :unknown_size),
         {:ok, race} <- fetch_enum(@races, Map.get(entry, "Race", "Formless"), :unknown_race),
         {:ok, element} <-
           fetch_enum(@elements, Map.get(entry, "Element", "Neutral"), :unknown_element) do
      {:ok,
       %MobDefinition{
         id: Map.fetch!(entry, "Id"),
         aegis_name: Map.fetch!(entry, "AegisName"),
         name: Map.fetch!(entry, "Name"),
         level: Map.get(entry, "Level", 1),
         hp: Map.get(entry, "Hp", 1),
         sp: Map.get(entry, "Sp", 0),
         base_exp: Map.get(entry, "BaseExp", 0),
         job_exp: Map.get(entry, "JobExp", 0),
         atk: Map.get(entry, "Attack", 0),
         matk: Map.get(entry, "Attack2", 0),
         def: Map.get(entry, "Defense", 0),
         mdef: Map.get(entry, "MagicDefense", 0),
         stats: parse_stats(entry),
         attack_range: Map.get(entry, "AttackRange", 0),
         skill_range: Map.get(entry, "SkillRange", 10),
         chase_range: Map.get(entry, "ChaseRange", 12),
         size: size,
         race: race,
         element: {element, Map.get(entry, "ElementLevel", 1)},
         walk_speed: Map.get(entry, "WalkSpeed", 150),
         attack_delay: Map.get(entry, "AttackDelay", 0),
         attack_motion: Map.get(entry, "AttackMotion", 0),
         client_attack_motion: Map.get(entry, "ClientAttackMotion", 0),
         damage_motion: Map.get(entry, "DamageMotion", 0),
         ai_type: parse_ai(Map.get(entry, "Ai")),
         modes: parse_modes(entry),
         drops: parse_drops(Map.get(entry, "Drops")),
         mvp_exp: Map.get(entry, "MvpExp", 0),
         mvp_drops: parse_mvp_drops(Map.get(entry, "MvpDrops"))
       }}
    end
  end

  @spec fetch_enum(map(), String.t(), atom()) :: {:ok, atom()} | {:error, {atom(), String.t()}}
  defp fetch_enum(table, value, error) do
    with :error <- Map.fetch(table, String.downcase(value)), do: {:error, {error, value}}
  end

  @spec parse_stats(map()) :: map()
  defp parse_stats(entry) do
    %{
      str: Map.get(entry, "Str", 1),
      agi: Map.get(entry, "Agi", 1),
      vit: Map.get(entry, "Vit", 1),
      int: Map.get(entry, "Int", 1),
      dex: Map.get(entry, "Dex", 1),
      luk: Map.get(entry, "Luk", 1)
    }
  end

  @spec parse_ai(term()) :: integer()
  defp parse_ai(value) when is_integer(value), do: value

  defp parse_ai(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_ai(_), do: 0

  @spec parse_modes(map()) :: [atom()]
  defp parse_modes(entry) do
    boss = if boss_class?(Map.get(entry, "Class")), do: [:boss], else: []
    aggressive = if aggressive_mode?(Map.get(entry, "Modes")), do: [:aggressive], else: []
    derived = MobMode.from_ai(Map.get(entry, "Ai"))
    Enum.uniq(boss ++ aggressive ++ derived)
  end

  @spec boss_class?(term()) :: boolean()
  defp boss_class?(class) when is_binary(class), do: String.downcase(class) == "boss"
  defp boss_class?(_), do: false

  @spec aggressive_mode?(term()) :: boolean()
  defp aggressive_mode?(modes) when is_map(modes) do
    Enum.any?(modes, fn {k, v} -> v == true and String.downcase(k) == "aggressive" end)
  end

  defp aggressive_mode?(_), do: false

  @spec parse_drops(term()) :: [MobDrop.t()]
  defp parse_drops(drops) when is_list(drops) do
    drops |> Enum.map(&parse_drop/1) |> Enum.reject(&is_nil/1)
  end

  defp parse_drops(_), do: []

  @spec parse_drop(map()) :: MobDrop.t() | nil
  defp parse_drop(%{"Item" => item, "Rate" => rate} = drop) when is_integer(rate) and rate > 0 do
    %MobDrop{
      item: item,
      rate: rate,
      steal_protected: Map.get(drop, "StealProtected", false),
      random_option_group: Map.get(drop, "RandomOptionGroup")
    }
  end

  defp parse_drop(_), do: nil

  @spec parse_mvp_drops(term()) :: [MobDrop.t()]
  defp parse_mvp_drops(drops) when is_list(drops) do
    drops |> Enum.map(&parse_mvp_drop/1) |> Enum.reject(&is_nil/1)
  end

  defp parse_mvp_drops(_), do: []

  @spec parse_mvp_drop(map()) :: MobDrop.t() | nil
  defp parse_mvp_drop(%{"Item" => item, "Rate" => rate} = drop)
       when is_integer(rate) and rate > 0 do
    %MobDrop{
      item: item,
      rate: rate,
      random_option_group: Map.get(drop, "RandomOptionGroup")
    }
  end

  defp parse_mvp_drop(_), do: nil
end
