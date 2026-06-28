defmodule Aesir.ZoneServer.Mmo.ItemManagement.Importer do
  @moduledoc """
  Maps a parsed rAthena `item_db` entry (string-keyed map, CamelCase keys) into
  an `ItemDefinition`. Used by the one-time `mix aesir.import.items` task; not on
  any runtime path.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  # rAthena's data has inconsistent casing (DelayConsume/Delayconsume,
  # ShadowGear/Shadowgear, ...), so types are matched on a downcased key.
  @types %{
    "healing" => :healing,
    "usable" => :usable,
    "etc" => :etc,
    "armor" => :armor,
    "weapon" => :weapon,
    "card" => :card,
    "petegg" => :pet_egg,
    "petarmor" => :pet_armor,
    "ammo" => :ammo,
    "delayconsume" => :delay_consume,
    "shadowgear" => :shadow_gear,
    "cash" => :cash
  }

  # Weapon SubType atoms align with `Aesir.ZoneServer.Mmo.WeaponTypes`; ammo and
  # misc subtypes get their own atoms. Matched on a downcased key.
  @subtypes %{
    "1hsword" => :one_handed_sword,
    "2hsword" => :two_handed_sword,
    "1hspear" => :one_handed_spear,
    "2hspear" => :two_handed_spear,
    "1haxe" => :one_handed_axe,
    "2haxe" => :two_handed_axe,
    "2hstaff" => :two_handed_staff,
    "dagger" => :dagger,
    "mace" => :mace,
    "staff" => :staff,
    "bow" => :bow,
    "knuckle" => :knuckle,
    "musical" => :musical,
    "whip" => :whip,
    "book" => :book,
    "katar" => :katar,
    "revolver" => :revolver,
    "rifle" => :rifle,
    "gatling" => :gatling,
    "shotgun" => :shotgun,
    "grenade" => :grenade,
    "huuma" => :huuma,
    "arrow" => :arrow,
    "bullet" => :bullet,
    "cannonball" => :cannonball,
    "kunai" => :kunai,
    "shuriken" => :shuriken,
    "throwweapon" => :throw_weapon,
    "enchant" => :enchant
  }

  @b_atk_ele %{
    "Fire" => :fire,
    "Water" => :water,
    "Wind" => :wind,
    "Earth" => :earth,
    "Holy" => :holy,
    "Dark" => :shadow,
    "Ghost" => :ghost,
    "Poison" => :poison,
    "Undead" => :undead,
    "Neutral" => :neutral
  }

  @always [:id, :aegis_name, :name, :type]
  @defaults Map.from_struct(struct(ItemDefinition, %{}))

  @spec to_yaml_map(ItemDefinition.t()) :: map()
  def to_yaml_map(%ItemDefinition{} = definition) do
    definition
    |> Map.from_struct()
    |> Enum.filter(fn {field, value} ->
      field in @always or value != Map.fetch!(@defaults, field)
    end)
    |> Map.new(fn {field, value} -> {Atom.to_string(field), encode_value(field, value)} end)
  end

  @spec encode_value(atom(), term()) :: term()
  defp encode_value(field, value) when field in [:type, :subtype, :attack_element],
    do: Atom.to_string(value)

  defp encode_value(field, value) when field in [:jobs, :locations] do
    Enum.map(value, &Atom.to_string/1)
  end

  defp encode_value(_field, value), do: value

  @spec to_definition(map()) :: {:ok, ItemDefinition.t()} | {:error, term()}
  def to_definition(entry) do
    with {:ok, type} <- parse_type(Map.get(entry, "Type")),
         {:ok, subtype} <- parse_subtype(Map.get(entry, "SubType")) do
      {:ok,
       %ItemDefinition{
         id: Map.fetch!(entry, "Id"),
         aegis_name: Map.fetch!(entry, "AegisName"),
         name: Map.fetch!(entry, "Name"),
         type: type,
         subtype: subtype,
         weight: Map.get(entry, "Weight", 0),
         buy: Map.get(entry, "Buy", 0),
         sell: Map.get(entry, "Sell", 0),
         attack: Map.get(entry, "Attack", 0),
         magic_attack: Map.get(entry, "MagicAttack", 0),
         defense: Map.get(entry, "Defense", 0),
         range: Map.get(entry, "Range", 0),
         slots: Map.get(entry, "Slots", 0),
         view: Map.get(entry, "View", 0),
         jobs: parse_flags(Map.get(entry, "Jobs")),
         locations: parse_flags(Map.get(entry, "Locations")),
         weapon_level: Map.get(entry, "WeaponLevel"),
         armor_level: Map.get(entry, "ArmorLevel"),
         equip_level_min: Map.get(entry, "EquipLevelMin", 0),
         equip_level_max: Map.get(entry, "EquipLevelMax", 0),
         refineable: Map.get(entry, "Refineable", false),
         attack_element: parse_attack_element(Map.get(entry, "Script"))
       }}
    end
  end

  @spec parse_type(String.t() | nil) :: {:ok, atom()} | {:error, {:unknown_type, String.t()}}
  defp parse_type(nil), do: {:ok, :etc}

  defp parse_type(str) do
    with :error <- Map.fetch(@types, String.downcase(str)), do: {:error, {:unknown_type, str}}
  end

  @spec parse_subtype(String.t() | nil) ::
          {:ok, atom() | nil} | {:error, {:unknown_subtype, String.t()}}
  defp parse_subtype(nil), do: {:ok, nil}

  defp parse_subtype(str) do
    with :error <- Map.fetch(@subtypes, String.downcase(str)),
         do: {:error, {:unknown_subtype, str}}
  end

  @spec parse_flags(map() | nil) :: [atom()]
  defp parse_flags(nil), do: []

  defp parse_flags(map) when is_map(map) do
    for({k, true} <- map, k != "All", do: atomize(k)) |> Enum.sort()
  end

  @spec atomize(String.t()) :: atom()
  defp atomize(str) do
    str |> Macro.underscore() |> String.replace("__", "_") |> String.to_atom()
  end

  @spec parse_attack_element(String.t() | nil) :: atom() | nil
  defp parse_attack_element(nil), do: nil

  defp parse_attack_element(script) do
    case Regex.run(~r/bonus\s+bAtkEle\s*,\s*Ele_(\w+)/, script, capture: :all_but_first) do
      [ele] -> Map.get(@b_atk_ele, ele)
      nil -> nil
    end
  end
end
