defmodule Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon do
  @moduledoc """
  Follower summons from a monster skill row's consecutive valid species IDs.

  A cast creates its full requested amount, cycling through up to five species,
  with a random initial species when fewer followers than species are requested.
  Each follower appears within two cells of its master, falling back to the
  master's cell when no nearby terrain is available. Skill conditions, not a
  separate follower cap, limit repeated summons.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.Slaves
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @val_keys [:val1, :val2, :val3, :val4, :val5]

  @doc "Summons followers and returns the master's updated summon bookkeeping; invalid rows do nothing."
  @spec summon(MobState.t(), pos_integer(), map()) :: :ok | {:ok, MobState.t()}
  def summon(%MobState{} = caster, amount, row) do
    case slave_ids(row) do
      [] ->
        :ok

      ids ->
        offset = if amount < length(ids), do: :rand.uniform(length(ids)) - 1, else: 0

        ids
        |> Stream.cycle()
        |> Stream.drop(offset)
        |> Enum.take(amount)
        |> Enum.each(&spawn_slave(caster, &1))

        {:ok, %{caster | can_summon: true}}
    end
  end

  @doc "Counts living followers on the registered master's current map."
  @spec count_living_slaves(integer()) :: non_neg_integer()
  def count_living_slaves(master_id) do
    case UnitRegistry.get_unit(:mob, master_id) do
      {:ok, {_, %MobState{} = master, _}} -> length(Slaves.linked(master))
      _missing -> 0
    end
  end

  defp spawn_slave(caster, mob_id) do
    {x, y} = Cell.random_traversable_near(caster.map_name, {caster.x, caster.y}, 2)
    Coordinator.summon_mob(caster.map_name, mob_id, x, y, master_id: caster.instance_id)
  end

  defp slave_ids(%{condition: condition}) do
    @val_keys
    |> Enum.map(&Map.get(condition, &1))
    |> Enum.take_while(&(is_integer(&1) and &1 > 0 and match?({:ok, _}, Mobs.by_id(&1))))
  end

  defp slave_ids(_row), do: []
end
