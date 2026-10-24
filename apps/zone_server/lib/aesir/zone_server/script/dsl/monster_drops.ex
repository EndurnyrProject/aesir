defmodule Aesir.ZoneServer.Script.Dsl.MonsterDrops do
  @moduledoc """
  Script buildins that edit a monster's drop table while the server runs:
  every monster of that kind drops from the edited table from then on.

  A monster is given by id or by name (`Mobs.search_name/1`). Both return
  `{ctx, result}`. Imported into scripts via the `Aesir.ZoneServer.Script.Dsl`
  facade.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Script.Ctx

  @max_drops 10
  @option_types [:weapon, :armor, :shadow_gear]

  @doc """
  Sets monster `mob`'s drop of item `item_id` to `rate` (1..10000): the first
  drop of that item is updated in place, otherwise a new drop is added when
  the table holds fewer than 10. `steal_protected` above 0 shields it from
  Steal; `group`, when given, is a random option group id, allowed only for
  weapons, armour and shadow gear. Returns 1 on a change, 0 when the monster,
  item, rate or group is invalid or the table is full.
  """
  @spec addmonsterdrop(
          Ctx.t(),
          integer() | String.t(),
          integer(),
          integer(),
          integer(),
          integer() | nil
        ) :: {Ctx.t(), 0 | 1}
  def addmonsterdrop(ctx, mob, item_id, rate, steal_protected \\ 0, group \\ nil)

  def addmonsterdrop(%Ctx{status: {:error, _}} = ctx, _mob, _item, _rate, _steal, _group),
    do: {ctx, 0}

  def addmonsterdrop(%Ctx{} = ctx, mob, item_id, rate, steal_protected, group) do
    with {:ok, mob} <- find_mob(mob),
         {:ok, item} <- Items.by_id(item_id),
         true <- rate in 1..10_000,
         {:ok, group_name} <- option_group(group, item),
         {:ok, _drops} <-
           Mobs.update_drops(mob.id, &put_drop(&1, item, rate, steal_protected > 0, group_name)) do
      {ctx, 1}
    else
      _ -> {ctx, 0}
    end
  end

  @doc """
  Removes every drop of item `item_id` from monster `mob`'s table. Returns 1
  when one was removed and 0 when the monster drops no such item; an unknown
  item or monster fails the command, pushes nothing (read here as 0) and the
  script goes on.
  """
  @spec delmonsterdrop(Ctx.t(), integer() | String.t(), integer()) :: {Ctx.t(), 0 | 1}
  def delmonsterdrop(%Ctx{status: {:error, _}} = ctx, _mob, _item_id), do: {ctx, 0}

  def delmonsterdrop(%Ctx{} = ctx, mob, item_id) do
    with {:item, {:ok, item}} <- {:item, Items.by_id(item_id)},
         {:mob, {:ok, mob}} <- {:mob, find_mob(mob)} do
      case Mobs.update_drops(mob.id, &remove_drop(&1, item)) do
        {:ok, _drops} -> {ctx, 1}
        :none -> {ctx, 0}
      end
    else
      {:item, :error} -> {Ctx.fail(ctx, :delmonsterdrop, :unknown_item), 0}
      {:mob, :error} -> {Ctx.fail(ctx, :delmonsterdrop, :unknown_mob), 0}
    end
  end

  defp find_mob(name) when is_binary(name), do: Mobs.by_id(Mobs.search_name(name))
  defp find_mob(id) when is_integer(id), do: Mobs.by_id(id)

  defp option_group(nil, _item), do: {:ok, nil}

  defp option_group(id, %ItemDefinition{type: type}) when type in @option_types do
    case RandomOptions.group(id) do
      {:ok, group} -> {:ok, group.name}
      :error -> :error
    end
  end

  defp option_group(_id, _item), do: :error

  defp put_drop(drops, item, rate, steal_protected, group_name) do
    drop = %MobDrop{
      item: item.aegis_name,
      rate: rate,
      steal_protected: steal_protected,
      random_option_group: group_name
    }

    case Enum.find_index(drops, &drops?(&1, item)) do
      nil when length(drops) >= @max_drops -> :full
      nil -> {:ok, drops ++ [drop]}
      index -> {:ok, List.replace_at(drops, index, drop)}
    end
  end

  defp remove_drop(drops, item) do
    case Enum.reject(drops, &drops?(&1, item)) do
      ^drops -> :none
      kept -> {:ok, kept}
    end
  end

  defp drops?(%MobDrop{item: aegis}, %ItemDefinition{id: id}) do
    match?({:ok, %ItemDefinition{id: ^id}}, Items.by_aegis(aegis))
  end
end
