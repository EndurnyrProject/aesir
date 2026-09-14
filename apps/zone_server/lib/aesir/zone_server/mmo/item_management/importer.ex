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
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility

  @typedoc "Transpile hook a failure belongs to."
  @type hook :: :on_use | :on_equip | :on_unequip | :card_on_equip | :card_on_unequip

  @typedoc "A single unsupported-script failure row."
  @type failure :: {hook(), integer(), String.t(), term()}

  @typedoc "Per-hook coverage counters."
  @type hook_summary :: %{
          considered: non_neg_integer(),
          with_script: non_neg_integer(),
          transpiled: non_neg_integer()
        }

  @typedoc "The full input to `build_report/1`."
  @type report :: %{
          on_use: hook_summary(),
          on_equip: hook_summary(),
          on_unequip: hook_summary(),
          card_on_equip: hook_summary(),
          card_on_unequip: hook_summary(),
          failures: [failure()]
        }

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

  @class_groups %{
    "Normal" => [:normal],
    "Upper" => [:upper],
    "Baby" => [:baby],
    "Third" => [:third],
    "Third_Upper" => [:third_upper],
    "Third_Baby" => [:third_baby],
    "Fourth" => [:fourth],
    "All_Upper" => [:upper, :third_upper, :fourth],
    "All_Baby" => [:baby, :third_baby],
    "All_Third" => [:third, :third_upper, :third_baby]
  }

  @spec to_yaml_map(ItemDefinition.t(), ItemEligibility.mode()) :: map()
  def to_yaml_map(%ItemDefinition{} = definition, mode) do
    definition
    |> Map.from_struct()
    |> Enum.filter(fn {field, value} ->
      field in @always or value != default_value(field, mode)
    end)
    |> Map.new(fn {field, value} -> {Atom.to_string(field), encode_value(field, value)} end)
  end

  defp default_value(:classes, mode), do: ItemDefinition.default_classes(mode)
  defp default_value(field, _mode), do: Map.fetch!(@defaults, field)

  @doc """
  Renders the transpile coverage report: a per-hook summary table, histograms
  of equipment and card rejection reasons grouped on the reason's leading term
  (with the offending script token kept for vocabulary-key/command tags), and
  the full per-hook failure tables. The tables are intentionally large - they
  are the greppable expansion backlog.
  """
  @spec build_report(report()) :: String.t()
  def build_report(%{
        on_use: on_use,
        on_equip: on_equip,
        on_unequip: on_unequip,
        card_on_equip: card_on_equip,
        card_on_unequip: card_on_unequip,
        failures: failures
      }) do
    failures_by_hook = Enum.group_by(failures, &elem(&1, 0))
    on_use_failures = Map.get(failures_by_hook, :on_use, [])
    on_equip_failures = Map.get(failures_by_hook, :on_equip, [])
    on_unequip_failures = Map.get(failures_by_hook, :on_unequip, [])
    card_on_equip_failures = Map.get(failures_by_hook, :card_on_equip, [])
    card_on_unequip_failures = Map.get(failures_by_hook, :card_on_unequip, [])

    """
    # Transpile report

    ## Summary

    | hook | items | with script | transpiled | unsupported |
    | --- | --- | --- | --- | --- |
    #{summary_row(:on_use, on_use, length(on_use_failures))}
    #{summary_row(:on_equip, on_equip, length(on_equip_failures))}
    #{summary_row(:on_unequip, on_unequip, length(on_unequip_failures))}
    #{summary_row(:card_on_equip, card_on_equip, length(card_on_equip_failures))}
    #{summary_row(:card_on_unequip, card_on_unequip, length(card_on_unequip_failures))}

    ## on_equip rejection reasons

    #{histogram(on_equip_failures)}
    ## on_unequip rejection reasons

    #{histogram(on_unequip_failures)}
    ## card_on_equip rejection reasons

    #{histogram(card_on_equip_failures)}
    ## card_on_unequip rejection reasons

    #{histogram(card_on_unequip_failures)}
    ## on_use failures

    #{failure_table(on_use_failures)}
    ## on_equip failures

    #{failure_table(on_equip_failures)}
    ## on_unequip failures

    #{failure_table(on_unequip_failures)}
    ## card_on_equip failures

    #{failure_table(card_on_equip_failures)}
    ## card_on_unequip failures

    #{failure_table(card_on_unequip_failures)}
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
  defp encode_value(field, value)
       when field in [:type, :subtype, :attack_element, :gender],
       do: Atom.to_string(value)

  defp encode_value(:jobs, :all), do: "all"

  defp encode_value(field, value) when field in [:jobs, :classes, :locations],
    do: Enum.map(value, &Atom.to_string/1)

  defp encode_value(field, value) when field in [:on_equip, :on_unequip],
    do: EquipScript.to_source(value)

  defp encode_value(_field, value), do: value

  @spec to_definition(map(), ItemEligibility.mode()) ::
          {:ok, ItemDefinition.t()} | {:error, term()}
  def to_definition(entry, mode) do
    item_id = Map.fetch!(entry, "Id")

    with {:ok, type} <- parse_type(Map.get(entry, "Type")),
         {:ok, subtype} <- parse_subtype(Map.get(entry, "SubType")),
         {:ok, jobs} <- parse_jobs(Map.fetch(entry, "Jobs"), item_id),
         {:ok, classes} <- parse_classes(Map.fetch(entry, "Classes"), item_id, mode),
         {:ok, gender} <- parse_gender(Map.fetch(entry, "Gender"), item_id) do
      definition = %ItemDefinition{
        id: item_id,
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
        jobs: jobs,
        classes: classes,
        gender: gender,
        locations: parse_location_flags(Map.get(entry, "Locations")),
        weapon_level: Map.get(entry, "WeaponLevel"),
        armor_level: Map.get(entry, "ArmorLevel"),
        equip_level_min: Map.get(entry, "EquipLevelMin", 0),
        equip_level_max: Map.get(entry, "EquipLevelMax", 0),
        refineable: Map.get(entry, "Refineable", false),
        bind_on_equip: get_in(entry, ["Flags", "BindOnEquip"]) || false,
        no_trade: get_in(entry, ["Trade", "NoTrade"]) || false,
        no_guild_storage: get_in(entry, ["Trade", "NoGuildStorage"]) || false,
        attack_element: parse_attack_element(Map.get(entry, "Script"))
      }

      {:ok, ItemDefinition.normalize_gender(definition)}
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

  defp parse_jobs(:error, _item_id), do: {:ok, :all}
  defp parse_jobs({:ok, nil}, _item_id), do: {:ok, []}

  defp parse_jobs({:ok, flags}, item_id) when is_list(flags) do
    case parse_ordered_flags(flags, [], ItemEligibility.families(), &job_group/1) do
      {:ok, jobs} ->
        jobs = Enum.sort(jobs)
        {:ok, if(jobs == ItemEligibility.families(), do: :all, else: jobs)}

      {:error, reason} ->
        restriction_error(item_id, :jobs, reason)
    end
  end

  defp parse_jobs({:ok, value}, item_id),
    do: restriction_error(item_id, :jobs, {:invalid_flags, value})

  defp parse_classes(:error, _item_id, mode),
    do: {:ok, ItemDefinition.default_classes(mode)}

  defp parse_classes({:ok, nil}, _item_id, _mode), do: {:ok, []}

  defp parse_classes({:ok, flags}, item_id, mode) when is_list(flags) do
    defaults = ItemDefinition.default_classes(mode)

    case parse_ordered_flags(flags, [], defaults, &class_group/1) do
      {:ok, classes} -> {:ok, Enum.sort(classes)}
      {:error, reason} -> restriction_error(item_id, :classes, reason)
    end
  end

  defp parse_classes({:ok, value}, item_id, _mode),
    do: restriction_error(item_id, :classes, {:invalid_flags, value})

  defp parse_ordered_flags(flags, initial, all_values, group_fun) do
    case all_setting(flags) do
      {:ok, all} ->
        starting = if all, do: all_values, else: initial

        flags
        |> Enum.reduce_while(
          {:ok, MapSet.new(starting)},
          &apply_ordered_flag(&1, &2, group_fun)
        )
        |> ordered_flags_result()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_ordered_flag({"All", _enabled}, acc, _group_fun), do: {:cont, acc}

  defp apply_ordered_flag({key, enabled}, {:ok, allowed}, group_fun)
       when is_binary(key) and is_boolean(enabled) do
    case group_fun.(key) do
      {:ok, values} ->
        values = MapSet.new(values)

        next =
          if enabled, do: MapSet.union(allowed, values), else: MapSet.difference(allowed, values)

        {:cont, {:ok, next}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp apply_ordered_flag({key, value}, _acc, _group_fun),
    do: {:halt, {:error, {:invalid_flag, key, value}}}

  defp apply_ordered_flag(value, _acc, _group_fun),
    do: {:halt, {:error, {:invalid_flag, value}}}

  defp ordered_flags_result({:ok, allowed}), do: {:ok, MapSet.to_list(allowed)}
  defp ordered_flags_result({:error, reason}), do: {:error, reason}

  defp all_setting(flags) do
    case List.keyfind(flags, "All", 0) do
      nil -> {:ok, false}
      {"All", enabled} when is_boolean(enabled) -> {:ok, enabled}
      {"All", value} -> {:error, {:invalid_flag, "All", value}}
    end
  end

  defp job_group(source_job) do
    case ItemEligibility.source_family("EAJ_" <> String.upcase(source_job)) do
      {:ok, family} -> {:ok, [family]}
      {:error, :unknown_source_job} -> {:error, {:unknown_flag, source_job}}
    end
  end

  defp class_group(source_class) do
    case Map.fetch(@class_groups, source_class) do
      {:ok, classes} -> {:ok, classes}
      :error -> {:error, {:unknown_flag, source_class}}
    end
  end

  defp parse_gender(:error, _item_id), do: {:ok, :both}
  defp parse_gender({:ok, "Both"}, _item_id), do: {:ok, :both}
  defp parse_gender({:ok, "Male"}, _item_id), do: {:ok, :male}
  defp parse_gender({:ok, "Female"}, _item_id), do: {:ok, :female}

  defp parse_gender({:ok, value}, item_id),
    do: restriction_error(item_id, :gender, {:unknown_value, value})

  defp restriction_error(item_id, field, reason),
    do: {:error, {:invalid_restriction, item_id, field, reason}}

  @spec parse_location_flags(map() | nil) :: [atom()]
  defp parse_location_flags(nil), do: []

  defp parse_location_flags(map) when is_map(map) do
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
