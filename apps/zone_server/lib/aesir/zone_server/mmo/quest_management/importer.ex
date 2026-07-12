defmodule Aesir.ZoneServer.Mmo.QuestManagement.Importer do
  @moduledoc """
  Converts rAthena `quest_db.yml` entries into `QuestDefinition` structs, and
  `QuestDefinition` structs back into our own-schema YAML maps.

  Target `Mob`/`MapMobTargets` names and Drop `Mob`/`Item` names are resolved
  against the imported mob/item db (`Mmo.MobManagement.Mobs`,
  `Mmo.ItemManagement.Items`). A name that doesn't resolve is dropped - the
  whole target for an unresolvable `Mob`, a single name for an unresolvable
  `MapMobTargets`/`Drop` reference - and reported back so the quest is
  imported with the rest of its data intact instead of failing the run.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition

  @typedoc "An unresolvable Target/Drop reference dropped during import."
  @type dropped ::
          {quest_id :: integer(), kind :: :target_mob | :map_mob_target | :drop_mob | :drop_item,
           name :: String.t()}

  @always [:id, :title]
  @defaults Map.from_struct(struct(QuestDefinition, %{}))

  @doc """
  Converts a raw rAthena quest_db entry into a `QuestDefinition`, along with
  the list of Target/Drop references that failed mob/item resolution.
  """
  @spec to_definition(map()) :: {QuestDefinition.t(), [dropped()]}
  def to_definition(entry) do
    id = Map.fetch!(entry, "Id")
    {targets, target_dropped} = targets(id, Map.get(entry, "Targets") || [])
    {drops, drop_dropped} = drops(id, Map.get(entry, "Drops") || [])

    definition = %QuestDefinition{
      id: id,
      title: Map.fetch!(entry, "Title"),
      time_limit: Map.get(entry, "TimeLimit"),
      targets: targets,
      drops: drops
    }

    {definition, target_dropped ++ drop_dropped}
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

  @spec targets(integer(), [map()]) :: {[QuestDefinition.target()], [dropped()]}
  defp targets(quest_id, raw_targets) do
    raw_targets
    |> Enum.reject(&(Map.get(&1, "Count") == 0))
    |> Enum.reduce({[], []}, fn raw, {kept, dropped} ->
      case target(quest_id, raw) do
        {:ok, target, entry_dropped} -> {[target | kept], dropped ++ entry_dropped}
        {:error, entry_dropped} -> {kept, dropped ++ entry_dropped}
      end
    end)
    |> then(fn {kept, dropped} -> {Enum.reverse(kept), dropped} end)
  end

  @spec target(integer(), map()) ::
          {:ok, QuestDefinition.target(), [dropped()]} | {:error, [dropped()]}
  defp target(quest_id, raw) do
    case target_mob(quest_id, raw) do
      {:ok, mob_id} ->
        {mobs_allowed, dropped} = map_mob_targets(quest_id, raw)

        target =
          %{
            mob_id: mob_id,
            count: Map.fetch!(raw, "Count"),
            min_level: Map.get(raw, "MinLevel"),
            max_level: Map.get(raw, "MaxLevel"),
            race: Map.get(raw, "Race"),
            size: Map.get(raw, "Size"),
            element: Map.get(raw, "Element"),
            map: Map.get(raw, "Location"),
            mobs_allowed: mobs_allowed
          }
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        {:ok, target, dropped}

      {:error, dropped} ->
        {:error, [dropped]}
    end
  end

  @spec target_mob(integer(), map()) :: {:ok, integer() | nil} | {:error, dropped()}
  defp target_mob(quest_id, %{"Mob" => name}) when is_binary(name) do
    case Mobs.by_name(name) do
      {:ok, %{id: id}} -> {:ok, id}
      :error -> {:error, {quest_id, :target_mob, name}}
    end
  end

  defp target_mob(_quest_id, _raw), do: {:ok, nil}

  @spec map_mob_targets(integer(), map()) :: {[integer()] | nil, [dropped()]}
  defp map_mob_targets(quest_id, %{"MapMobTargets" => raw}) when is_map(raw) do
    raw
    |> Enum.filter(fn {_name, allowed?} -> allowed? end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.reduce({[], []}, fn name, {ids, dropped} ->
      case Mobs.by_name(name) do
        {:ok, %{id: id}} -> {[id | ids], dropped}
        :error -> {ids, [{quest_id, :map_mob_target, name} | dropped]}
      end
    end)
    |> then(fn {ids, dropped} -> {Enum.reverse(ids), Enum.reverse(dropped)} end)
  end

  defp map_mob_targets(_quest_id, _raw), do: {nil, []}

  @spec drops(integer(), [map()]) :: {[QuestDefinition.drop()], [dropped()]}
  defp drops(quest_id, raw_drops) do
    Enum.reduce(raw_drops, {[], []}, fn raw, {kept, dropped} ->
      case drop(quest_id, raw) do
        {:ok, drop} -> {[drop | kept], dropped}
        {:error, entry_dropped} -> {kept, [entry_dropped | dropped]}
      end
    end)
    |> then(fn {kept, dropped} -> {Enum.reverse(kept), Enum.reverse(dropped)} end)
  end

  @spec drop(integer(), map()) :: {:ok, QuestDefinition.drop()} | {:error, dropped()}
  defp drop(quest_id, raw) do
    mob_ref = Map.get(raw, "Mob", 0)
    item_name = Map.fetch!(raw, "Item")

    case {resolve_mob(mob_ref), Items.by_aegis(item_name)} do
      {{:ok, mob_id}, {:ok, %{id: item_id}}} ->
        {:ok,
         %{
           mob_id: mob_id,
           item_id: item_id,
           count: Map.get(raw, "Count", 1),
           rate: Map.fetch!(raw, "Rate")
         }}

      {{:error, name}, _} ->
        {:error, {quest_id, :drop_mob, name}}

      {_, :error} ->
        {:error, {quest_id, :drop_item, item_name}}
    end
  end

  @spec resolve_mob(integer() | String.t()) :: {:ok, integer()} | {:error, String.t()}
  defp resolve_mob(0), do: {:ok, 0}

  defp resolve_mob(name) when is_binary(name) do
    case Mobs.by_name(name) do
      {:ok, %{id: id}} -> {:ok, id}
      :error -> {:error, name}
    end
  end
end
