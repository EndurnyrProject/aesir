defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtRemovetrap do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 124,
    name: :ht_removetrap,
    display_name: "Remove Trap",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 2,
    sp_cost: [5]

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @trap_item_id 1065

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, {:ground, _x, _y}, _level, _definition) do
    case preflight_item(caster) do
      {:ok, _item_def} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, _level, _definition) do
    with {:ok, item_def} <- preflight_item(caster),
         {:ok, _transition} <-
           Manager.reclaim_trap({:player, caster.character_id}, caster.map_name, x, y),
         {:ok, persisted, change} <-
           InventoryOps.add(caster.character_id, caster.inventory, caster.stats, item_def, 1) do
      updated =
        caster
        |> Map.put(:inventory, persisted)
        |> Map.update!(:pending_inventory_notify, &(&1 ++ [change]))

      {:ok, updated}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp preflight_item(caster) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(@trap_item_id),
         :ok <- InventoryOps.can_add(caster.inventory, caster.stats, item_def, 1) do
      {:ok, item_def}
    end
  end
end
