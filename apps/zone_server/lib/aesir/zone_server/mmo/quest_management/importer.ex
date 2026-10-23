defmodule Aesir.ZoneServer.Mmo.QuestManagement.Importer do
  @moduledoc """
  Converts rAthena `quest_db.yml` entries into `QuestDefinition` structs, and
  `QuestDefinition` structs back into our own-schema YAML maps.

  Targets and drops are read in row order, as the reference reads them:

  - A target is keyed by its `Mob` (resolved to an id) or its `Id`. A row whose
    key repeats an earlier target updates that target in place and lists it
    again, so the quest holds the merged objective twice. The same holds for
    drops keyed by `Mob` (`0` when absent).
  - A quest is skipped whole when a target row is refused: more than three
    targets, neither `Mob` nor `Id`, an unresolvable `Mob`, an `Id` of `0`, a new
    target without `Count`, an unknown or unsupported race, size or element, or
    a `Location` other than `All` that is not in the map index. A malformed
    value (a name that is not a scalar, a number that is not an unsigned 16-bit
    integer, a `MapMobTargets` flag that is not a boolean) skips the quest too,
    in a target or a drop row. A numeric name is read as text, so it simply
    fails to resolve.
  - Filters are read only on an `Id` target. A `MaxLevel` below `MinLevel` becomes
    275, and a `MaxLevel` with no `MinLevel` sets the minimum to 1. A
    `MapMobTargets` name set to `false` removes that monster again; an
    unresolvable name is skipped.
  - A drop row is skipped when its `Mob` or `Item` does not resolve, or when a new
    row lacks `Item` or `Rate`. `Count` defaults to 1 and is capped to 1 for an
    item that does not stack.

  Names resolve through the `resolvers()` passed in. `to_definition/1` uses the
  loaded mob and item catalogs and accepts every `Location`, since the map
  index is a reference source file that only the import task reads. Every
  skipped quest, row and name is reported back as a `dropped()` entry.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition

  @typedoc """
  A refused quest, row or name. `:target_mob` and `:invalid` skip the whole
  quest; the other kinds skip one row or name.
  """
  @type dropped ::
          {quest_id :: integer(),
           kind ::
             :target_mob
             | :invalid
             | :map_mob_target
             | :drop_mob
             | :drop_item
             | :drop_invalid, name :: String.t()}

  @typedoc """
  Name lookups: `mob` maps a monster's AegisName to its id, `item` maps an
  item's AegisName to its id and whether it stacks, and `map?` tells whether a
  map name is in the map index.
  """
  @type resolvers :: %{
          mob: (String.t() -> {:ok, integer()} | :error),
          item: (String.t() -> {:ok, %{id: integer(), stackable?: boolean()}} | :error),
          map?: (String.t() -> boolean())
        }

  @max_objectives 3
  @max_level 275
  @uint16 0..65_535

  @races ~w(formless undead brute plant insect fish demon demihuman angel dragon all)
  @sizes ~w(small medium large all)
  @elements ~w(neutral water earth fire wind poison holy dark ghost undead all)

  @always [:id, :title]
  @defaults Map.from_struct(struct(QuestDefinition, %{}))

  @doc """
  Converts a raw rAthena quest_db entry against the loaded mob and item
  catalogs. See `to_definition/2`.
  """
  @spec to_definition(map()) :: {QuestDefinition.t() | nil, [dropped()]}
  def to_definition(entry), do: to_definition(entry, catalog_resolvers())

  @doc """
  Converts a raw rAthena quest_db entry into a `QuestDefinition`, along with
  every refused reference. The definition is `nil` when the quest is skipped.
  """
  @spec to_definition(map(), resolvers()) :: {QuestDefinition.t() | nil, [dropped()]}
  def to_definition(entry, resolvers) do
    id = Map.fetch!(entry, "Id")

    with {:ok, targets, target_dropped} <-
           targets(id, Map.get(entry, "Targets") || [], resolvers),
         {:ok, drops, drop_dropped} <-
           drops(id, Map.get(entry, "Drops") || [], resolvers, target_dropped) do
      definition = %QuestDefinition{
        id: id,
        title: Map.fetch!(entry, "Title"),
        time_limit: Map.get(entry, "TimeLimit"),
        targets: targets,
        drops: drops
      }

      {definition, drop_dropped}
    else
      {:skip, dropped} -> {nil, dropped}
    end
  end

  @doc """
  Converts a `QuestDefinition` into a plain map ready for `Ymlr.document!/1`,
  omitting fields still at their default value.
  """
  @spec to_yaml_map(QuestDefinition.t()) :: map()
  def to_yaml_map(%QuestDefinition{} = definition) do
    definition
    |> Map.from_struct()
    |> Enum.filter(fn {field, value} ->
      field in @always or value != Map.fetch!(@defaults, field)
    end)
    |> Map.new(fn {field, value} -> {Atom.to_string(field), encode_value(field, value)} end)
  end

  @spec encode_value(atom(), term()) :: term()
  defp encode_value(field, value) when field in [:targets, :drops] do
    Enum.map(value, &stringify_keys/1)
  end

  defp encode_value(_field, value), do: value

  @spec stringify_keys(map()) :: map()
  defp stringify_keys(map), do: Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)

  @spec catalog_resolvers() :: resolvers()
  defp catalog_resolvers do
    %{
      mob: fn name ->
        case Mobs.by_name(name) do
          {:ok, %{id: id}} -> {:ok, id}
          :error -> :error
        end
      end,
      item: fn name ->
        case Items.by_aegis(name) do
          {:ok, item} -> {:ok, %{id: item.id, stackable?: ItemDefinition.stackable?(item)}}
          :error -> :error
        end
      end,
      map?: fn _name -> true end
    }
  end

  # Targets: each row updates or creates the target its key names, then lists
  # that key again; the final list reads every key's merged target.
  @spec targets(integer(), [map()], resolvers()) ::
          {:ok, [QuestDefinition.target()], [dropped()]} | {:skip, [dropped()]}
  defp targets(quest_id, rows, resolvers) do
    rows
    |> Enum.reduce_while({:ok, [], %{}, []}, fn row, {:ok, keys, by_key, dropped} ->
      case target_row(quest_id, row, keys, by_key, resolvers) do
        {:ok, key, target, row_dropped} ->
          {:cont, {:ok, keys ++ [key], Map.put(by_key, key, target), dropped ++ row_dropped}}

        {:skip, reason} ->
          {:halt, {:skip, dropped ++ [reason]}}
      end
    end)
    |> case do
      {:ok, keys, by_key, dropped} ->
        {:ok, Enum.map(keys, &emit_target(Map.fetch!(by_key, &1))), dropped}

      {:skip, dropped} ->
        {:skip, dropped}
    end
  end

  @spec target_row(integer(), map(), [term()], map(), resolvers()) ::
          {:ok, term(), map(), [dropped()]} | {:skip, dropped()}
  defp target_row(quest_id, row, keys, by_key, resolvers) do
    with :ok <- check(length(keys) < @max_objectives, quest_id, "more than 3 targets"),
         {:ok, key} <- target_key(quest_id, row, resolvers),
         {:ok, target} <- existing_or_new_target(quest_id, row, key, by_key),
         {:ok, target, dropped} <- target_filters(quest_id, row, target, resolvers),
         {:ok, target} <- target_count(quest_id, row, target) do
      {:ok, key, target, dropped}
    end
  end

  @spec target_key(integer(), map(), resolvers()) :: {:ok, term()} | {:skip, dropped()}
  defp target_key(quest_id, %{"Mob" => value}, resolvers) do
    with {:ok, name} <- scalar(quest_id, "target Mob", value) do
      case resolvers.mob.(name) do
        {:ok, mob_id} -> {:ok, {:mob, mob_id}}
        :error -> {:skip, {quest_id, :target_mob, name}}
      end
    end
  end

  defp target_key(quest_id, %{"Id" => index}, _resolvers) do
    cond do
      not uint16?(index) -> invalid(quest_id, "target Id #{inspect(index)}")
      index == 0 -> invalid(quest_id, "target Id 0")
      true -> {:ok, {:id, index}}
    end
  end

  defp target_key(quest_id, _row, _resolvers), do: invalid(quest_id, "target without Mob or Id")

  @spec existing_or_new_target(integer(), map(), term(), map()) ::
          {:ok, map()} | {:skip, dropped()}
  defp existing_or_new_target(quest_id, row, key, by_key) do
    case Map.fetch(by_key, key) do
      {:ok, target} ->
        {:ok, target}

      :error when is_map_key(row, "Count") ->
        {:ok, new_target(key)}

      :error ->
        invalid(quest_id, "new target without Count")
    end
  end

  @spec new_target(term()) :: map()
  defp new_target({:mob, mob_id}), do: %{mob_id: mob_id, min_level: 0, max_level: 0}
  defp new_target({:id, _index}), do: %{min_level: 0, max_level: 0}

  @spec target_filters(integer(), map(), map(), resolvers()) ::
          {:ok, map(), [dropped()]} | {:skip, dropped()}
  defp target_filters(_quest_id, %{"Mob" => _name}, target, _resolvers), do: {:ok, target, []}

  defp target_filters(quest_id, row, target, resolvers) do
    with {:ok, target} <- min_level(quest_id, row, target),
         {:ok, target} <- max_level(quest_id, row, target),
         {:ok, target} <- named_filter(quest_id, row, target, "Race", :race, @races),
         {:ok, target} <- named_filter(quest_id, row, target, "Size", :size, @sizes),
         {:ok, target} <- named_filter(quest_id, row, target, "Element", :element, @elements),
         {:ok, target} <- location(quest_id, row, target, resolvers),
         :ok <- map_name(quest_id, row),
         {:ok, target, dropped} <- map_mob_targets(quest_id, row, target, resolvers) do
      {:ok, default_min_level(target), dropped}
    end
  end

  @spec min_level(integer(), map(), map()) :: {:ok, map()} | {:skip, dropped()}
  defp min_level(quest_id, %{"MinLevel" => level}, target) do
    if uint16?(level),
      do: {:ok, %{target | min_level: level}},
      else: invalid(quest_id, "MinLevel #{inspect(level)}")
  end

  defp min_level(_quest_id, _row, target), do: {:ok, target}

  @spec max_level(integer(), map(), map()) :: {:ok, map()} | {:skip, dropped()}
  defp max_level(quest_id, %{"MaxLevel" => level}, target) do
    cond do
      not uint16?(level) -> invalid(quest_id, "MaxLevel #{inspect(level)}")
      target.min_level > level -> {:ok, %{target | max_level: @max_level}}
      true -> {:ok, %{target | max_level: level}}
    end
  end

  defp max_level(_quest_id, _row, target), do: {:ok, target}

  @spec named_filter(integer(), map(), map(), String.t(), atom(), [String.t()]) ::
          {:ok, map()} | {:skip, dropped()}
  defp named_filter(quest_id, row, target, field, key, accepted) do
    with {:ok, value} <- Map.fetch(row, field),
         {:ok, name} <- scalar(quest_id, field, value) do
      if String.downcase(name) in accepted,
        do: {:ok, Map.put(target, key, name)},
        else: invalid(quest_id, "#{field} #{name}")
    else
      :error -> {:ok, target}
      {:skip, reason} -> {:skip, reason}
    end
  end

  @spec location(integer(), map(), map(), resolvers()) :: {:ok, map()} | {:skip, dropped()}
  defp location(quest_id, %{"Location" => value}, target, resolvers) do
    with {:ok, map} <- scalar(quest_id, "Location", value) do
      if String.downcase(map) == "all" or resolvers.map?.(map),
        do: {:ok, Map.put(target, :map, map)},
        else: invalid(quest_id, "Location #{map}")
    end
  end

  defp location(_quest_id, _row, target, _resolvers), do: {:ok, target}

  @spec map_name(integer(), map()) :: :ok | {:skip, dropped()}
  defp map_name(quest_id, %{"MapName" => value}) do
    with {:ok, _name} <- scalar(quest_id, "MapName", value), do: :ok
  end

  defp map_name(_quest_id, _row), do: :ok

  @spec map_mob_targets(integer(), map(), map(), resolvers()) ::
          {:ok, map(), [dropped()]} | {:skip, dropped()}
  defp map_mob_targets(quest_id, %{"MapMobTargets" => names}, target, resolvers)
       when is_map(names) do
    names
    |> Enum.reduce_while({:ok, Map.get(target, :mobs_allowed, []), []}, fn entry, acc ->
      map_mob_target(quest_id, entry, acc, resolvers)
    end)
    |> case do
      {:ok, allowed, dropped} -> {:ok, Map.put(target, :mobs_allowed, allowed), dropped}
      {:skip, reason} -> {:skip, reason}
    end
  end

  defp map_mob_targets(_quest_id, _row, target, _resolvers), do: {:ok, target, []}

  defp map_mob_target(quest_id, {name, active?}, {:ok, allowed, dropped}, resolvers) do
    case resolvers.mob.(name) do
      :error ->
        {:cont, {:ok, allowed, dropped ++ [{quest_id, :map_mob_target, name}]}}

      {:ok, _mob_id} when not is_boolean(active?) ->
        {:halt, invalid(quest_id, "MapMobTargets #{name}: #{inspect(active?)}")}

      {:ok, mob_id} when active? ->
        allowed = if mob_id in allowed, do: allowed, else: allowed ++ [mob_id]
        {:cont, {:ok, allowed, dropped}}

      {:ok, mob_id} ->
        {:cont, {:ok, List.delete(allowed, mob_id), dropped}}
    end
  end

  @spec default_min_level(map()) :: map()
  defp default_min_level(%{min_level: 0, max_level: max} = target) when max > 0,
    do: %{target | min_level: 1}

  defp default_min_level(target), do: target

  @spec target_count(integer(), map(), map()) :: {:ok, map()} | {:skip, dropped()}
  defp target_count(quest_id, %{"Count" => count}, target) do
    if uint16?(count),
      do: {:ok, Map.put(target, :count, count)},
      else: invalid(quest_id, "Count #{inspect(count)}")
  end

  defp target_count(_quest_id, _row, target), do: {:ok, target}

  @spec emit_target(map()) :: QuestDefinition.target()
  defp emit_target(target) do
    target
    |> Enum.reject(fn {key, value} -> key in [:min_level, :max_level] and value == 0 end)
    |> Map.new()
  end

  # Drops: each row updates or creates the drop its monster names, then lists
  # that monster again; the final list reads every monster's merged drop.
  @spec drops(integer(), [map()], resolvers(), [dropped()]) ::
          {:ok, [QuestDefinition.drop()], [dropped()]} | {:skip, [dropped()]}
  defp drops(quest_id, rows, resolvers, dropped) do
    rows
    |> Enum.reduce_while({:ok, [], %{}, dropped}, fn row, {:ok, keys, by_key, dropped} ->
      case drop_row(quest_id, row, by_key, resolvers) do
        {:ok, mob_id, drop} ->
          {:cont, {:ok, keys ++ [mob_id], Map.put(by_key, mob_id, drop), dropped}}

        {:skip, {_quest_id, :invalid, _reason} = reason} ->
          {:halt, {:skip, dropped ++ [reason]}}

        {:skip, reason} ->
          {:cont, {:ok, keys, by_key, dropped ++ [reason]}}
      end
    end)
    |> case do
      {:ok, keys, by_key, dropped} ->
        {:ok, Enum.map(keys, &Map.delete(Map.fetch!(by_key, &1), :stackable?)), dropped}

      {:skip, dropped} ->
        {:skip, dropped}
    end
  end

  @spec drop_row(integer(), map(), map(), resolvers()) ::
          {:ok, integer(), map()} | {:skip, dropped()}
  defp drop_row(quest_id, row, by_key, resolvers) do
    with {:ok, mob_id} <- drop_mob(quest_id, row, resolvers),
         {:ok, drop} <- existing_or_new_drop(quest_id, row, mob_id, by_key),
         {:ok, drop} <- drop_item(quest_id, row, drop, resolvers),
         {:ok, drop} <- drop_count(quest_id, row, drop, Map.has_key?(by_key, mob_id)) do
      drop_rate(quest_id, row, mob_id, drop)
    end
  end

  @spec drop_mob(integer(), map(), resolvers()) :: {:ok, integer()} | {:skip, dropped()}
  defp drop_mob(quest_id, %{"Mob" => value}, resolvers) do
    with {:ok, name} <- scalar(quest_id, "drop Mob", value) do
      case resolvers.mob.(name) do
        {:ok, mob_id} -> {:ok, mob_id}
        :error -> {:skip, {quest_id, :drop_mob, name}}
      end
    end
  end

  defp drop_mob(_quest_id, _row, _resolvers), do: {:ok, 0}

  @spec existing_or_new_drop(integer(), map(), integer(), map()) ::
          {:ok, map()} | {:skip, dropped()}
  defp existing_or_new_drop(quest_id, row, mob_id, by_key) do
    case Map.fetch(by_key, mob_id) do
      {:ok, drop} -> {:ok, drop}
      :error when not is_map_key(row, "Item") -> {:skip, {quest_id, :drop_invalid, "no Item"}}
      :error when not is_map_key(row, "Rate") -> {:skip, {quest_id, :drop_invalid, "no Rate"}}
      :error -> {:ok, %{mob_id: mob_id}}
    end
  end

  @spec drop_item(integer(), map(), map(), resolvers()) :: {:ok, map()} | {:skip, dropped()}
  defp drop_item(quest_id, %{"Item" => value}, drop, resolvers) do
    with {:ok, name} <- scalar(quest_id, "drop Item", value) do
      case resolvers.item.(name) do
        {:ok, %{id: item_id, stackable?: stackable?}} ->
          {:ok, Map.merge(drop, %{item_id: item_id, stackable?: stackable?})}

        :error ->
          {:skip, {quest_id, :drop_item, name}}
      end
    end
  end

  defp drop_item(_quest_id, _row, drop, _resolvers), do: {:ok, drop}

  @spec drop_count(integer(), map(), map(), boolean()) :: {:ok, map()} | {:skip, dropped()}
  defp drop_count(quest_id, %{"Count" => count}, drop, _existing?) do
    if uint16?(count),
      do: {:ok, Map.put(drop, :count, if(drop.stackable?, do: count, else: 1))},
      else: invalid(quest_id, "drop Count #{inspect(count)}")
  end

  defp drop_count(_quest_id, _row, drop, true), do: {:ok, drop}
  defp drop_count(_quest_id, _row, drop, false), do: {:ok, Map.put(drop, :count, 1)}

  @spec drop_rate(integer(), map(), integer(), map()) ::
          {:ok, integer(), map()} | {:skip, dropped()}
  defp drop_rate(quest_id, %{"Rate" => rate}, mob_id, drop) do
    if uint16?(rate),
      do: {:ok, mob_id, Map.put(drop, :rate, rate)},
      else: invalid(quest_id, "drop Rate #{inspect(rate)}")
  end

  defp drop_rate(_quest_id, _row, mob_id, drop), do: {:ok, mob_id, drop}

  @spec scalar(integer(), String.t(), term()) :: {:ok, String.t()} | {:skip, dropped()}
  defp scalar(_quest_id, _field, value)
       when is_binary(value) or is_number(value) or is_boolean(value),
       do: {:ok, to_string(value)}

  defp scalar(quest_id, field, value), do: invalid(quest_id, "#{field} #{inspect(value)}")

  @spec check(boolean(), integer(), String.t()) :: :ok | {:skip, dropped()}
  defp check(true, _quest_id, _reason), do: :ok
  defp check(false, quest_id, reason), do: invalid(quest_id, reason)

  @spec invalid(integer(), String.t()) :: {:skip, dropped()}
  defp invalid(quest_id, reason), do: {:skip, {quest_id, :invalid, reason}}

  @spec uint16?(term()) :: boolean()
  defp uint16?(value), do: is_integer(value) and value in @uint16
end
