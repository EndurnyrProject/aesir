defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfPickstone do
  @moduledoc """
  Find Stone (TF_PICKSTONE). Produces 1 Stone (item id 7049).

  rAthena: self-targeted, no damage, SP 2, fixed cast 500ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 151,
    name: :tf_pickstone,
    display_name: "Find Stone",
    max_level: 1,
    target_type: :self,
    sp_cost: [2],
    fixed_cast_time: [500],
    quest_skill: true,
    quest_owner_job: :thief

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @stone_id 7049

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, :self, _level, _definition) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(@stone_id),
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
