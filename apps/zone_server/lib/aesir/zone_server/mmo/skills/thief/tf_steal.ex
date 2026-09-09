defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfSteal do
  @moduledoc """
  Steal (TF_STEAL). Attempts to steal one item from a mob, once per instance.

  Steal chance: rate% = `(dex - mob_dex)/2 + 6*level + 4`,
  rolled out of 100; bosses and mobs already stolen from reject outright. On a
  successful roll the mob's drop table is walked in order (`steal_protected`
  entries skipped) and the first drop whose `rnd(10000) <= rate` wins. The
  atomic rate roll, drop roll and `stolen_from` flip run inside the mob's own
  process (`MobSession.attempt_steal/3`) so a mob can only be stolen from once
  regardless of concurrent attempts. Items only.

  Renewal: the steal chance ((caster DEX − target DEX) / 2 + 6 per level + 4 percent) is rolled once, then each drop is tried at its own rate. Pre-renewal: the chance is never rolled alone; every drop's rate is scaled by it. Both modes: a chance below 1 percent fails, bosses and already-stolen monsters refuse, and the first drop to succeed is taken.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 50,
    name: :tf_steal,
    display_name: "Steal",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    sp_cost: List.duplicate(10, 10)

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, _definition) do
    caster_dex = Stats.get_effective_stat(caster.stats, :dex)

    with {:ok, {_module, _state, pid}} <- UnitRegistry.get_unit(:mob, target_id),
         {:ok, item_id} <- MobSession.attempt_steal(pid, caster_dex, level),
         {:ok, item_def} <- ItemManagement.get_item_by_id(item_id),
         {:ok, persisted, change} <-
           InventoryOps.add(caster.character_id, caster.inventory, caster.stats, item_def, 1) do
      updated =
        caster
        |> Map.put(:inventory, persisted)
        |> Map.update!(:pending_inventory_notify, &(&1 ++ [change]))

      {:ok, updated}
    end
  end
end
