defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywater do
  @moduledoc """
  Aqua Benedicta (AL_HOLYWATER). While standing on a water cell, consumes one
  Empty Bottle and produces one Holy Water.

  The Empty Bottle is a production requirement rather than a skill requirement:
  it belongs to the crafting recipe the skill runs, not to the skill's own cost
  row, which is why the definition's declared item cost has no counterpart in the
  skill data the audit compares against.

  Renewal: single level, ten SP, an 800ms variable cast plus a fixed 200ms, and
  a 500ms after-cast delay.

  Pre-renewal: a flat one-second cast with no fixed component, the same ten SP
  and the same 500ms after-cast delay. The water-cell requirement and the
  one-bottle-to-one-holy-water recipe are the same in both modes.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 31,
    name: :al_holywater,
    display_name: "Aqua Benedicta",
    max_level: 1,
    target_type: :self,
    damage_kind: :magic,
    sp_cost: [10],
    cast_time: [renewal: [800], pre_renewal: [1_000]],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    after_cast_delay: [500],
    item_cost: [%{id: 713, amount: 1}]

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

      # NOTE: Aesir has no NJ_SUITON cell state. When NJ_SUITON cells exist, destroy the
      # matching cell after a successful craft and remove this note.
      {:ok, updated}
    end
  end
end
