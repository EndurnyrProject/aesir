defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaCreatecon do
  @moduledoc """
  Create Elemental Converter (SA_CREATECON). A quest skill for 30 SP that offers
  the converters the caster holds a blank scroll and the matching ore for, and
  brews one of the chosen kind; the materials are re-checked on reply.

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1007,
    name: :sa_createcon,
    display_name: "Create Elemental Converter",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: [30],
    quest_skill: true,
    quest_owner_job: :sage,
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps

  @behaviour Active
  @behaviour Menu

  # Each converter costs one Blank Scroll plus one elemental material, in the
  # canonical menu order. Materials are keyed by numeric id because three items'
  # internal names differ
  # from their display names (990 `Boody_Red` "Red Blood", 993 `Yellow_Live`
  # "Green Live", 7433 `Scroll` "Blank Scroll"), so the ids are the only stable
  # handle.
  @blank_scroll 7433
  @recipes [
    {12_114, [{@blank_scroll, 1}, {990, 1}]},
    {12_115, [{@blank_scroll, 1}, {991, 1}]},
    {12_116, [{@blank_scroll, 1}, {993, 1}]},
    {12_117, [{@blank_scroll, 1}, {992, 1}]}
  ]

  @impl Active
  def cast(caster, :self, level, definition) do
    case Enum.filter(@recipes, fn {_id, materials} -> holds?(caster, materials) end) do
      [] ->
        # The reference sends the converter list after the requirement is paid,
        # empty or not, so the cast reports its failure with the cost kept.
        {:failed, caster, :no_materials}

      brewable ->
        offer = %{
          skill_id: definition.id,
          kind: :ITEMS,
          entry_ids: Enum.map(brewable, fn {id, _materials} -> id end),
          level: level
        }

        {:ok, %{caster | pending_menu_offer: offer}}
    end
  end

  @doc """
  Brews the converter the client picked.

  The materials are re-checked here rather than trusted from the offer: the menu
  only proves the caster held them when it opened, and it may have traded, dropped
  or spent them while deciding.

  Success is unconditional and the yield is always one, so there is no failure
  roll and no quantity to scale by level.

  `selected_id` was validated against the offer this skill built, so it always
  names one of the four recipes; a miss is a broken invariant and crashes.
  """
  @impl Menu
  def on_menu_reply(caster, %{id: selected_id, extras: _extras}, _level) do
    {^selected_id, materials} = List.keyfind(@recipes, selected_id, 0)

    if holds?(caster, materials) do
      brew(caster, selected_id, materials)
    else
      {:error, :no_materials}
    end
  end

  # The materials are taken before the converter is added, as the reference
  # consumes them before its 100% success roll; an add that still fails leaves
  # them spent and reports the reason to the client.
  defp brew(caster, converter_id, materials) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(converter_id) do
      consumed =
        Enum.reduce(materials, caster, fn {id, amount}, acc -> consume(acc, id, amount) end)

      case InventoryOps.add(
             consumed.character_id,
             consumed.inventory,
             consumed.stats,
             item_def,
             1
           ) do
        {:ok, persisted, change} ->
          {:ok,
           %{
             consumed
             | inventory: persisted,
               pending_inventory_notify: consumed.pending_inventory_notify ++ [change]
           }}

        {:error, reason} ->
          {:ok, InventoryManager.stage_add_failure(consumed, reason)}
      end
    end
  end

  # Mirrors the interpreter's own catalyst consumption: mutate the in-memory
  # inventory now and stage the delta for `commit_cast` to write through.
  defp consume(caster, id, amount) do
    index = ItemContainer.stackable_index(caster.inventory, id)
    {:ok, inventory, change} = ItemContainer.remove(caster.inventory, index, amount)

    %{
      caster
      | inventory: inventory,
        pending_inventory_persist:
          caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
    }
  end

  defp holds?(caster, materials) do
    Enum.all?(materials, fn {id, amount} ->
      ItemContainer.held_amount(caster.inventory, id) >= amount
    end)
  end
end
