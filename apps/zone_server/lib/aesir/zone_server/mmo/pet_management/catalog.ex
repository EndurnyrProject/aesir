defmodule Aesir.ZoneServer.Mmo.PetManagement.Catalog do
  @moduledoc """
  Runtime pet catalog loaded from `pets.yml` into `:persistent_term`.

  Only three lookups exist: by mob, by egg item, and whether an item is a
  taming item. When several pets share an egg item, `by_egg/1` returns the one
  with the lowest mob id; the original pick follows hash map order, which no
  id order reproduces.
  """

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition

  @pt_key __MODULE__

  @doc "Returns every pet ordered by mob id."
  @spec all() :: [PetDefinition.t()]
  def all, do: index().all

  @doc "Looks up a pet by its mob id."
  @spec by_mob(pos_integer()) :: {:ok, PetDefinition.t()} | :error
  def by_mob(mob_id), do: Map.fetch(index().by_mob, mob_id)

  @doc "Looks up the pet hatched from an egg item; the lowest mob id wins a shared egg."
  @spec by_egg(pos_integer()) :: {:ok, PetDefinition.t()} | :error
  def by_egg(item_id), do: Map.fetch(index().by_egg, item_id)

  @doc "Whether an item is some pet's taming item."
  @spec tame_item?(pos_integer()) :: boolean()
  def tame_item?(item_id), do: MapSet.member?(index().tame_items, item_id)

  @doc "Reloads the catalog from the active mode's data files."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, load())
    :ok
  end

  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        :ok = reload()
        :persistent_term.get(@pt_key)

      index ->
        index
    end
  end

  defp load do
    pets =
      "pets.yml"
      |> Source.sources()
      |> Enum.flat_map(&YamlElixir.read_from_file!/1)
      |> DataLoader.merge_by_key(& &1["mob_id"])
      |> Enum.map(&definition/1)
      |> Enum.sort_by(& &1.mob_id)

    %{
      all: pets,
      by_mob: Map.new(pets, &{&1.mob_id, &1}),
      by_egg: pets |> Enum.reverse() |> Map.new(&{&1.egg_item_id, &1}),
      tame_items: for(%{tame_item_id: id} <- pets, id != 0, into: MapSet.new(), do: id)
    }
  end

  defp definition(row) do
    %PetDefinition{
      mob_id: row["mob_id"],
      tame_item_id: row["tame_item_id"],
      egg_item_id: row["egg_item_id"],
      equip_item_id: row["equip_item_id"],
      food_item_id: row["food_item_id"],
      fullness: row["fullness"],
      hungry_delay_ms: row["hungry_delay_ms"],
      hunger_increase: row["hunger_increase"],
      intimacy_start: row["intimacy_start"],
      intimacy_fed: row["intimacy_fed"],
      intimacy_overfed: row["intimacy_overfed"],
      intimacy_hungry: row["intimacy_hungry"],
      intimacy_owner_die: row["intimacy_owner_die"],
      capture_rate: row["capture_rate"],
      special_performance: row["special_performance"],
      attack_rate: row["attack_rate"],
      retaliate_rate: row["retaliate_rate"],
      change_target_rate: row["change_target_rate"],
      allow_auto_feed: row["allow_auto_feed"],
      bonus_program: bonus_program(row["bonus_program"]),
      support_ops: Enum.map(row["support_ops"], &support_op/1),
      evolution:
        Enum.map(row["evolution"], fn evolution ->
          %{
            target_mob_id: evolution["target_mob_id"],
            requirements:
              Enum.map(
                evolution["requirements"],
                &%{item_id: &1["item_id"], amount: &1["amount"]}
              )
          }
        end)
    }
  end

  defp bonus_program(nil), do: []
  defp bonus_program(source), do: EquipScript.parse!(source)

  defp support_op([name | args]) do
    List.to_tuple([String.to_atom(name) | Enum.map(args, &support_arg/1)])
  end

  defp support_arg(value) when is_binary(value), do: String.to_atom(value)
  defp support_arg(value), do: value
end
