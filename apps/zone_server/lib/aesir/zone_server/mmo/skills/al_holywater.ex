defmodule Aesir.ZoneServer.Mmo.Skills.AlHolywater do
  @moduledoc """
  Aqua Benedicta (AL_HOLYWATER). While standing on a water cell,
  produces 1 Holy Water (item id 523).

  rAthena: requires State: Water; SP 10; cast 800ms / fixed 200ms / after-cast 500ms.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 31,
    name: :al_holywater,
    display_name: "Aqua Benedicta",
    max_level: 1,
    target_type: :self,
    sp_cost: [10],
    cast_time: [800],
    fixed_cast_time: [200],
    after_cast_delay: [500]

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @holy_water_id 523

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, _target, _level, _definition) do
    with {:ok, map_data} <- MapCache.get(caster.map_name),
         true <- MapData.check_cell(map_data, caster.x, caster.y, :chk_water) do
      :ok
    else
      _ -> {:error, :not_on_water}
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, _target, _level, _definition) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(@holy_water_id),
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
