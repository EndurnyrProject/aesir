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
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
  def cast(%PlayerState{} = caster, :self, _level, %Definition{splash_radius: radius}) do
    party_ctx = party_context(caster)

    collected =
      caster.map_name
      |> GroundItemStore.query_in_range(caster.x, caster.y, radius)
      |> Enum.reduce(caster, fn item, collected -> collect_item(item, collected, party_ctx) end)

    {:ok, collected}
  end

  @spec party_context(PlayerState.t()) :: %{party_id: non_neg_integer(), pickup_share: boolean()}
  defp party_context(%PlayerState{party_id: 0}), do: %{party_id: 0, pickup_share: false}

  defp party_context(%PlayerState{party_id: party_id}) do
    case PartyManager.get(party_id) do
      {:ok, party} -> %{party_id: party_id, pickup_share: party.item_pickup_share}
      {:error, :not_found} -> %{party_id: 0, pickup_share: false}
    end
  end

  defp collect_item(%GroundItem{} = item, %PlayerState{} = caster, party_ctx) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- InventoryOps.can_add(caster.inventory, caster.stats, item_def, item.amount),
         {:ok, claimed} <-
           Coordinator.claim_item(caster.map_name, item.id, caster.character_id, party_ctx) do
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
        re_drop_claimed(caster.map_name, claimed)
        unchanged
    end
  end

  @spec re_drop_claimed(String.t(), GroundItem.t()) :: :ok
  defp re_drop_claimed(map_name, %GroundItem{owners: nil} = item) do
    Coordinator.drop_items(
      map_name,
      [{item.nameid, item.amount, item.x, item.y, item.identified}],
      item.x,
      item.y
    )
  end

  defp re_drop_claimed(map_name, %GroundItem{} = item) do
    Coordinator.drop_items(
      map_name,
      [{item.nameid, item.amount, item.x, item.y, item.identified}],
      item.x,
      item.y,
      ownership: {item.owners, item.unlock_at}
    )
  end
end
