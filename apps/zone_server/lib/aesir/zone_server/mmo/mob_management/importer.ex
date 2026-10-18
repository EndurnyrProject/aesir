defmodule Aesir.ZoneServer.Mmo.MobManagement.Importer do
  @moduledoc """
  Maps a parsed monster-database entry (string-keyed map, CamelCase keys) into
  a `MobDefinition`. Used by the one-time `mix aesir.import.mobs` task; not on
  any runtime path.

  Modes start with the `Ai` preset, then explicit boolean `Modes` overrides
  set or clear its bits. Class modes are added last: Boss gives detector,
  status immunity and knockback immunity, Guardian gives status immunity,
  Battlefield adds skill immunity, and Event adds fixed-item-drop mode.
  The declared class is retained
  for initial base data; a later Mode calculation derives the runtime class.
  `MvpExp` and `MvpDrops` are parsed onto
  `mvp_exp`/`mvp_drops` and stay strictly separate from the normal `drops`
  list. `RaceGroups` is parsed into `race_groups`; resistances and `DamageTaken`
  are still dropped.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode

  require Logger

  @sizes %{"small" => :small, "medium" => :medium, "large" => :large}
  @classes %{
    "normal" => :normal,
    "boss" => :boss,
    "guardian" => :guardian,
    "battlefield" => :battlefield,
    "event" => :event
  }

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
    "player_human" => :player_human,
    "player_doram" => :player_doram
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
  defp encode_value(field, value) when field in [:size, :race, :class], do: Atom.to_string(value)
  defp encode_value(:modes, value), do: Enum.map(value, &Atom.to_string/1)
  defp encode_value(:race_groups, value), do: Enum.map(value, &Atom.to_string/1)
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

  @doc """
  Converts one rAthena `mob_db` row read in `mode`.

  `Attack2` is the maximum ATK in pre-renewal (`atk2`) and the MATK in renewal
  (`matk`), as `mob.cpp` loads it.
  """
  @spec to_definition(map(), :renewal | :pre_renewal) ::
          {:ok, MobDefinition.t()} | {:error, term()}
  def to_definition(entry, mode \\ :renewal) do
    with {:ok, class} <- fetch_enum(@classes, Map.get(entry, "Class", "Normal"), :unknown_class),
         {:ok, size} <- fetch_enum(@sizes, Map.get(entry, "Size", "Small"), :unknown_size),
         {:ok, race} <- fetch_enum(@races, Map.get(entry, "Race", "Formless"), :unknown_race),
         {:ok, element} <-
           fetch_enum(@elements, Map.get(entry, "Element", "Neutral"), :unknown_element) do
      {:ok,
       %MobDefinition{
         id: Map.fetch!(entry, "Id"),
         aegis_name: Map.fetch!(entry, "AegisName"),
         name: Map.fetch!(entry, "Name"),
         level: uint!(entry, "Level", 1, 16),
         hp: max(uint!(entry, "Hp", 1, 32), 1),
         sp: max(uint!(entry, "Sp", 1, 32), 1),
         base_exp: Map.get(entry, "BaseExp", 0),
         job_exp: Map.get(entry, "JobExp", 0),
         atk: uint!(entry, "Attack", 0, 16),
         atk2: if(mode == :pre_renewal, do: uint!(entry, "Attack2", 0, 16), else: 0),
         matk: if(mode == :renewal, do: uint!(entry, "Attack2", 0, 16), else: 0),
         def: min(uint!(entry, "Defense", 0, 16), if(mode == :renewal, do: 32_767, else: 127)),
         mdef:
           min(uint!(entry, "MagicDefense", 0, 16), if(mode == :renewal, do: 32_767, else: 127)),
         class: class,
         stats: parse_stats(entry),
         attack_range: Map.get(entry, "AttackRange", 0),
         skill_range: Map.get(entry, "SkillRange", 10),
         chase_range: Map.get(entry, "ChaseRange", 12),
         size: size,
         race: race,
         race_groups: parse_race_groups(Map.get(entry, "RaceGroups")),
         element: {element, element_level(entry)},
         walk_speed: entry |> uint!("WalkSpeed", 150, 16) |> max(20) |> min(1_000),
         attack_delay: entry |> uint!("AttackDelay", 100, 16) |> max(100) |> min(8_000),
         attack_motion: attack_motion(entry),
         client_attack_motion:
           entry |> uint!("ClientAttackMotion", attack_motion(entry), 16) |> max(1),
         damage_motion: uint!(entry, "DamageMotion", 0, 16),
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

  @spec parse_race_groups(term()) :: [atom()]
  defp parse_race_groups(groups) when is_map(groups) do
    groups
    |> Enum.filter(fn {_group, enabled?} -> enabled? == true end)
    |> Enum.flat_map(fn {group, _enabled?} ->
      case Map.fetch(Resolver.race2s(), "rc2_" <> String.downcase(group)) do
        {:ok, race_group} ->
          [race_group]

        :error ->
          Logger.warning("Unknown secondary monster group: #{group}")
          []
      end
    end)
    |> Enum.sort()
    |> Enum.uniq()
  end

  defp parse_race_groups(_), do: []

  @spec parse_stats(map()) :: map()
  defp parse_stats(entry) do
    Map.new(
      [{"Str", :str}, {"Agi", :agi}, {"Vit", :vit}, {"Int", :int}, {"Dex", :dex}, {"Luk", :luk}],
      fn {key, field} ->
        value = uint!(entry, key, 1, 16)
        {field, Integer.mod(value + 32_768, 65_536) - 32_768}
      end
    )
  end

  defp attack_motion(entry), do: entry |> uint!("AttackMotion", 100, 16) |> max(1) |> min(8_000)

  defp element_level(entry) do
    level = uint!(entry, "ElementLevel", 1, 16)
    if level in 1..4, do: level, else: 1
  end

  defp uint!(entry, key, default, bits) do
    value = Map.get(entry, key, default)

    if is_integer(value) and value >= 0 and value < Integer.pow(2, bits),
      do: value,
      else: raise(ArgumentError, "invalid #{key} for monster #{entry["Id"]}: #{inspect(value)}")
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
    modes =
      entry
      |> Map.get("Ai")
      |> MobMode.from_ai()
      |> MobMode.apply_overrides(Map.get(entry, "Modes") || %{})

    Enum.uniq(class_modes(Map.get(entry, "Class")) ++ modes)
  end

  # The modes `MobDatabase::loadingFinished` adds for a class.
  @spec class_modes(term()) :: [atom()]
  defp class_modes(class) when is_binary(class) do
    case String.downcase(class) do
      "boss" -> [:detector, :status_immune, :knockback_immune]
      "guardian" -> [:status_immune]
      "battlefield" -> [:status_immune, :skill_immune]
      "event" -> [:fixed_item_drop]
      _other -> []
    end
  end

  defp class_modes(_class), do: []

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
