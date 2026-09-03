defmodule Aesir.ZoneServer.Unit.Inventory do
  @moduledoc """
  Domain core for a character's in-session inventory.

  The single-item operations are pure over the indexed inventory map carried by
  `PlayerState` (`%{non_neg_integer() => InventoryItem.t()}`) and return change
  descriptors. `give_many/4` composes those operations for capacity prechecks and
  delegates its atomic persistence to `InventoryOps`.

  Reading static item definitions through `ItemManagement.get_item_by_id/1` and
  the location/job lookup helpers are deterministic static reads, not side
  effects, so they stay inside the core.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Rental

  import Bitwise

  require Logger

  @max_inventory 100

  @equippable_types [
    :weapon,
    :armor,
    :ammo,
    :pet_armor,
    :shadow_gear
  ]

  @typedoc "Inventory keyed by stable session index."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @typedoc "Validation context required to equip an item: job and base level."
  @type equip_ctx :: %{job_id: integer(), base_level: integer()}

  @typedoc "Descriptor of the change produced by a successful operation."
  @type change ::
          ItemContainer.change()
          | {:equipped, non_neg_integer(), non_neg_integer(), [non_neg_integer()]}
          | {:unequipped, non_neg_integer()}
          | {:card_compounded, non_neg_integer(), non_neg_integer(),
             :card0 | :card1 | :card2 | :card3}

  @typedoc "Successful operation result: the new inventory plus the change."
  @type op_result :: {:ok, t(), change()} | {:error, atom()}

  @doc """
  Loads a character's complete inventory from persistence.

  Forwards to `Aesir.ZoneServer.Unit.Inventory.Persistence`; kept here so the
  load path used by the inventory manager has a stable entry point.
  """
  @spec load_inventory(integer()) :: [InventoryItem.t()]
  defdelegate load_inventory(char_id), to: Persistence

  @doc """
  The inventory's slot cap.
  """
  @spec capacity() :: pos_integer()
  def capacity, do: @max_inventory

  @doc """
  Adds `amount` of `item_def` to `inventory`, reusing the container core.

  Stacks into an existing stackable item (same `nameid`, not equipped, no cards,
  no random options) up to the shared 30,000 cap and spills the overflow into
  the lowest free index(es). With no stackable target it creates a new item at
  the lowest free index. The add is all-or-nothing: if any required slot is
  missing the inventory is left untouched and `{:error, :inventory_full}` is
  returned. The 100-slot cap is enforced via `ItemContainer`.

  Weight is intentionally NOT enforced here; the orchestrator enforces it.
  """
  @spec add(t(), ItemDefinition.t(), pos_integer(), map()) :: op_result()
  def add(inventory, %ItemDefinition{} = item_def, amount, opts \\ %{})
      when is_map(inventory) and is_integer(amount) and amount > 0 do
    ItemContainer.add(inventory, item_def, amount, @max_inventory, opts)
  end

  @doc """
  Gives a batch of concrete item-group grants atomically.

  Weight and slot capacity are checked before persistence. All row writes run in
  one transaction, so a failed grant leaves both persistence and the supplied
  inventory unchanged. Item-group unique-id requests currently persist `0`
  because Aesir has no durable item-serial generator.
  """
  @spec give_many(pos_integer(), t(), Stats.t(), [Group.grant()]) ::
          {:ok, t()} | {:error, :insufficient_space}
  def give_many(char_id, inventory, %Stats{} = stats, grants)
      when is_integer(char_id) and char_id > 0 and is_map(inventory) and is_list(grants) do
    now = NaiveDateTime.utc_now()

    with {:ok, prepared} <- prepare_grants(char_id, grants, now),
         :ok <- precheck_weight(inventory, stats, prepared),
         {:ok, _preview} <- precheck_slots(inventory, prepared),
         {:ok, persisted} <- InventoryOps.add_many(char_id, inventory, prepared) do
      {:ok, persisted}
    else
      {:error, reason} when reason in [:overweight, :inventory_full] ->
        {:error, :insufficient_space}

      {:error, reason} ->
        Logger.warning(
          "Inventory.give_many for char #{char_id} dropped grants: #{inspect(reason)}"
        )

        {:error, :insufficient_space}
    end
  end

  defp prepare_grants(char_id, grants, now) do
    Enum.reduce_while(grants, {:ok, []}, fn grant, {:ok, prepared} ->
      case ItemManagement.get_item_by_id(grant.item_id) do
        {:ok, item_def} ->
          entry = {item_def, grant.amount, grant_opts(char_id, grant, now)}
          {:cont, {:ok, [entry | prepared]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> then(fn
      {:ok, prepared} -> {:ok, Enum.reverse(prepared)}
      {:error, reason} -> {:error, reason}
    end)
  end

  defp precheck_weight(inventory, stats, prepared) do
    added_weight =
      Enum.reduce(prepared, 0, fn {item_def, amount, _opts}, total ->
        total + item_def.weight * amount
      end)

    if Weight.would_exceed?(inventory, stats, added_weight),
      do: {:error, :overweight},
      else: :ok
  end

  defp precheck_slots(inventory, prepared) do
    Enum.reduce_while(prepared, {:ok, inventory}, fn {item_def, amount, opts}, {:ok, inv} ->
      case add(inv, item_def, amount, opts) do
        {:ok, next, _change} -> {:cont, {:ok, next}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp grant_opts(char_id, grant, now) do
    %{
      identify: if(grant.identify?, do: 1, else: 0),
      refine: grant.refine,
      enchant_grade: grant.grade,
      bound: bound_value(grant.bound),
      unique_id: 0,
      expire_time: expire_time(grant.duration_min, now),
      craft: craft(grant.named?, char_id)
    }
  end

  defp bound_value(:account), do: 1
  defp bound_value(:char), do: 4
  defp bound_value(nil), do: 0

  defp expire_time(0, _now), do: nil
  defp expire_time(minutes, now), do: Rental.expire_at(minutes * 60, now)

  defp craft(true, char_id), do: char_id |> ItemCraft.signed() |> ItemCraft.to_map()
  defp craft(false, _char_id), do: nil

  @doc """
  Total quantity of item `nameid` held across all stackable slots.

  Sums the stackable stacks of `nameid` (unequipped, no cards, no random
  options); equipped or carded copies do not count toward the stackable total.
  """
  @spec held_amount(t(), integer()) :: non_neg_integer()
  defdelegate held_amount(inventory, nameid), to: ItemContainer

  @doc """
  Index of a stackable slot holding item `nameid`, or `nil` when none exists.
  """
  @spec stackable_index(t(), integer()) :: non_neg_integer() | nil
  defdelegate stackable_index(inventory, nameid), to: ItemContainer

  @doc """
  Removes `amount` from the item at `index`.

  Reduces the stack or, when the amount reaches zero, drops the slot entirely.
  """
  @spec remove(t(), non_neg_integer(), pos_integer()) :: op_result()
  defdelegate remove(inventory, index, amount), to: ItemContainer

  @doc """
  Equips the item at `index` into the client-requested `position` bitmask.

  Validates that the item exists, is equipment, identified, the job and level
  requirements are met, the item is not broken, and that `position` is one of the slots the
  item's `locations` allow. The worn mask is derived from the item's allowed
  locations: an accessory that allows both accessory slots is narrowed to a
  single slot honouring `position` (or, when ambiguous, the first free slot);
  every other item wears its full allowed mask (a two-hander stays on both
  hands, a single-slot item on its bit). Any currently equipped item whose
  bitmask intersects the worn mask is auto-unequipped and reported in
  `unequipped_indices`.
  """
  @spec equip(t(), non_neg_integer(), non_neg_integer(), equip_ctx()) :: op_result()
  def equip(inventory, index, position, ctx)
      when is_map(inventory) and is_integer(position) and position >= 0 do
    with {:ok, item} <- fetch(inventory, index),
         {:ok, item_def} <- ItemManagement.get_item_by_id(item.nameid),
         :ok <- validate_equippable(item_def),
         :ok <- validate_requirements(item_def, ctx),
         :ok <- validate_not_broken(item),
         :ok <- validate_identified(item),
         {:ok, worn_mask} <- resolve_worn_mask(inventory, item_def, position, ctx) do
      {inventory, unequipped} = unequip_conflicts(inventory, index, worn_mask)
      equipped = %{item | equip: worn_mask}
      new_inventory = ItemContainer.put_item(inventory, index, equipped)
      {:ok, new_inventory, {:equipped, index, worn_mask, unequipped}}
    else
      {:error, :item_not_found} -> {:error, :cannot_equip}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Unequips the item at `index`, resetting its `equip` bitmask to 0.
  """
  @spec unequip(t(), non_neg_integer()) :: op_result()
  def unequip(inventory, index) when is_map(inventory) do
    case Map.get(inventory, index) do
      nil -> {:error, :not_found}
      %InventoryItem{equip: 0} -> {:error, :not_equipped}
      %InventoryItem{} = item -> do_unequip(inventory, index, item)
    end
  end

  @doc """
  Returns the equipped items (those with a non-zero `equip` bitmask), keyed by
  their session index.
  """
  @spec equipped_items(t()) :: t()
  def equipped_items(inventory) when is_map(inventory) do
    for {index, %InventoryItem{equip: equip} = item} <- inventory, equip > 0, into: %{} do
      {index, item}
    end
  end

  defp do_unequip(inventory, index, item) do
    updated = %{item | equip: 0}
    {:ok, ItemContainer.put_item(inventory, index, updated), {:unequipped, index}}
  end

  defp fetch(inventory, index) do
    case Map.get(inventory, index) do
      nil -> {:error, :not_found}
      %InventoryItem{} = item -> {:ok, item}
    end
  end

  @both_accessory 0x88
  @right_hand 0x02
  @left_hand 0x20
  @right_accessory 0x08
  @left_accessory 0x80
  @assassin_job_id 12

  # The worn slot is derived from the item's own location mask. The client-supplied
  # `position` is only consulted to disambiguate the dual accessory slots (see
  # `worn_mask/3`) and to equip a normal Assassin dagger in the left hand. For every
  # other item the requested position is irrelevant.
  defp resolve_worn_mask(inventory, %ItemDefinition{} = item_def, position, ctx) do
    allowed = EquipLocation.location_atoms_to_bitmask(item_def.locations)

    cond do
      allowed == 0 ->
        {:error, :cannot_equip}

      assassin_left_hand_dagger?(item_def, allowed, position, ctx) ->
        {:ok, @left_hand}

      true ->
        {:ok, worn_mask(inventory, allowed, position)}
    end
  end

  defp assassin_left_hand_dagger?(
         %ItemDefinition{subtype: :dagger},
         @right_hand,
         @left_hand,
         %{job_id: job_id}
       ) do
    job_id == @assassin_job_id
  end

  defp assassin_left_hand_dagger?(_item_def, _allowed, _position, _ctx), do: false

  defp worn_mask(inventory, allowed, position)
       when (allowed &&& @both_accessory) == @both_accessory do
    case position &&& @both_accessory do
      @right_accessory -> @right_accessory
      @left_accessory -> @left_accessory
      _ambiguous -> free_accessory_slot(inventory)
    end
  end

  defp worn_mask(_inventory, allowed, _position), do: allowed

  defp free_accessory_slot(inventory) do
    occupied =
      Enum.reduce(inventory, 0, fn {_index, %InventoryItem{equip: equip}}, acc ->
        acc ||| equip
      end)

    cond do
      (occupied &&& @right_accessory) == 0 -> @right_accessory
      (occupied &&& @left_accessory) == 0 -> @left_accessory
      true -> @right_accessory
    end
  end

  defp validate_equippable(%ItemDefinition{type: type}) do
    if type in @equippable_types, do: :ok, else: {:error, :cannot_equip}
  end

  @doc "Whether `item_def` may be equipped by the given job and base level."
  @spec validate_requirements(ItemDefinition.t(), equip_ctx()) ::
          :ok | {:error, :requirement_unmet}
  def validate_requirements(%ItemDefinition{} = item_def, %{} = ctx) do
    with :ok <- validate_job(item_def, ctx.job_id) do
      validate_level(item_def, ctx.base_level)
    end
  end

  @doc """
  Whether `job_id` may wear `item_def` (the job requirement only, no level or
  broken checks). An item with no job restriction (`jobs: []`) is wearable by
  every job.
  """
  @spec validate_job(ItemDefinition.t(), integer()) :: :ok | {:error, :requirement_unmet}
  def validate_job(%ItemDefinition{jobs: []}, _job_id), do: :ok

  def validate_job(%ItemDefinition{jobs: jobs}, job_id) do
    with {:ok, job_name} <- AvailableJobs.job_id_to_name(job_id),
         true <- job_name in jobs do
      :ok
    else
      _ -> {:error, :requirement_unmet}
    end
  end

  defp validate_level(%ItemDefinition{equip_level_min: min, equip_level_max: max}, base_level) do
    below_min? = min > 0 and base_level < min
    above_max? = max > 0 and base_level > max
    if below_min? or above_max?, do: {:error, :requirement_unmet}, else: :ok
  end

  defp validate_not_broken(%InventoryItem{attribute: 1}), do: {:error, :item_broken}
  defp validate_not_broken(%InventoryItem{}), do: :ok

  defp validate_identified(%InventoryItem{} = item) do
    if InventoryItem.identified?(item), do: :ok, else: {:error, :item_unidentified}
  end

  defp unequip_conflicts(inventory, equipping_index, location) do
    Enum.reduce(inventory, {inventory, []}, fn
      {^equipping_index, _item}, acc ->
        acc

      {index, %InventoryItem{equip: equip} = item}, {inv, removed} when equip > 0 ->
        if (equip &&& location) != 0 do
          {ItemContainer.put_item(inv, index, %{item | equip: 0}), [index | removed]}
        else
          {inv, removed}
        end

      {_index, _item}, acc ->
        acc
    end)
  end
end
