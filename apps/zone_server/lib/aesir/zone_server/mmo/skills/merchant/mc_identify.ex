defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McIdentify do
  @moduledoc """
  Item Appraisal (MC_IDENTIFY). Offers the caster's unidentified inventory slots
  and identifies the selected row.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 40,
    name: :mc_identify,
    display_name: "Item Appraisal",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 1,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Unit.ItemContainer

  @behaviour Active
  @behaviour Menu

  @impl Active
  def cast(caster, :self, level, definition) do
    slots = unidentified_slots(caster.inventory)

    if slots == [] do
      {:error, :no_unidentified_items}
    else
      offer = %{skill_id: definition.id, kind: :INVENTORY_SLOTS, entry_ids: slots, level: level}
      {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @impl Menu
  def on_menu_reply(caster, %{id: slot, extras: _extras}, _level) do
    with {:ok, inventory, change} <- ItemContainer.identify(caster.inventory, slot) do
      {:ok,
       %{
         caster
         | inventory: inventory,
           pending_inventory_persist:
             caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
       }}
    end
  end

  defp unidentified_slots(inventory) do
    inventory
    |> Enum.filter(fn {_slot, item} -> item.identify == 0 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end
end
