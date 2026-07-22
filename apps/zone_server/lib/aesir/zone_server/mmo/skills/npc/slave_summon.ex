defmodule Aesir.ZoneServer.Mmo.Skills.Npc.SlaveSummon do
  @moduledoc """
  Shared summon logic behind `NPC_SUMMONSLAVE` and `NPC_CALLSLAVE`.

  Both rAthena skills share `mob_summonslave` semantics: one cast summons
  `level` slaves from the row's `condition.val1..val5` ids (the importer nests
  rAthena's val columns there), cycling through the configured ids. Each
  slave spawns via `Coordinator.summon_mob/5` on the caster's own cell with
  `master_id:` set to the caster's instance id, which drives the `slavele`
  skill condition and composes with the `owner_event` death mechanism.

  A hard per-master cap of 5 living slaves bounds runaway rows: a cast only
  summons up to the remaining headroom, and with no headroom it is a no-op
  `:ok` (the skill still goes on cooldown at the cast site, so there is no
  retry spam). A row with no valid slave id is a clean `{:error, _}` abort.
  """

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @slave_cap 5
  @val_keys [:val1, :val2, :val3, :val4, :val5]

  @doc """
  Summons up to `level` slaves for `caster`, cycling through the row's valid
  slave ids and capped at the remaining headroom under the 5-living-slave cap.

  Returns `{:error, :no_slave_ids}` when the row carries no valid id.
  """
  @spec summon(MobState.t(), pos_integer(), map()) :: :ok | {:error, :no_slave_ids}
  def summon(%MobState{} = caster, level, row) do
    case slave_ids(row) do
      [] ->
        {:error, :no_slave_ids}

      ids ->
        headroom = @slave_cap - count_living_slaves(caster.instance_id)
        amount = max(min(level, headroom), 0)

        ids
        |> Stream.cycle()
        |> Enum.take(amount)
        |> Enum.each(&spawn_slave(caster, &1))

        :ok
    end
  end

  @doc """
  Counts the living slaves linked to `master_id`.

  Living means still registered: the map coordinator unregisters a mob from
  `UnitRegistry` when it dies, so registry membership is the liveness signal
  (mob snapshots in the registry are not otherwise refreshed, but `master_id`
  is immutable after spawn). Also backs the `Selector`'s `slavele` condition
  gate.
  """
  @spec count_living_slaves(integer()) :: non_neg_integer()
  def count_living_slaves(master_id) do
    :mob
    |> UnitRegistry.list_units_by_type()
    |> Enum.count(fn id ->
      match?(
        {:ok, {_module, %MobState{master_id: ^master_id, is_dead: false}, _pid}},
        UnitRegistry.get_unit(:mob, id)
      )
    end)
  end

  defp spawn_slave(%MobState{} = caster, mob_id) do
    Coordinator.summon_mob(caster.map_name, mob_id, caster.x, caster.y,
      master_id: caster.instance_id
    )
  end

  defp slave_ids(%{condition: condition}) do
    @val_keys
    |> Enum.map(&Map.get(condition, &1))
    |> Enum.filter(&(is_integer(&1) and &1 > 0))
  end

  defp slave_ids(_row), do: []
end
