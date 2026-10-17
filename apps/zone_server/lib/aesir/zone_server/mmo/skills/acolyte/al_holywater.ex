defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywater do
  @moduledoc """
  Aqua Benedicta (AL_HOLYWATER). While standing on a water cell, brews one Empty
  Bottle into one Holy Water.

  The Empty Bottle is a material of the brew, not a requirement of the skill:
  the skill has no item cost. The cast starts only while a bottle is held. When
  it ends, the SP is spent first; the brew then fails with nothing made if no
  bottle is left or the Holy Water stack is full, and otherwise takes the bottle
  and adds the Holy Water, which is lost if it cannot be carried.

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
    after_cast_delay: [500]

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @holy_water_id 523
  @empty_bottle_id 713
  @max_stack 30_000

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

  @doc """
  The cast starts only while the caster holds an Empty Bottle, failing with a
  generic reason otherwise.
  """
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :no_empty_bottle}
  def begin_attempt(caster, _target, _level, _definition) do
    if ItemContainer.held_amount(caster.inventory, @empty_bottle_id) > 0,
      do: {:ok, caster},
      else: {:error, :no_empty_bottle}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :brew_failed} | {:error, atom()}
  def cast(caster, _target, _level, _definition) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(@holy_water_id) do
      bottle = ItemContainer.stackable_index(caster.inventory, @empty_bottle_id)

      if is_nil(bottle) or stack_full?(caster.inventory),
        do: {:failed, caster, :brew_failed},
        else: {:ok, caster |> take_bottle(bottle) |> add_holy_water(item_def)}
    end
  end

  defp stack_full?(inventory) do
    case ItemContainer.stackable_index(inventory, @holy_water_id) do
      nil -> false
      index -> inventory[index].amount + 1 > @max_stack
    end
  end

  defp take_bottle(caster, index) do
    {:ok, inventory, change} = ItemContainer.remove(caster.inventory, index, 1)

    %{
      caster
      | inventory: inventory,
        pending_inventory_persist:
          caster.pending_inventory_persist ++ [{caster.inventory, inventory, change}]
    }
  end

  # NOTE: Aesir has no NJ_SUITON cell state. When NJ_SUITON cells exist, destroy the
  # matching cell after a successful brew and remove this note.
  defp add_holy_water(caster, item_def) do
    case InventoryOps.add(caster.character_id, caster.inventory, caster.stats, item_def, 1) do
      {:ok, persisted, change} ->
        %{
          caster
          | inventory: persisted,
            pending_inventory_notify: caster.pending_inventory_notify ++ [change]
        }

      {:error, reason} when reason in [:overweight, :inventory_full] ->
        caster
    end
  end
end
