defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywater do
  @moduledoc """
  Aqua Benedicta (AL_HOLYWATER). While standing on a water cell, brews one Empty
  Bottle into one Holy Water.

  The Empty Bottle is a material of the brew, not a requirement of the skill:
  the skill has no item cost. The cast starts only while a bottle is held, then
  only on a water cell that is not under Land Protector, or while the caster
  stands in Deluge. When
  it ends, the SP is spent first; the brew fails with nothing made only when no
  bottle is left, and otherwise takes the bottle and adds the Holy Water, which
  is lost (and reported to the client) if it cannot be carried.

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
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @holy_water_id 523
  @empty_bottle_id 713

  @behaviour Active

  @doc """
  The cast starts only while the caster holds an Empty Bottle, then only on a
  water cell free of Land Protector or under Deluge; either refusal is the
  generic failure.
  """
  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :no_empty_bottle | :not_on_water}
  def begin_attempt(caster, _target, _level, _definition) do
    cond do
      ItemContainer.held_amount(caster.inventory, @empty_bottle_id) == 0 ->
        {:error, :no_empty_bottle}

      on_water?(caster) ->
        {:ok, caster}

      true ->
        {:error, :not_on_water}
    end
  end

  # NOTE: Aesir has no NJ_SUITON. When SC_SUITON exists, let it pass the water
  # state like Deluge and remove this note.
  defp on_water?(%{character_id: id, map_name: map_name, x: x, y: y}) do
    StatusStorage.has_status?(:player, id, :sc_deluge) or
      (water_cell?(map_name, x, y) and not Storage.land_protected?(map_name, x, y))
  end

  defp water_cell?(map_name, x, y) do
    case MapCache.get(map_name) do
      {:ok, map_data} -> MapData.check_cell(map_data, x, y, :chk_water)
      _missing -> false
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), :brew_failed} | {:error, atom()}
  def cast(caster, _target, _level, _definition) do
    with {:ok, item_def} <- ItemManagement.get_item_by_id(@holy_water_id) do
      bottle = ItemContainer.stackable_index(caster.inventory, @empty_bottle_id)

      if is_nil(bottle),
        do: {:failed, caster, :brew_failed},
        else: {:ok, caster |> take_bottle(bottle) |> add_holy_water(item_def)}
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

      {:error, reason} ->
        InventoryManager.stage_add_failure(caster, reason)
    end
  end
end
