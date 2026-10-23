defmodule Aesir.ZoneServer.Unit.Inventory do
  @moduledoc """
  Domain core for a character's in-session inventory.

  The single-item operations are pure over the indexed inventory map carried by
  `PlayerState` (`%{non_neg_integer() => InventoryItem.t()}`) and return change
  descriptors. `give_group/4` composes those operations per item-group entry and
  delegates each entry's persistence to `InventoryOps`.

  Reading static item definitions through `ItemManagement.get_item_by_id/1` and
  the location/job lookup helpers are deterministic static reads, not side
  effects, so they stay inside the core.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.Eligibility
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions.Roller, as: RandomOptionRoller
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Rental

  import Bitwise

  @max_inventory 100

  # The reference's itemdb_isequip2: only these types roll refine/grade.
  @refinable_types [:weapon, :armor, :ammo, :shadow_gear]

  @equippable_types [
    :weapon,
    :armor,
    :ammo,
    :pet_armor,
    :shadow_gear
  ]

  @typedoc "Inventory keyed by stable session index."
  @type t :: %{non_neg_integer() => InventoryItem.t()}

  @typedoc "Validation context required to equip an item."
  @type equip_ctx :: Eligibility.context()

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
  Number of unused slots inside the inventory's slot cap.

  Keys outside `0..capacity-1` are not slots and do not count.
  """
  @spec blank_slots(t()) :: non_neg_integer()
  def blank_slots(inventory) when is_map(inventory) do
    @max_inventory - Enum.count(inventory, fn {index, _item} -> index < @max_inventory end)
  end

  @doc """
  Adds a fresh grant of `amount` of `item_def`, built from `opts`, with the
  inventory recipe (`ItemContainer.put/6`).

  `weight_room` is the weight still free (`weight_room/2`); the default
  `:infinity` is for a caller that has already settled the weight of a whole
  batch. Refusals are `:invalid`, `:over_amount`, `:stack_limit`,
  `:overweight` and `:inventory_full`, in that order.
  """
  @spec add(t(), ItemDefinition.t(), integer(), map(), integer() | :infinity) :: op_result()
  def add(inventory, %ItemDefinition{} = item_def, amount, opts \\ %{}, weight_room \\ :infinity)
      when is_map(inventory) and is_integer(amount) do
    add_item(inventory, item_def, ItemContainer.new_item(item_def, opts), amount, weight_room)
  end

  @doc """
  Adds `amount` copies of an existing `item` (a row moved from another
  container or player) with the inventory recipe, as `add/5` does.
  """
  @spec add_item(t(), ItemDefinition.t(), InventoryItem.t(), integer(), integer() | :infinity) ::
          op_result()
  def add_item(
        inventory,
        %ItemDefinition{} = item_def,
        %InventoryItem{} = item,
        amount,
        weight_room
      ) do
    ItemContainer.put(inventory, :inventory, item_def, item, amount, %{
      capacity: @max_inventory,
      weight: weight_room
    })
  end

  @doc """
  The weight a player with `stats` can still carry on top of `inventory`.
  """
  @spec weight_room(t(), Stats.t()) :: integer()
  def weight_room(inventory, %Stats{} = stats),
    do: Weight.max_weight(stats) - Weight.current_weight(inventory)

  @doc """
  Gives every concrete item-group grant in order, as the reference does.

  Each entry is added on its own: a stackable entry in one call, a
  non-stackable entry one unit per call. The already-granted units stay granted
  and a later failure never undoes them. `successes` carries one
  `{item_id, announced?}` per successful unit so the caller can announce exactly
  what the reference announces; `failures` carries one reason per refused unit.
  With `halt?: true` the grant stops at the first refusal (the
  `getrandgroupitem` rule); otherwise it continues (`getgroupitem`). Unique-id
  requests currently persist `0` because Aesir has no durable item-serial
  generator.
  """
  @spec give_group(pos_integer(), t(), Stats.t(), [Group.grant()], keyword()) ::
          {:ok, t(), [{integer(), boolean()}], [term()]}
  def give_group(char_id, inventory, %Stats{} = stats, grants, opts \\ [])
      when is_integer(char_id) and char_id > 0 and is_map(inventory) and is_list(grants) do
    halt? = Keyword.get(opts, :halt?, false)
    rng = Keyword.get(opts, :rng, :rand)
    now = NaiveDateTime.utc_now()

    Enum.reduce_while(grants, {:ok, inventory, [], []}, fn grant, acc ->
      step_grant(char_id, stats, grant, now, acc, halt?, rng)
    end)
  end

  defp step_grant(
         char_id,
         stats,
         grant,
         now,
         {:ok, current, successes, failures},
         halt?,
         rng
       ) do
    case ItemManagement.get_item_by_id(grant.item_id) do
      {:ok, item_def} ->
        add_opts = grant_opts(char_id, grant, item_def, now, rng)
        acc = {current, successes, failures}

        acc =
          if ItemDefinition.stackable?(item_def) and grant.stacked? do
            give_stack_entry(char_id, stats, item_def, grant, add_opts, acc)
          else
            give_unit_entries(char_id, stats, item_def, grant, add_opts, acc, halt?, rng)
          end

        {inventory, successes, failures} = acc
        result = {:ok, inventory, successes, failures}
        continue_or_halt(result, halt?, failures)

      {:error, _reason} ->
        {:cont, {:ok, current, successes, failures}}
    end
  end

  defp continue_or_halt(result, true, [_reason | _rest]), do: {:halt, result}
  defp continue_or_halt(result, _halt?, _failures), do: {:cont, result}

  defp give_stack_entry(char_id, stats, item_def, grant, opts, {inventory, successes, failures}) do
    case give_grant(char_id, inventory, stats, item_def, grant.amount, opts) do
      {:ok, persisted} -> {persisted, successes ++ [success(grant)], failures}
      {:error, reason, unchanged} -> {unchanged, successes, failures ++ [reason]}
    end
  end

  defp give_unit_entries(
         char_id,
         stats,
         item_def,
         grant,
         opts,
         {inventory, successes, failures},
         halt?,
         rng
       ) do
    if grant.amount < 1 do
      {inventory, successes, failures}
    else
      Enum.reduce_while(1..grant.amount, {inventory, successes, failures}, fn unit, acc ->
        step_unit(char_id, stats, item_def, grant, opts, acc, halt?, {unit, rng})
      end)
    end
  end

  defp step_unit(
         char_id,
         stats,
         item_def,
         grant,
         opts,
         {inventory, successes, failures},
         halt?,
         {unit, rng}
       ) do
    opts = per_unit_opts(grant, item_def, opts, unit, rng)

    case give_grant(char_id, inventory, stats, item_def, 1, opts) do
      {:ok, persisted} ->
        {:cont, {persisted, successes ++ [success(grant)], failures}}

      {:error, reason, unchanged} ->
        result = {unchanged, successes, failures ++ [reason]}

        if halt?, do: {:halt, result}, else: {:cont, result}
    end
  end

  defp per_unit_opts(_grant, _item_def, opts, 1, _rng), do: opts

  defp per_unit_opts(grant, item_def, opts, _unit, rng) do
    if refinable?(item_def) do
      %{
        opts
        | refine: Roller.roll_refine(grant, rng),
          enchant_grade: Roller.roll_grade(grant, rng),
          random_options: roll_options(grant, rng)
      }
    else
      opts
    end
  end

  # An equipment grant whose entry names a random option group rolls fresh
  # options for every add; other grants carry none.
  defp roll_options(grant, rng) do
    with id when is_integer(id) <- Map.get(grant, :random_option_group),
         {:ok, group} <- RandomOptions.group(id) do
      RandomOptionRoller.roll(group, rng)
    else
      _ -> []
    end
  end

  defp refinable?(%ItemDefinition{type: type}), do: type in @refinable_types

  defp success(grant), do: {grant.item_id, grant.announced?}

  @spec give_grant(pos_integer(), t(), Stats.t(), ItemDefinition.t(), pos_integer(), map()) ::
          {:ok, t()} | {:error, ItemContainer.add_error(), t()}
  defp give_grant(char_id, inventory, stats, item_def, amount, opts) do
    case InventoryOps.add(char_id, inventory, stats, item_def, amount, opts) do
      {:ok, persisted, _change} -> {:ok, persisted}
      {:error, reason} -> {:error, reason, inventory}
    end
  end

  # An item-group grant's own identify request wins; otherwise the source's
  # obtain rule identifies everything but weapons, armour, pet armour and
  # shadow gear.
  defp grant_opts(char_id, grant, item_def, now, rng) do
    %{
      identify:
        if(grant.identify? or ItemDefinition.identified_on_obtain?(item_def), do: 1, else: 0),
      refine: if(refinable?(item_def), do: grant.refine, else: 0),
      enchant_grade: if(refinable?(item_def), do: grant.grade, else: 0),
      bound: bound_value(grant.bound),
      unique_id: 0,
      expire_time: expire_time(grant.duration_min, now),
      craft: craft(grant.named?, char_id),
      random_options: if(refinable?(item_def), do: roll_options(grant, rng), else: [])
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

  @doc "Whether `item_def` may be equipped by the given character identity."
  @spec validate_requirements(ItemDefinition.t(), equip_ctx()) ::
          :ok | {:error, Eligibility.reason()}
  def validate_requirements(%ItemDefinition{} = item_def, ctx),
    do: Eligibility.check(item_def, ctx)

  @doc """
  Returns the sorted indices of equipped items that the identity may no longer wear.

  Invalid identity and missing static definitions abort the scan instead of
  converting data errors into permission failures.
  """
  @spec ineligible_equipment(t(), Eligibility.context(), ItemEligibility.mode()) ::
          {:ok, [non_neg_integer()]}
          | {:error, :invalid_identity | {:missing_definition, integer()}}
  def ineligible_equipment(inventory, context, mode) when is_map(inventory) do
    case Eligibility.validate_context(context, mode) do
      :ok -> scan_equipment(inventory, context, mode)
      {:error, :invalid_identity} -> {:error, :invalid_identity}
    end
  end

  defp scan_equipment(inventory, context, mode) do
    inventory
    |> equipped_items()
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce_while({:ok, []}, &scan_item(&1, &2, context, mode))
    |> then(fn
      {:ok, indices} -> {:ok, Enum.reverse(indices)}
      {:error, reason} -> {:error, reason}
    end)
  end

  defp scan_item({index, item}, {:ok, indices}, context, mode) do
    case ItemManagement.get_item_by_id(item.nameid) do
      {:ok, item_def} -> scan_definition(item_def, context, mode, index, indices)
      {:error, _reason} -> {:halt, {:error, {:missing_definition, item.nameid}}}
    end
  end

  defp scan_definition(item_def, context, mode, index, indices) do
    case Eligibility.check(item_def, context, mode) do
      :ok ->
        {:cont, {:ok, indices}}

      {:error, reason}
      when reason in [:job_restricted, :class_restricted, :gender_restricted, :level_restricted] ->
        {:cont, {:ok, [index | indices]}}

      {:error, :invalid_identity} ->
        {:halt, {:error, :invalid_identity}}
    end
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
