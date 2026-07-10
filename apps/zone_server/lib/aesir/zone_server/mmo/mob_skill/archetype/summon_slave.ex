defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.SummonSlave do
  @moduledoc """
  Summons slave mobs linked to their master (`NPC_SUMMONSLAVE`, `NPC_CALLSLAVE`).

  The slave mob ids come from the row's `val1..val5`, which the importer nests
  under `condition` (rAthena packs them into the skill row's condition columns);
  the Executor forwards the row's condition map in `params`. Mirroring rAthena's
  `mob_summonslave`, one cast summons `level` slaves, cycling through the
  configured ids. Each slave spawns via `Coordinator.summon_mob/5` with
  `master_id:` set to the caster's instance id, which drives the `slavele`
  skill condition and composes with the `owner_event` death mechanism.

  A hard per-master cap of 5 living slaves bounds runaway rows: a cast only
  summons up to the remaining headroom, and with no headroom (or no valid val
  ids) it is a no-op `:ok` — the skill still goes on cooldown at the cast site,
  so there is no retry spam and nothing to surface as an error.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @slave_cap 5

  @val_keys [:val1, :val2, :val3, :val4, :val5]

  @impl true
  def apply(%MobState{} = caster, _target, params, level) do
    slave_ids = slave_ids(params)
    headroom = @slave_cap - count_living_slaves(caster.instance_id)
    amount = max(min(level, headroom), 0)

    if slave_ids != [] and amount > 0 do
      slave_ids
      |> Stream.cycle()
      |> Enum.take(amount)
      |> Enum.each(&summon(caster, &1))
    end

    :ok
  end

  @doc """
  Counts the living slaves linked to `master_id`.

  Living means still registered: the map coordinator unregisters a mob from
  `UnitRegistry` when it dies, so registry membership is the liveness signal
  (mob snapshots in the registry are not otherwise refreshed, but `master_id`
  is immutable after spawn).
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

  # NOTE: slaves spawn on the caster's cell; the coordinator's scatter/area
  # placement is private, expose it if stacked summons ever matter visually.
  defp summon(%MobState{} = caster, mob_id) do
    Coordinator.summon_mob(caster.map_name, mob_id, caster.x, caster.y,
      master_id: caster.instance_id
    )
  end

  defp slave_ids(%{condition: condition}) do
    @val_keys
    |> Enum.map(&Map.get(condition, &1))
    |> Enum.filter(&(is_integer(&1) and &1 > 0))
  end

  defp slave_ids(_params), do: []
end
