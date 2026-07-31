defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaCreatecon do
  @moduledoc """
  Create Elemental Converter (SA_CREATECON). Offers the caster a menu of the
  elemental converters it holds the materials for and brews the chosen one.

  This level-one quest skill is self-targeted, instant, deals no damage, and
  costs 30 SP.
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
    quest_owner_job: :sage

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Unit.ItemContainer
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
        {:error, :no_materials}

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

  # The converter is added before the materials are taken because the add is the
  # only step that can still fail. Aesir has no ground-item fallback for this
  # path, so it refuses the brew intact rather than consuming the materials.
  defp brew(caster, converter_id, materials) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(converter_id),
         {:ok, persisted, change} <-
           InventoryOps.add(caster.character_id, caster.inventory, caster.stats, item_def, 1) do
      brewed =
        caster
        |> Map.put(:inventory, persisted)
        |> Map.update!(:pending_inventory_notify, &(&1 ++ [change]))

      {:ok, Enum.reduce(materials, brewed, fn {id, amount}, acc -> consume(acc, id, amount) end)}
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
