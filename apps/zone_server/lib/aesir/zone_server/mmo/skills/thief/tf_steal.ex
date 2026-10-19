defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfSteal do
  @moduledoc """
  Steal (TF_STEAL) and Gank's item theft, both running one steal recipe.

  The monster's own session decides the theft (`MobSession.attempt_steal/3`):
  the chance is (caster DEX - monster DEX) / 2 + 6 per level + 4 percent plus
  the caster's equipment steal-rate bonus. Renewal rolls that chance once and
  then tries each stealable drop at its own rate; pre-renewal never rolls the
  chance alone and scales every drop's rate by it. A monster already stolen
  from, with a master, status-immune, of the Treasure group, or on a no-loot
  map refuses and stays refused; one in any body state other than Burning
  (petrifying, petrified, frozen, stunned, sleeping, ...) refuses only while
  that lasts.

  A stolen weapon, armour, pet armour or shadow gear arrives unidentified. The
  monster is spent once an item is chosen, even when the caster cannot carry it.

  A Steal cast that fails still spends its SP and reports the failure. Only a
  player steals; any other caster's cast does nothing. Gank (`gank/4`) calls the
  same recipe directly on a landed normal hit, with no cast requirements.
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

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: CasterPlayer
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.StealOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @steal_id 50
  @gank_id 210

  @typedoc "Why a steal took no item: a monster refusal or the caster could not carry it."
  @type failure :: StealOps.reason() | :item_rejected

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:failed, PlayerState.t(), failure()} | {:error, :not_found}
  def cast(%PlayerState{} = caster, {:unit, target}, level, _definition) do
    case monster_pid(target) do
      {:ok, pid} -> settle(steal(caster, pid, level))
      :not_a_monster -> {:failed, caster, :not_a_monster}
      {:error, :not_found} = error -> error
    end
  end

  def cast(caster, _target, _level, _definition), do: {:ok, caster}

  @doc """
  Gank's theft on a landed non-bow normal hit against a monster.

  Rolls the Gank chance per mille, then steals at the caster's Steal level
  with no cast requirements. A success shows Steal at the Gank level around
  the monster; a failure reports Gank's failure to the caster.
  """
  @spec gank(state, pos_integer(), pid(), {integer(), integer()}) :: state when state: term()
  def gank(%PlayerState{} = caster, mob_id, mob_pid, {x, y}) do
    chance = Passives.steal_proc(caster)

    if Stats.weapon_type(caster.stats.equipment) != :bow and chance > 0 and
         :rand.uniform(1_000) - 1 < chance do
      case steal(caster, mob_pid, CasterPlayer.skill_level(caster, @steal_id)) do
        {:ok, updated} ->
          show_gank(updated, mob_id, {x, y})
          updated

        {:error, _reason, updated} ->
          SkillHandler.report_cast_failure(@gank_id, caster.character_id, :steal_failed)
          updated
      end
    else
      caster
    end
  end

  def gank(non_player, _mob_id, _mob_pid, _position), do: non_player

  # A bare number is resolved through the shared ID index, so a non-monster
  # with that number is never confused with a monster.
  defp monster_pid({:mob, id}), do: registered_mob_pid(id)
  defp monster_pid({_type, _id}), do: :not_a_monster

  defp monster_pid(id) when is_integer(id) do
    case UnitRegistry.unit_type_for(id) do
      {:ok, :mob} -> registered_mob_pid(id)
      {:ok, _type} -> :not_a_monster
      {:error, :not_found} = error -> error
    end
  end

  defp registered_mob_pid(id) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_module, _state, pid}} -> {:ok, pid}
      {:error, :not_found} = error -> error
    end
  end

  defp settle({:ok, caster}), do: {:ok, caster}
  defp settle({:error, reason, caster}), do: {:failed, caster, reason}

  @spec steal(PlayerState.t(), pid(), non_neg_integer()) ::
          {:ok, PlayerState.t()} | {:error, failure(), PlayerState.t()}
  defp steal(caster, mob_pid, level) do
    with {:ok, item_id} <- MobSession.attempt_steal(mob_pid, item_caster(caster), level),
         {:ok, item_def} <- ItemManagement.get_item_by_id(item_id),
         {:ok, inventory, change} <- add_item(caster, item_def) do
      {:ok,
       %{
         caster
         | inventory: inventory,
           pending_inventory_notify: caster.pending_inventory_notify ++ [change]
       }}
    else
      {:error, reason} ->
        {:error, failure_reason(reason), caster}
    end
  end

  defp failure_reason(reason)
       when reason in [:immune, :protected, :already_stolen, :status_blocked, :miss, :no_drop],
       do: reason

  defp failure_reason(_inventory_rejection), do: :item_rejected

  defp item_caster(caster) do
    %{
      dex: Stats.get_effective_stat(caster.stats, :dex),
      add_steal_rate: Stats.get_equipment_modifier(caster.stats, :add_steal_rate)
    }
  end

  defp add_item(%{character_id: id, inventory: inventory, stats: stats}, item_def) do
    if ItemDefinition.identified_on_obtain?(item_def),
      do: InventoryOps.add(id, inventory, stats, item_def, 1),
      else: InventoryOps.add(id, inventory, stats, item_def, 1, %{identify: 0})
  end

  defp show_gank(caster, mob_id, {x, y}) do
    Broadcast.to_in_range(caster.map_name, x, y, Config.view_range(), %SkillEffect{
      skill_id: @steal_id,
      level: CasterPlayer.skill_level(caster, @gank_id),
      target_id: mob_id,
      src_id: caster.character_id,
      result: 1
    })
  end
end
