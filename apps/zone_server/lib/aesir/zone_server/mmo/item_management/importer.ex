defmodule Aesir.ZoneServer.Mmo.ItemManagement.Importer do
  @moduledoc """
  Maps a parsed rAthena `item_db` entry (string-keyed map, CamelCase keys) into
  an `ItemDefinition`, and renders the import-pass coverage report. Used by the
  one-time `mix aesir.import.items` task; not on any runtime path.

  ## `bAtkEle` carve-out

  `parse_attack_element/1` sniffs `bonus bAtkEle,Ele_*` straight out of the raw
  script and sets `attack_element`, independent of the `on_equip` transpile.
  `bAtkEle` is *also* in the bonus vocabulary, compiling to an `EquipScript`
  `:set` — the two are not redundant, because the transpile is all-or-nothing:
  an item like Fireblend, whose script is rejected over some unrelated
  construct, still keeps its `attack_element` from the sniff. The sniff is the
  fallback; the `:set` is what a fully-transpiled script contributes.

  Both feed the same runtime answer through
  `Aesir.ZoneServer.Unit.Player.PlayerState`, which prefers the ammo's
  `attack_element`, then the equipment `:atk_ele` modifier, then neutral. They
  derive from the same rAthena field, so they never disagree.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition

  @typedoc "Transpile hook a failure belongs to."
  @type hook :: :on_use | :on_equip

  @typedoc "A single unsupported-script failure row."
  @type failure :: {hook(), integer(), String.t(), term()}

  @typedoc "Per-hook coverage counters."
  @type hook_summary :: %{
          considered: non_neg_integer(),
          with_script: non_neg_integer(),
          transpiled: non_neg_integer()
        }

  @typedoc "The full input to `build_report/1`."
  @type report :: %{on_use: hook_summary(), on_equip: hook_summary(), failures: [failure()]}

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

  @doc """
  Renders the transpile coverage report: a per-hook summary table, a histogram
  of `on_equip` rejection reasons grouped on the reason's leading term (with the
  offending script token kept for the vocabulary-key/command tags, so the
  high-yield backlog rows like `bMaxHP`/`bonus2` stand on their own), and the
  full per-hook failure tables. The `on_equip` table is intentionally large - it
  is the greppable expansion backlog.
  """
  @spec build_report(report()) :: String.t()
  def build_report(%{on_use: on_use, on_equip: on_equip, failures: failures}) do
    {on_use_failures, on_equip_failures} =
      Enum.split_with(failures, fn {hook, _id, _name, _reason} -> hook == :on_use end)

    """
    # Transpile report

    ## Summary

    | hook | items | with script | transpiled | unsupported |
    | --- | --- | --- | --- | --- |
    #{summary_row(:on_use, on_use, length(on_use_failures))}
    #{summary_row(:on_equip, on_equip, length(on_equip_failures))}

    ## on_equip rejection reasons

    #{histogram(on_equip_failures)}
    ## on_use failures

    #{failure_table(on_use_failures)}
    ## on_equip failures

    #{failure_table(on_equip_failures)}
    """
  end

  @spec summary_row(hook(), hook_summary(), non_neg_integer()) :: String.t()
  defp summary_row(
         hook,
         %{considered: considered, with_script: with_script, transpiled: transpiled},
         unsupported
       ) do
    "| #{hook} | #{considered} | #{with_script} | #{transpiled} | #{unsupported} |"
  end

  @spec histogram([failure()]) :: String.t()
  defp histogram([]), do: "_none_\n"

  defp histogram(failures) do
    rows =
      failures
      |> Enum.frequencies_by(fn {_hook, _id, _name, reason} -> histogram_key(reason) end)
      |> Enum.sort_by(fn {_key, count} -> -count end)
      |> Enum.map_join("\n", fn {key, count} -> "| #{key} | #{count} |" end)

    """
    | reason | count |
    | --- | --- |
    #{rows}
    """
  end

  @spec histogram_key(term()) :: String.t()
  defp histogram_key({:unsupported, detail}), do: detail_key(detail)
  defp histogram_key(reason) when is_tuple(reason), do: to_string(elem(reason, 0))
  defp histogram_key(reason), do: inspect(reason)

  # Tags whose payload is a raw rAthena script token (a bonus key or command
  # name); splitting the histogram on it surfaces the high-yield backlog rows
  # (`bMaxHP`, `bonus2`, ...). Other tags carry incidental data (user var names),
  # so they group on the leading term alone.
  @named_detail [:unknown_bonus_key, :unsupported_command, :unsupported_call]

  @spec detail_key(term()) :: String.t()
  defp detail_key({tag, term}) when tag in @named_detail and is_binary(term),
    do: "#{tag} #{term}"

  defp detail_key({tag, _term}) when is_atom(tag), do: to_string(tag)
  defp detail_key(tag) when is_atom(tag), do: to_string(tag)
  defp detail_key(detail), do: inspect(detail)

  @spec failure_table([failure()]) :: String.t()
  defp failure_table([]), do: "_none_\n"

  defp failure_table(failures) do
    rows =
      failures
      |> Enum.sort_by(fn {_hook, id, _name, _reason} -> id end)
      |> Enum.map_join("\n", fn {_hook, id, name, reason} ->
        "| #{id} | #{name} | #{inspect(reason)} |"
      end)

    """
    | id | name | reason |
    | --- | --- | --- |
    #{rows}
    """
  end

  @spec encode_value(atom(), term()) :: term()
  defp encode_value(field, value) when field in [:type, :subtype, :attack_element],
    do: Atom.to_string(value)

  defp encode_value(field, value) when field in [:jobs, :locations] do
    Enum.map(value, &Atom.to_string/1)
  end

  defp encode_value(:on_equip, value), do: EquipScript.to_source(value)

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
