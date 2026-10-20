defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtRemovetrap do
  @moduledoc """
  Remove Trap (HT_REMOVETRAP). Picks up a placed trap.

  Renewal and pre-renewal agree: picks up a trap within 2 cells for 5 SP, returning the trap item.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 124,
    name: :ht_removetrap,
    display_name: "Remove Trap",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 2,
    sp_cost: [5],
    damage_kind: :misc

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:ground, _x, _y}, _level, _definition), do: :ok

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, _level, _definition) do
    case Manager.reclaim_trap({:player, caster.character_id}, caster.map_name, x, y) do
      {:ok, %{item_id: nil}} ->
        {:ok, caster}

      {:ok, %{item_id: item_id}} ->
        return_item(caster, item_id)

      {:error, reason} ->
        {:failed, caster, reason}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  # The reference removes the trap before adding the item and reports a failed
  # add without undoing the removal, so an item that does not fit is still a
  # completed cast.
  defp return_item(caster, item_id) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(item_id),
         {:ok, persisted, change} <-
           InventoryOps.add(caster.character_id, caster.inventory, caster.stats, item_def, 1) do
      {:ok,
       caster
       |> Map.put(:inventory, persisted)
       |> Map.update!(:pending_inventory_notify, &(&1 ++ [change]))}
    else
      {:error, _reason} -> {:ok, caster}
    end
  end
end
