defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsGreed do
  @moduledoc """
  Greed (BS_GREED). Collects every ground item within two cells into the caster's inventory.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1013,
    name: :bs_greed,
    display_name: "Greed",
    max_level: 1,
    target_type: :self,
    splash_radius: 2,
    sp_cost: [10],
    quest_skill: true,
    quest_owner_job: :blacksmith

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{} = caster, :self, _level, %Definition{splash_radius: radius}) do
    collected =
      caster.map_name
      |> GroundItemStore.query_in_range(caster.x, caster.y, radius)
      |> Enum.reduce(caster, &collect_item/2)

    {:ok, collected}
  end

  defp collect_item(%GroundItem{} = item, %PlayerState{} = caster) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- InventoryOps.can_add(caster.inventory, caster.stats, item_def, item.amount),
         {:ok, claimed} <-
           Coordinator.claim_item(caster.map_name, item.id, caster.character_id) do
      give_claimed(item_def, item, claimed, caster)
    else
      {:error, _reason} -> caster
    end
  end

  defp give_claimed(item_def, item, %GroundItem{} = claimed, %PlayerState{} = caster) do
    case InventoryManager.handle_give_item(item_def, item.amount, caster, item.identified) do
      {:ok, collected} ->
        collected

      {:error, _reason, unchanged} ->
        Coordinator.drop_items(
          caster.map_name,
          [{claimed.nameid, claimed.amount, claimed.x, claimed.y, claimed.identified}],
          claimed.x,
          claimed.y
        )

        unchanged
    end
  end
end
