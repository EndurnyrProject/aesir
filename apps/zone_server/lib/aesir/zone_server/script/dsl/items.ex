defmodule Aesir.ZoneServer.Script.Dsl.Items do
  @moduledoc """
  Economy and inventory buildins for the script DSL: zeny reads and transfers,
  item grants (plain, grouped, named, rental, bound, attribute-carrying),
  item removal, compiled on-use item scripts, equipment repair, the
  interactive refine flow, and inventory weight checks.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal,
    only: [apply_op: 2, no_player!: 1, equipped_index: 2]

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Announce
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  # CompiledItemScripts is created at runtime by ScriptCompiler.compile_all!/1
  # (it does not exist at compile time); `consumeitem/2` dispatches into it.
  @compile {:no_warn_undefined, CompiledItemScripts}

  @typedoc "One inventory item's refine state and eligibility, from `refine_targets/1`."
  @type refine_target :: %{
          index: non_neg_integer(),
          nameid: integer(),
          name: String.t(),
          refine: non_neg_integer(),
          refinable?: boolean()
        }

  @typedoc "The ore/zeny/blessing cost of one refine attempt, from `refine_cost/3`."
  @type refine_cost :: %{
          ore_nameid: integer() | nil,
          ore_amount: non_neg_integer(),
          zeny: non_neg_integer(),
          blessing_amount: non_neg_integer()
        }

  @refine_ore_amount 1

  @doc """
  The player's current zeny. Pure read over the ctx snapshot.
  """
  @spec zeny(Ctx.t()) :: non_neg_integer()
  def zeny(%Ctx{game_state: nil}), do: no_player!("zeny/1")
  def zeny(%Ctx{game_state: gs}), do: gs.zeny

  @doc """
  Debits `amount` zeny through the session seam, pushing the change to the
  client and persisting it. Halts `:not_enough_zeny` when the player is short
  (debiting nothing).
  """
  @spec pay_zeny(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def pay_zeny(%Ctx{status: {:error, _}} = ctx, _amount), do: ctx
  def pay_zeny(%Ctx{} = ctx, amount), do: apply_op(ctx, {:pay_zeny, amount})

  @doc """
  Credits `amount` zeny through the session seam, clamped at the zeny cap,
  pushing the change to the client and persisting it. Never fails.
  """
  @spec credit_zeny(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def credit_zeny(%Ctx{status: {:error, _}} = ctx, _amount), do: ctx
  def credit_zeny(%Ctx{} = ctx, amount), do: apply_op(ctx, {:credit_zeny, amount})

  @doc """
  Gives `qty` of item `item_id` through the session seam (persisting and
  emitting `ItemAdded`). Halts on a full/overweight inventory.
  """
  @spec give_item(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def give_item(%Ctx{status: {:error, _}} = ctx, _item_id, _qty), do: ctx
  def give_item(%Ctx{} = ctx, item_id, qty), do: apply_op(ctx, {:give_item, item_id, qty})

  @doc "Rolls and grants every result from an item group."
  @spec get_group_item(Ctx.t(), atom()) :: Ctx.t()
  def get_group_item(%Ctx{status: {:error, _}} = ctx, _group_key), do: ctx

  def get_group_item(%Ctx{} = ctx, group_key) do
    case ItemGroups.fetch(group_key) do
      {:ok, group} ->
        group
        |> Roller.roll_full()
        |> stamp_group_key(group_key)
        |> then(&commit_grants(ctx, &1))

      :error ->
        Ctx.halt(ctx, :unknown_item_group)
    end
  end

  @doc "Rolls and grants `qty` results from one item-group subgroup."
  @spec get_rand_group_item(Ctx.t(), atom(), pos_integer(), non_neg_integer()) :: Ctx.t()
  def get_rand_group_item(%Ctx{status: {:error, _}} = ctx, _group_key, _qty, _sub), do: ctx

  def get_rand_group_item(%Ctx{} = ctx, group_key, qty, sub)
      when is_integer(qty) and qty > 0 and is_integer(sub) and sub >= 0 do
    case ItemGroups.fetch(group_key) do
      {:ok, group} ->
        group
        |> Roller.roll_n(sub, qty)
        |> stamp_group_key(group_key)
        |> then(&commit_grants(ctx, &1))

      :error ->
        Ctx.halt(ctx, :unknown_item_group)
    end
  end

  @doc "Returns one item id from a subgroup without depleting shared-pool state."
  @spec group_rand_item(Ctx.t(), atom(), non_neg_integer()) :: pos_integer()
  def group_rand_item(%Ctx{}, group_key, sub) do
    with {:ok, group} <- ItemGroups.fetch(group_key),
         {:ok, item_id} <- Roller.pick_id(group, sub) do
      item_id
    else
      :error ->
        raise ArgumentError,
              "group_rand_item/3 cannot resolve item group #{inspect(group_key)} subgroup #{sub}"
    end
  end

  @doc "Commits concrete item-group grants through the current script context."
  @spec commit_grants(Ctx.t(), [Group.grant()]) :: Ctx.t()
  def commit_grants(%Ctx{} = ctx, []), do: ctx
  def commit_grants(%Ctx{status: {:error, _}} = ctx, _grants), do: ctx

  def commit_grants(%Ctx{session_pid: session_pid} = ctx, grants) when is_pid(session_pid) do
    case apply_op(ctx, {:give_items_atomic, grants}) do
      %Ctx{status: {:error, :insufficient_space}} = halted ->
        rollback_pool(grants)
        Ctx.halt(halted, :inventory_full)

      %Ctx{status: {:error, _reason}} = halted ->
        rollback_pool(grants)
        halted

      %Ctx{} = committed ->
        maybe_announce(committed, grants)
    end
  end

  def commit_grants(%Ctx{session_pid: nil, game_state: nil} = ctx, _grants),
    do: Ctx.halt(ctx, :no_player)

  def commit_grants(%Ctx{session_pid: nil, game_state: game_state} = ctx, grants) do
    case Inventory.give_many(
           ctx.char_id,
           game_state.inventory,
           game_state.stats,
           grants
         ) do
      {:ok, inventory} ->
        maybe_announce(%{ctx | game_state: %{game_state | inventory: inventory}}, grants)

      {:error, :insufficient_space} ->
        rollback_pool(grants)
        Ctx.halt(ctx, :inventory_full)
    end
  end

  @spec stamp_group_key([Group.grant()], atom()) :: [Group.grant()]
  defp stamp_group_key(grants, group_key),
    do: Enum.map(grants, &Map.put(&1, :group_key, group_key))

  @spec rollback_pool([Group.grant()]) :: :ok
  defp rollback_pool(grants) do
    Enum.each(grants, fn
      %{group_key: group_key, drawn: {sub, item_ids}} ->
        ItemGroupPool.rollback(group_key, sub, item_ids)

      _grant ->
        :ok
    end)
  end

  @spec maybe_announce(Ctx.t(), [Group.grant()]) :: Ctx.t()
  defp maybe_announce(ctx, grants) do
    Enum.each(grants, fn
      %{announced?: true, item_id: item_id} ->
        Announce.announce_all("Obtained item #{item_id}.", 0)

      _grant ->
        :ok
    end)

    ctx
  end

  @doc """
  Gives one identified item signed by an online character through the session seam.
  Halts if the target is offline or unknown, or if the inventory cannot hold it.
  """
  @spec get_named_item(Ctx.t(), integer(), String.t() | integer()) :: Ctx.t()
  def get_named_item(%Ctx{status: {:error, _}} = ctx, _item_id, _target), do: ctx

  def get_named_item(%Ctx{} = ctx, item_id, target),
    do: apply_op(ctx, {:get_named_item, item_id, target})

  @doc """
  Gives one time-limited rental item through the session seam.
  """
  @spec give_item_rental(Ctx.t(), integer(), pos_integer(), keyword()) :: Ctx.t()
  def give_item_rental(ctx, item_id, seconds, opts \\ [])

  def give_item_rental(%Ctx{status: {:error, _}} = ctx, _id, _secs, _opts), do: ctx

  def give_item_rental(%Ctx{} = ctx, item_id, seconds, opts),
    do: apply_op(ctx, {:give_item_rental, item_id, seconds, opts})

  @doc """
  Gives `qty` of item `item_id` through the session seam with an account or
  character binding.
  """
  @spec give_item_bound(Ctx.t(), integer(), pos_integer(), :account | :char | 1 | 4) :: Ctx.t()
  def give_item_bound(%Ctx{status: {:error, _}} = ctx, _item_id, _qty, _bound), do: ctx

  def give_item_bound(%Ctx{} = ctx, item_id, qty, bound),
    do: apply_op(ctx, {:give_item_bound, item_id, qty, bound_value(bound)})

  defp bound_value(:account), do: 1
  defp bound_value(:char), do: 4
  defp bound_value(1), do: 1
  defp bound_value(4), do: 4

  @doc """
  Removes `qty` of item `item_id` through the session seam (persisting and
  emitting `ItemRemoved`). Halts `:not_enough_items` when the player holds fewer.
  """
  @spec delitem(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def delitem(%Ctx{status: {:error, _}} = ctx, _item_id, _qty), do: ctx
  def delitem(%Ctx{} = ctx, item_id, qty), do: apply_op(ctx, {:delitem, item_id, qty})

  @doc """
  Removes the equipment worn in equip `slot` (rAthena `delequip`) through the
  session seam: the item is unequipped first (appearance broadcast, stats
  recompute), then its inventory row is deleted. An empty or unknown slot is a
  no-op. Like the other granting/removing effects the value rAthena returns is
  not exposed. Halts `:no_player` on a detached ctx.
  """
  @spec delequip(Ctx.t(), integer()) :: Ctx.t()
  def delequip(%Ctx{status: {:error, _}} = ctx, _slot), do: ctx

  def delequip(%Ctx{} = ctx, slot) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} -> apply_op(ctx, {:delequip, index, nameid})
      nil -> ctx
    end
  end

  @doc """
  Raises the equipment worn in equip `slot` by `up` refine levels (default `1`,
  rAthena `successrefitem`), clamped to `MAX_REFINE`, through the session seam
  with no ore/zeny cost. The item's refine is persisted and combat stats
  recalculated when it was equipped. An empty/unknown slot is a no-op (the
  value rAthena returns is not exposed, matching the other statement effects).
  Halts `:no_player` on a detached ctx.
  """
  @spec successrefitem(Ctx.t(), integer(), pos_integer()) :: Ctx.t()
  def successrefitem(ctx, slot, up \\ 1)

  def successrefitem(%Ctx{status: {:error, _}} = ctx, _slot, _up), do: ctx

  def successrefitem(%Ctx{} = ctx, slot, up) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} ->
        apply_op(ctx, {:successrefitem, index, nameid, up})

      nil ->
        ctx
    end
  end

  @doc """
  Destroys the equipment worn in equip `slot` (rAthena `failedrefitem`) through
  the session seam, as a forced refine failure irrecoverably breaks the item.
  The removal is persisted and combat stats recalculated when it was equipped.
  An empty/unknown slot is a no-op (the value rAthena returns is not exposed,
  matching the other statement effects). Halts `:no_player` on a detached ctx.
  """
  @spec failedrefitem(Ctx.t(), integer()) :: Ctx.t()
  def failedrefitem(%Ctx{status: {:error, _}} = ctx, _slot), do: ctx

  def failedrefitem(%Ctx{} = ctx, slot) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} -> apply_op(ctx, {:failedrefitem, index, nameid})
      nil -> ctx
    end
  end

  @doc """
  Suppresses inventory item use for the player through the session seam
  (rAthena `disable_items` / `disableitemuse`): while active, item-use requests
  are rejected until cleared by a later script or a fresh session. Used by
  shop/item-exchange NPCs so the player cannot consume items mid-dialog. Haltst
  `:no_player` on a detached ctx.
  """
  @spec disable_items(Ctx.t()) :: Ctx.t()
  def disable_items(%Ctx{status: {:error, _}} = ctx), do: ctx
  def disable_items(%Ctx{} = ctx), do: apply_op(ctx, {:disable_items})

  @doc """
  Gives `qty` of item `item_id` with explicit attributes through the session
  seam (rAthena `getitem2`): `identify`, `refine`, and the four card values
  (`card1`..`card4` map to `card0`..`card3`). The element attribute has no
  Aesir inventory field and is accepted-but-ignored, as documented. Halts
  `:no_player` on a detached ctx.
  """
  @spec getitem2(
          Ctx.t(),
          integer(),
          pos_integer(),
          0 | 1,
          non_neg_integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: Ctx.t()
  # The rAthena `getitem2` buildin carries nine positional args (id, count,
  # identify, refine, attr, four cards); the arity is inherent.
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def getitem2(
        %Ctx{status: {:error, _}} = ctx,
        _item,
        _qty,
        _identify,
        _refine,
        _attr,
        _card1,
        _card2,
        _card3,
        _card4
      ),
      do: ctx

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def getitem2(
        %Ctx{} = ctx,
        item,
        qty,
        identify,
        refine,
        _attr,
        card1,
        card2,
        card3,
        card4
      ) do
    attrs = %{
      identify: identify,
      refine: refine,
      card0: card1,
      card1: card2,
      card2: card3,
      card3: card4
    }

    apply_op(ctx, {:give_item2, item, qty, attrs})
  end

  @doc """
  Runs item `item_id`'s use script on the invoking player (rAthena
  `consumeitem`). The player need not possess the item and nothing is removed
  from inventory — only the item's `on_use` effect runs (inns use this to feed
  stat-food buffs). Delegates to the same compiled item scripts the item-use
  path runs, so the effect (`sc_start`, `heal`, …) applies through the normal
  DSL seams; an item with no `on_use` is a no-op.
  """
  @spec consumeitem(Ctx.t(), integer()) :: Ctx.t()
  def consumeitem(%Ctx{status: {:error, _}} = ctx, _item_id), do: ctx
  def consumeitem(%Ctx{} = ctx, item_id), do: CompiledItemScripts.on_use(item_id, ctx)

  @doc """
  Clears the broken flag on the equipment at inventory `index` through the
  session seam (rAthena `repair`), re-syncing the now-normal row to the client.
  Idempotent: a missing or already-normal row is a no-op success. Never
  re-equips the item - the player re-wears it manually.
  """
  @spec repair(Ctx.t(), non_neg_integer()) :: Ctx.t()
  def repair(%Ctx{status: {:error, _}} = ctx, _index), do: ctx
  def repair(%Ctx{} = ctx, index), do: apply_op(ctx, {:repair, index})

  @doc """
  Clears the broken flag on every broken equipment through the session seam
  (rAthena `repairall`), re-syncing each repaired row to the client. Idempotent
  when nothing is broken. Never re-equips.
  """
  @spec repairall(Ctx.t()) :: Ctx.t()
  def repairall(%Ctx{status: {:error, _}} = ctx), do: ctx
  def repairall(%Ctx{} = ctx), do: apply_op(ctx, {:repairall})

  @doc """
  Item id of the `n`-th broken equipment in the player's inventory (1-indexed,
  slot order; rAthena `getbrokenid`), or 0 when fewer than `n` items are
  broken. Pure read over the snapshot.
  """
  @spec getbrokenid(Ctx.t(), integer()) :: non_neg_integer()
  def getbrokenid(%Ctx{game_state: nil}, _n), do: no_player!("getbrokenid/2")

  def getbrokenid(%Ctx{game_state: gs}, n) when is_integer(n) and n >= 1 do
    gs.inventory
    |> Enum.sort_by(fn {index, _item} -> index end)
    |> Enum.filter(fn {_index, item} -> item.attribute == 1 end)
    |> Enum.at(n - 1)
    |> case do
      {_index, item} -> item.nameid
      nil -> 0
    end
  end

  def getbrokenid(%Ctx{}, _n), do: 0

  @doc """
  Total quantity of item `item_id` the player holds. Pure read over the snapshot.
  """
  @spec count_item(Ctx.t(), integer()) :: non_neg_integer()
  def count_item(%Ctx{game_state: nil}, _item_id), do: no_player!("count_item/2")

  def count_item(%Ctx{game_state: gs}, item_id),
    do: Inventory.held_amount(gs.inventory, item_id)

  @doc """
  Lists every refinable equip in inventory with its current refine state. Pure
  read over `ctx.game_state` + `RefineDatabase`; no session round-trip.
  """
  @spec refine_targets(Ctx.t()) :: [refine_target()]
  def refine_targets(%Ctx{game_state: nil}), do: no_player!("refine_targets/1")

  def refine_targets(%Ctx{game_state: gs}) do
    gs.inventory
    |> Enum.flat_map(&to_refine_target/1)
    |> Enum.sort_by(& &1.index)
  end

  @spec to_refine_target({non_neg_integer(), InventoryItem.t()}) :: [refine_target()]
  defp to_refine_target({index, %InventoryItem{nameid: nameid, refine: refine} = item}) do
    case ItemManagement.get_item_by_id(nameid) do
      {:ok, %ItemDefinition{refineable: true, name: name} = item_def} ->
        [
          %{
            index: index,
            nameid: nameid,
            name: name,
            refine: refine,
            refinable?: refine_eligible?(item, item_def)
          }
        ]

      _not_refinable ->
        []
    end
  end

  @doc """
  Whether the inventory item at `index` is currently refinable (a refineable
  item type, below `MAX_REFINE`). Pure read; `false` for a missing index.
  """
  @spec refinable?(Ctx.t(), non_neg_integer()) :: boolean()
  def refinable?(%Ctx{game_state: nil}, _index), do: no_player!("refinable?/2")

  def refinable?(%Ctx{game_state: gs}, index) do
    case Map.get(gs.inventory, index) do
      %InventoryItem{nameid: nameid} = item ->
        case ItemManagement.get_item_by_id(nameid) do
          {:ok, item_def} -> refine_eligible?(item, item_def)
          {:error, _reason} -> false
        end

      nil ->
        false
    end
  end

  @doc """
  The success rate, as a display-friendly `0..100` percent, of refining the
  item at `index` with `cost_type` — the yml `Rate/100` for the attempt going
  `refine -> refine + 1`. Pure read. `0` when the item is not currently
  refinable or `cost_type` has no entry at this level.
  """
  @spec refine_rate(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type()) :: 0..100
  def refine_rate(%Ctx{game_state: nil}, _index, _cost_type), do: no_player!("refine_rate/3")

  def refine_rate(%Ctx{} = ctx, index, cost_type) do
    case fetch_process(ctx, index, cost_type) do
      {:ok, _level_info, chance} -> div(chance.rate, 100)
      :error -> 0
    end
  end

  @doc """
  The ore/zeny/blessing cost of attempting to refine the item at `index` with
  `cost_type`. Pure read; an ineligible item or missing process data returns an
  all-zero cost with a `nil` ore.
  """
  @spec refine_cost(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type()) :: refine_cost()
  def refine_cost(%Ctx{game_state: nil}, _index, _cost_type), do: no_player!("refine_cost/3")

  def refine_cost(%Ctx{} = ctx, index, cost_type) do
    case fetch_process(ctx, index, cost_type) do
      {:ok, level_info, chance} ->
        %{
          ore_nameid: chance.material_nameid,
          ore_amount: @refine_ore_amount,
          zeny: chance.price,
          blessing_amount: level_info.blessing_amount
        }

      :error ->
        %{ore_nameid: nil, ore_amount: 0, zeny: 0, blessing_amount: 0}
    end
  end

  @doc """
  Attempts to refine the item at inventory `index` using `cost_type` through
  the session seam (ore + zeny, and a Blacksmith Blessing when `use_blessing?`
  is requested and available). Unlike other effect ops, returns the tagged
  `RefineOps` outcome directly instead of folding an updated `ctx` — the script
  branches on the result to drive the rest of the dialog.

  The expected `nameid` at `index` is captured here and threaded into the op as
  a TOCTOU guard: `RefineOps` re-reads the item under the single-writer and
  rejects with `{:error, :no_item}` if the slot changed since the script chose
  it (e.g. from `refine_targets/1`). A missing item at `index` is rejected the
  same way without a session round-trip.

  ponytail: because this returns the tagged result instead of an updated
  `ctx`, a script that keeps dialoging after a successful refine (`mes`/`next`)
  sees the pre-refine `ctx.game_state` (stale zeny/inventory/refine level) —
  fine for branching on the outcome, not fine for a follow-up line that reads
  those values. A real refine NPC will need a refreshed `ctx`; add one if/when
  that NPC is written (Task 10 or later).

  Returns `{:error, :no_player}` on a detached ctx (there is no inventory to
  refine), same tagged-result shape as any other rejection.
  """
  @spec refine(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type(), boolean()) ::
          RefineOps.result()
  def refine(ctx, index, cost_type, use_blessing? \\ false)

  def refine(%Ctx{status: {:error, reason}}, _index, _cost_type, _use_blessing?),
    do: {:error, reason}

  def refine(%Ctx{game_state: nil}, _index, _cost_type, _use_blessing?), do: {:error, :no_player}

  def refine(%Ctx{game_state: gs, session_pid: session_pid}, index, cost_type, use_blessing?) do
    case Map.get(gs.inventory, index) do
      %InventoryItem{nameid: nameid} ->
        PlayerSession.script_apply(
          session_pid,
          {:refine, index, nameid, cost_type, use_blessing?}
        )

      nil ->
        {:error, :no_item}
    end
  end

  @spec refine_eligible?(InventoryItem.t(), ItemDefinition.t()) :: boolean()
  defp refine_eligible?(
         %InventoryItem{refine: refine},
         %ItemDefinition{refineable: true} = item_def
       ) do
    refine < RefineDatabase.max_refine() and
      match?({:ok, _group, _item_level}, RefineDatabase.group_and_level(item_def))
  end

  defp refine_eligible?(%InventoryItem{}, %ItemDefinition{}), do: false

  @spec fetch_process(Ctx.t(), non_neg_integer(), RefineDatabase.cost_type()) ::
          {:ok, RefineDatabase.level_info(), RefineDatabase.chance()} | :error
  defp fetch_process(%Ctx{game_state: gs}, index, cost_type) do
    with %InventoryItem{} = item <- Map.get(gs.inventory, index),
         {:ok, item_def} <- ItemManagement.get_item_by_id(item.nameid),
         true <- refine_eligible?(item, item_def),
         {:ok, group, item_level} <- RefineDatabase.group_and_level(item_def),
         level_info when not is_nil(level_info) <-
           RefineDatabase.level_info(group, item_level, item.refine + 1),
         {:ok, chance} <- Map.fetch(level_info.chances, cost_type) do
      {:ok, level_info, chance}
    else
      _not_refinable -> :error
    end
  end

  @doc """
  Whether the player can carry every `{item_id, amount}` in `items` at once
  (rAthena `checkweight`): `1` when the combined weight fits under the carry
  limit and there are enough free inventory slots for the new item types,
  else `0`.

  The slot check is an approximation — it reserves one slot per distinct item
  type not already held — rather than rAthena's exact per-stack accounting;
  the weight check is exact. Pure read over the ctx snapshot.
  """
  @spec checkweight(Ctx.t(), [{integer(), non_neg_integer()}]) :: 0 | 1
  def checkweight(%Ctx{game_state: nil}, _items), do: no_player!("checkweight/2")

  def checkweight(%Ctx{game_state: gs}, items) do
    added_weight =
      Enum.reduce(items, 0, fn {item_id, amount}, acc -> acc + item_weight(item_id) * amount end)

    weight_ok? = not Weight.would_exceed?(gs.inventory, gs.stats, added_weight)

    new_types =
      items
      |> Enum.map(&elem(&1, 0))
      |> Enum.uniq()
      |> Enum.count(fn item_id -> Inventory.held_amount(gs.inventory, item_id) == 0 end)

    slots_ok? = Inventory.capacity() - map_size(gs.inventory) >= new_types

    if weight_ok? and slots_ok?, do: 1, else: 0
  end

  @spec item_weight(integer()) :: non_neg_integer()
  defp item_weight(item_id) do
    case ItemManagement.get_item_by_id(item_id) do
      {:ok, %ItemDefinition{weight: weight}} -> weight
      {:error, _reason} -> 0
    end
  end
end
