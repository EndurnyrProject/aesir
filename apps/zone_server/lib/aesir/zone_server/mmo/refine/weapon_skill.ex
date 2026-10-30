defmodule Aesir.ZoneServer.Mmo.Refine.WeaponSkill do
  @moduledoc """
  Deterministic Upgrade Weapon offer and attempt rules, shared by both modes.

  Offers identified, unworn weapons below the learned rank when the required
  ore is held. Reply preparation revalidates row identity, refinability, rank,
  the +10 cap, ore and the next normal refine process, but does not repeat the
  offer-only identification/equipment checks. No randomness, writes or packets.
  """

  import Bitwise

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "A rejected selection before any ore or weapon mutation."
  @type reason :: :no_item | :not_refinable | :max_refine | :no_ore

  @typedoc "Current authoritative rows and the normal rate for the next refine step."
  @type context :: %{
          item: InventoryItem.t(),
          definition: ItemDefinition.t(),
          ore_index: non_neg_integer(),
          normal_rate: non_neg_integer()
        }

  @doc "Offers inventory indices mapped to persisted weapon row ids using the captured learned rank."
  @spec offer(PlayerState.t(), non_neg_integer()) :: %{non_neg_integer() => integer()}
  def offer(%PlayerState{inventory: inventory}, learned_rank) do
    for {index,
         %InventoryItem{
           id: id,
           nameid: nameid,
           identify: identified,
           equip: equip,
           refine: refine
         }} <- inventory,
        nameid > 0,
        is_integer(id),
        refine < learned_rank,
        identified != 0,
        band(equip, EquipLocation.location_bit(:both_hand)) == 0,
        {:ok, %ItemDefinition{type: :weapon, weapon_level: level}} <- [Items.by_id(nameid)],
        {:ok, ore} <- [material(level)],
        not is_nil(ItemContainer.stackable_index(inventory, ore)),
        into: %{},
        do: {index, id}
  end

  @doc "The skill's hardcoded ore for weapon levels 1 through 4; higher levels are unsupported."
  @spec material(integer()) :: {:ok, pos_integer()} | :error
  def material(1), do: {:ok, 1_010}
  def material(2), do: {:ok, 1_011}
  def material(level) when level in [3, 4], do: {:ok, 984}
  def material(_level), do: :error

  @doc "Revalidates the selected persisted row and next normal process, without spending anything."
  @spec prepare(PlayerState.t(), non_neg_integer(), integer(), non_neg_integer()) ::
          {:ok, context()} | {:error, reason()}
  def prepare(%PlayerState{inventory: inventory}, index, expected_item_id, learned_rank) do
    with {:ok, item} <- selected_item(inventory, index, expected_item_id),
         {:ok, definition} <- refinable_weapon(item),
         true <- item.refine < learned_rank and item.refine < 10,
         {:ok, ore} <- material(definition.weapon_level),
         ore_index when is_integer(ore_index) <- ItemContainer.stackable_index(inventory, ore),
         {:ok, rate} <- normal_rate(definition.weapon_level, item.refine, ore) do
      {:ok, %{item: item, definition: definition, ore_index: ore_index, normal_rate: rate}}
    else
      {:error, _reason} = error -> error
      false -> {:error, :max_refine}
      nil -> {:error, :no_ore}
    end
  end

  @doc "The unclamped integer percent chance, with signed job-level division truncating toward zero."
  @spec chance(non_neg_integer(), non_neg_integer(), boolean()) :: integer()
  def chance(normal_rate, _job_level, true), do: div(normal_rate, 100) + 10
  def chance(normal_rate, job_level, false), do: div(normal_rate, 100) + div(job_level - 50, 2)

  @doc "Succeeds only when chance exceeds the 0..99 roll; any failed roll destroys the weapon."
  @spec outcome(non_neg_integer(), integer(), 0..99) :: {:success, non_neg_integer()} | {:break}
  def outcome(current_refine, chance, roll) do
    if chance > roll, do: {:success, current_refine + 1}, else: {:break}
  end

  defp selected_item(inventory, index, expected_item_id) do
    case Map.get(inventory, index) do
      %InventoryItem{id: ^expected_item_id, nameid: nameid} = item when nameid > 0 -> {:ok, item}
      _missing_or_replaced -> {:error, :no_item}
    end
  end

  defp refinable_weapon(item) do
    case Items.by_id(item.nameid) do
      {:ok, %ItemDefinition{type: :weapon, refineable: true, weapon_level: level} = definition}
      when level in 1..4 ->
        {:ok, definition}

      _not_refinable ->
        {:error, :not_refinable}
    end
  end

  defp normal_rate(level, refine, ore) do
    case RefineDatabase.level_info(:weapon, level, refine + 1) do
      %{chances: %{normal: %{rate: rate, material_nameid: ^ore}}} -> {:ok, rate}
      _missing_or_mismatched -> {:error, :not_refinable}
    end
  end
end
