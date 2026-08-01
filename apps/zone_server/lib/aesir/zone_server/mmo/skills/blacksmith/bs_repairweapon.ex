defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsRepairweapon do
  @moduledoc """
  Weapon Repair (BS_REPAIRWEAPON). Offers one repairable broken equipment row
  from the caster or a nearby player and repairs it with the caster's material.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 108,
    name: :bs_repairweapon,
    display_name: "Weapon Repair",
    max_level: 1,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 2,
    cast_time: [2_500],
    fixed_cast_time: [2_500],
    sp_cost: [30]

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.BreakOps
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Menu

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, target, level, %Definition{} = definition) do
    target_id = Active.resolve_target_id(caster, target)

    with {:ok, target_state, _pid} <- resolve_target(caster, target_id),
         slots when slots != [] <- repairable_slots(target_state.inventory) do
      offer = %{
        skill_id: definition.id,
        kind: :INVENTORY_SLOTS,
        entry_ids: slots,
        level: level
      }

      {:ok, %{caster | target_id: target_id, pending_menu_offer: offer}}
    else
      {:error, reason} -> {:error, reason}
      [] -> {:error, :no_repairable_items}
    end
  end

  @impl Menu
  @spec on_menu_reply(
          PlayerState.t(),
          %{id: non_neg_integer(), extras: [non_neg_integer()]},
          pos_integer()
        ) :: {:ok, PlayerState.t()} | {:error, atom()}
  def on_menu_reply(%PlayerState{target_id: target_id} = caster, %{id: slot}, _level) do
    with {:ok, target_state, target_pid} <- resolve_target(caster, target_id),
         %InventoryItem{attribute: 1} = item <- Map.get(target_state.inventory, slot),
         {:ok, material_id} <- material_for(item),
         :ok <- require_material(caster.inventory, material_id),
         {:ok, repaired_caster} <- repair_target(caster, target_id, target_pid, slot),
         {:ok, consumed} <- consume_material(repaired_caster, material_id) do
      {:ok, consumed}
    else
      nil -> {:error, :repair_failed}
      %InventoryItem{} -> {:error, :repair_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_target(%PlayerState{character_id: target_id} = caster, target_id),
    do: {:ok, caster, caster.process_pid}

  defp resolve_target(%PlayerState{} = caster, target_id) do
    with {:ok, {_module, %PlayerState{} = target, pid}} <-
           UnitRegistry.get_unit(:player, target_id),
         true <- nearby?(caster, target) do
      {:ok, target, pid}
    else
      false -> {:error, :target_out_of_range}
      {:error, :not_found} -> {:error, :invalid_target}
    end
  end

  defp nearby?(caster, target) do
    caster.map_name == target.map_name and
      Geometry.in_tile_range?(caster.x, caster.y, target.x, target.y, 2)
  end

  defp repairable_slots(inventory) do
    inventory
    |> Enum.filter(fn
      {_slot, %InventoryItem{attribute: 1} = item} -> match?({:ok, _}, material_for(item))
      _normal_or_non_item -> false
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp material_for(%InventoryItem{nameid: item_id}) do
    case Items.by_id(item_id) do
      {:ok, %{type: :weapon, weapon_level: 1}} -> {:ok, 1_002}
      {:ok, %{type: :weapon, weapon_level: 2}} -> {:ok, 998}
      {:ok, %{type: :weapon, weapon_level: 3}} -> {:ok, 999}
      {:ok, %{type: :weapon, weapon_level: 4}} -> {:ok, 756}
      {:ok, %{type: :armor, armor_level: 1}} -> {:ok, 999}
      {:ok, _unrepairable} -> {:error, :unrepairable_item}
      :error -> {:error, :unknown_item}
    end
  end

  defp require_material(inventory, material_id) do
    if ItemContainer.held_amount(inventory, material_id) >= 1,
      do: :ok,
      else: {:error, :no_materials}
  end

  defp repair_target(%PlayerState{character_id: target_id} = caster, target_id, _pid, slot) do
    case BreakOps.repair(caster, slot) do
      {:ok, ^caster} -> {:error, :repair_failed}
      {:ok, repaired} -> {:ok, stage_repaired_notify(repaired, slot)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp repair_target(caster, _target_id, target_pid, slot) do
    case PlayerSession.repair_item(target_pid, slot) do
      :ok -> {:ok, caster}
      {:error, reason} -> {:error, reason}
    end
  end

  # The cross-player path pushes the repaired row from inside the target's own
  # session. A self-repair never enters a session call, so it stages the same
  # notification here; without it the caster's client keeps showing the row
  # broken until relog and refuses to equip it.
  defp stage_repaired_notify(%PlayerState{} = state, slot) do
    change = {:added, slot, Map.get(state.inventory, slot)}

    %{state | pending_inventory_notify: state.pending_inventory_notify ++ [change]}
  end

  defp consume_material(caster, material_id) do
    index = ItemContainer.stackable_index(caster.inventory, material_id)

    with {:ok, inventory, change} <- ItemContainer.remove(caster.inventory, index, 1) do
      {:ok,
       %{
         caster
         | inventory: inventory,
           pending_inventory_persist:
             caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
       }}
    end
  end
end
