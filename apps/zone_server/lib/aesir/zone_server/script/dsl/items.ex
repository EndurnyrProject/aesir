defmodule Aesir.ZoneServer.Script.Dsl.Items do
  @moduledoc """
  Economy and inventory buildins for the script DSL: zeny reads and transfers,
  item grants (plain, grouped, named, rental, bound, attribute-carrying),
  item removal, compiled on-use item scripts, equipment repair, the
  interactive refine flow, and inventory weight checks.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  import Aesir.ZoneServer.Script.Dsl.Internal,
    only: [apply_op: 2, no_player!: 2, equipped_index: 2]

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.CompiledItemScripts
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Announce
  alias Aesir.ZoneServer.Script.Dsl.ItemGrants
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  @unknown_item_id 512

  @doc """
  The player's current zeny. Pure read over the ctx snapshot.
  """
  @spec zeny(Ctx.t()) :: non_neg_integer()
  def zeny(%Ctx{game_state: nil} = ctx), do: no_player!(ctx, "zeny/1")
  def zeny(%Ctx{game_state: gs}), do: gs.zeny

  @doc """
  Debits `amount` zeny through the session seam, pushing the change to the
  client and persisting it. A player who is short pays nothing and the script
  goes on.
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
  emitting `ItemAdded`). A full or overweight inventory fails the command and
  the script goes on.
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
        |> then(&commit_grants(ctx, &1, false))

      :error ->
        Ctx.fail(ctx, :getgroupitem, :unknown_item_group)
    end
  end

  @doc """
  Grants `qty` units of one entry picked from a subgroup.

  This is the reference's single-entry buildin: the pick is one entry (weighted,
  uniform, or one shared-pool copy depending on the subgroup algorithm), the
  grant is `qty` units of it (`0` takes the entry's own amount), and a grant
  that needs more blank slots than the inventory has is refused before any add.
  A refused unit fails the command and the script goes on; units already added
  stay.
  """
  @spec get_rand_group_item(Ctx.t(), atom(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def get_rand_group_item(ctx, group_key, qty, sub),
    do: get_rand_group_item(ctx, group_key, qty, sub, 0, 0)

  @spec get_rand_group_item(Ctx.t(), atom(), non_neg_integer(), non_neg_integer(), term()) ::
          Ctx.t()
  def get_rand_group_item(ctx, group_key, qty, sub, identify),
    do: get_rand_group_item(ctx, group_key, qty, sub, identify, 0)

  @spec get_rand_group_item(
          Ctx.t(),
          atom(),
          non_neg_integer(),
          non_neg_integer(),
          term(),
          integer() | nil
        ) :: Ctx.t()
  def get_rand_group_item(%Ctx{status: {:error, _}} = ctx, _group_key, _qty, _sub, _i, _char_id),
    do: ctx

  def get_rand_group_item(%Ctx{game_state: nil} = ctx, _group_key, _qty, _sub, _i, _char_id),
    do: Ctx.halt(ctx, :no_player)

  def get_rand_group_item(%Ctx{} = ctx, group_key, qty, sub, identify, char_id)
      when is_integer(qty) and qty >= 0 and is_integer(sub) and sub >= 0 and
             (is_integer(char_id) or is_nil(char_id)) do
    identify? = identify not in [0, false, nil]

    with {:ok, group} <- ItemGroups.fetch(group_key),
         grant when is_map(grant) <- Roller.pick_grant(group, sub, qty, identify?: identify?) do
      grant = Map.put(grant, :group_key, group_key)
      deliver_group(ctx, char_id, grant)
    else
      :error -> Ctx.fail(ctx, :getrandgroupitem, :unknown_item_group)
      nil -> Ctx.fail(ctx, :getrandgroupitem, :no_group_entry)
    end
  end

  @spec deliver_group(Ctx.t(), integer() | nil, Group.grant()) :: Ctx.t()
  defp deliver_group(%Ctx{game_state: game_state} = ctx, char_id, grant)
       when char_id in [nil, 0] do
    if blank_slots?(game_state.inventory, grant),
      do: commit_grants(ctx, [grant], true),
      else: Ctx.fail(ctx, :getrandgroupitem, :inventory_full)
  end

  defp deliver_group(%Ctx{char_id: char_id} = ctx, char_id, grant) do
    if blank_slots?(ctx.game_state.inventory, grant),
      do: commit_grants(ctx, [grant], true),
      else: Ctx.fail(ctx, :getrandgroupitem, :inventory_full)
  end

  defp deliver_group(ctx, char_id, grant) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, target_state, pid}} when is_pid(pid) ->
        deliver_to_target(ctx, target_state, pid, grant)

      _offline_or_detached ->
        ctx
    end
  end

  defp deliver_to_target(ctx, target_state, pid, grant) do
    if blank_slots?(Map.get(target_state, :inventory, %{}), grant) do
      case PlayerSession.script_apply(pid, {:give_rand_group_items, [grant]}) do
        {:ok, _target_state} -> ctx
        {:error, reason} -> Ctx.fail(ctx, :getrandgroupitem, reason)
      end
    else
      Ctx.fail(ctx, :getrandgroupitem, :inventory_full)
    end
  end

  @doc """
  Returns one item id from a subgroup without depleting shared-pool state.

  An unknown group or subgroup fails the command and returns the unknown-item
  id (`512`), as the script command does.
  """
  @spec group_rand_item(Ctx.t(), atom(), non_neg_integer()) :: pos_integer()
  def group_rand_item(%Ctx{} = ctx, group_key, sub) do
    with {:ok, group} <- ItemGroups.fetch(group_key),
         {:ok, item_id} <- Roller.pick_id(group, sub) do
      item_id
    else
      :error ->
        Ctx.fail(ctx, :grouprandomitem, {:unknown_item_group, group_key, sub})
        @unknown_item_id
    end
  end

  @doc "Commits concrete item-group grants through the current script context."
  @spec commit_grants(Ctx.t(), [Group.grant()]) :: Ctx.t()
  def commit_grants(ctx, grants), do: commit_grants(ctx, grants, false)

  @spec commit_grants(Ctx.t(), [Group.grant()], boolean()) :: Ctx.t()
  def commit_grants(%Ctx{} = ctx, [], _halt?), do: ctx
  def commit_grants(%Ctx{status: {:error, _}} = ctx, _grants, _halt?), do: ctx

  def commit_grants(%Ctx{session_pid: session_pid} = ctx, grants, halt?)
      when is_pid(session_pid) do
    op = if halt?, do: {:give_rand_group_items, grants}, else: {:give_group_items, grants}
    apply_op(ctx, op)
  end

  def commit_grants(%Ctx{session_pid: nil, game_state: nil} = ctx, _grants, _halt?),
    do: Ctx.halt(ctx, :no_player)

  def commit_grants(%Ctx{session_pid: nil, game_state: game_state} = ctx, grants, halt?) do
    {:ok, inventory, successes, failures} =
      Inventory.give_group(ctx.char_id, game_state.inventory, game_state.stats, grants,
        halt?: halt?
      )

    ctx = announce_successes(%{ctx | game_state: %{game_state | inventory: inventory}}, successes)

    case {halt?, failures} do
      {true, [reason | _]} -> Ctx.fail(ctx, :getrandgroupitem, reason)
      _ -> ctx
    end
  end

  @spec stamp_group_key([Group.grant()], atom()) :: [Group.grant()]
  defp stamp_group_key(grants, group_key),
    do: Enum.map(grants, &Map.put(&1, :group_key, group_key))

  # The handler announces on the session path, where the per-unit successes are
  # known; a detached ctx announces here from the same success list.
  @spec announce_successes(Ctx.t(), [{integer(), boolean()}]) :: Ctx.t()
  defp announce_successes(ctx, successes) do
    Enum.each(successes, fn
      {item_id, true} -> Announce.announce_all("Obtained item #{item_id}.", 0)
      _unit -> :ok
    end)

    ctx
  end

  @spec blank_slots?(Inventory.t(), Group.grant()) :: boolean()
  defp blank_slots?(inventory, grant) do
    case ItemManagement.get_item_by_id(grant.item_id) do
      {:ok, item_def} ->
        needed = if ItemDefinition.stackable?(item_def), do: 1, else: grant.amount
        Inventory.blank_slots(inventory) >= needed

      {:error, _reason} ->
        false
    end
  end

  @doc """
  Gives one identified item signed by an online character through the session seam.
  An offline or unknown target, or an inventory that cannot hold it, fails the
  command and the script goes on.
  """
  @spec get_named_item(Ctx.t(), integer(), String.t() | integer()) :: Ctx.t()
  def get_named_item(%Ctx{status: {:error, _}} = ctx, _item_id, _target), do: ctx

  def get_named_item(%Ctx{} = ctx, item_id, target),
    do: apply_op(ctx, {:get_named_item, item_id, target})

  @doc """
  Builds an item's random options from a script's three option arrays.

  Slot `i` takes element `i` of each array, for as many slots as the id array
  has elements and at most the item's five; a missing value or parameter is 0.
  The id and value are cast to 16-bit and the parameter to 8-bit signed
  integers, the widths of the item's option fields.
  """
  @spec random_options([integer()], [integer()], [integer()]) :: ItemOptions.t()
  def random_options(ids, values, params) do
    ids
    |> Enum.take(ItemOptions.max_options())
    |> Enum.with_index()
    |> Enum.map(fn {id, i} ->
      %{
        id: signed(id, 16),
        value: signed(Enum.at(values, i, 0), 16),
        param: signed(Enum.at(params, i, 0), 8)
      }
    end)
    |> ItemOptions.trim()
  end

  defp signed(value, bits) do
    <<cast::signed-size(^bits)>> = <<value::size(bits)>>
    cast
  end

  @doc """
  Gives one time-limited rental item through the session seam (rAthena
  `rentitem`): any item type, for any number of seconds. An integer last
  argument is the account id of the player to rent it to.
  """
  @spec give_item_rental(Ctx.t(), integer(), integer(), keyword() | integer()) :: Ctx.t()
  def give_item_rental(ctx, item_id, seconds, opts \\ [])

  def give_item_rental(%Ctx{status: {:error, _}} = ctx, _id, _secs, _opts), do: ctx

  def give_item_rental(%Ctx{} = ctx, item_id, seconds, account_id) when is_integer(account_id),
    do: ItemGrants.rentitem(ctx, item_id, seconds, account_id)

  def give_item_rental(%Ctx{} = ctx, item_id, seconds, opts),
    do: apply_op(ctx, {:give_item_rental, item_id, seconds, opts})

  @doc """
  Gives `qty` of item `item_id` through the session seam with an account or
  character binding.
  """
  @spec give_item_bound(Ctx.t(), integer(), pos_integer(), :account | :char | integer()) ::
          Ctx.t()
  def give_item_bound(%Ctx{status: {:error, _}} = ctx, _item_id, _qty, _bound), do: ctx

  def give_item_bound(%Ctx{} = ctx, item_id, qty, bound) do
    case bound_value(bound) do
      {:ok, value} -> apply_op(ctx, {:give_item_bound, item_id, qty, value})
      :error -> Ctx.fail(ctx, :getitembound, :bad_bound)
    end
  end

  defp bound_value(:account), do: {:ok, 1}
  defp bound_value(:char), do: {:ok, 4}
  defp bound_value(bound) when bound in 0..4, do: {:ok, bound}
  defp bound_value(_bound), do: :error

  @doc """
  Removes the equipment worn in equip `slot` (rAthena `delequip`) through the
  session seam: the item is unequipped first (appearance broadcast, stats
  recompute), then its inventory row is deleted. An empty or unknown slot ends
  the script (`:not_equipped`). Like the other granting/removing effects the
  value rAthena returns is not exposed. Halts `:no_player` on a detached ctx.
  """
  @spec delequip(Ctx.t(), integer()) :: Ctx.t()
  def delequip(%Ctx{status: {:error, _}} = ctx, _slot), do: ctx
  def delequip(%Ctx{game_state: nil} = ctx, _slot), do: Ctx.halt(ctx, :no_player)

  def delequip(%Ctx{} = ctx, slot) do
    case equipped_index(ctx, slot) do
      {index, %InventoryItem{nameid: nameid}} -> apply_op(ctx, {:delequip, index, nameid})
      nil -> Ctx.halt(ctx, :not_equipped)
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
  Refuses item use, equipping and self skills for the rest of this script's
  dialog through the session seam (rAthena `disable_items` / `disableitemuse`).
  Each script starts from the mode's default: allowed in pre-renewal, refused
  in renewal. Halts `:no_player` on a detached ctx.
  """
  @spec disable_items(Ctx.t()) :: Ctx.t()
  def disable_items(%Ctx{status: {:error, _}} = ctx), do: ctx
  def disable_items(%Ctx{} = ctx), do: apply_op(ctx, {:disable_items})

  @doc """
  Allows item use, equipping and self skills for the rest of this script's
  dialog through the session seam (rAthena `enable_items` / `enableitemuse`).
  Halts `:no_player` on a detached ctx.
  """
  @spec enable_items(Ctx.t()) :: Ctx.t()
  def enable_items(%Ctx{status: {:error, _}} = ctx), do: ctx
  def enable_items(%Ctx{} = ctx), do: apply_op(ctx, {:enable_items})

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

  def consumeitem(%Ctx{} = ctx, item_id) do
    ended = CompiledItemScripts.on_use(item_id, ctx)
    %{ended | status: ctx.status}
  end

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
  def getbrokenid(%Ctx{game_state: nil} = ctx, _n), do: no_player!(ctx, "getbrokenid/2")

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
  Lists every refinable equip in inventory with its current refine state. Pure
  read over `ctx.game_state` + `RefineDatabase`; no session round-trip.
  """
  @spec refine_targets(Ctx.t()) :: [refine_target()]
  def refine_targets(%Ctx{game_state: nil} = ctx), do: no_player!(ctx, "refine_targets/1")

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
  def refinable?(%Ctx{game_state: nil} = ctx, _index), do: no_player!(ctx, "refinable?/2")

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
  def refine_rate(%Ctx{game_state: nil} = ctx, _index, _cost_type),
    do: no_player!(ctx, "refine_rate/3")

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
  def refine_cost(%Ctx{game_state: nil} = ctx, _index, _cost_type),
    do: no_player!(ctx, "refine_cost/3")

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
  the weight check is exact. An unknown item or an amount below 1 fails the
  command and reads `0`. Pure read over the ctx snapshot.
  """
  @spec checkweight(Ctx.t(), [{integer(), non_neg_integer()}]) :: 0 | 1
  def checkweight(%Ctx{game_state: nil} = ctx, _items), do: no_player!(ctx, "checkweight/2")

  def checkweight(%Ctx{} = ctx, items) do
    if Enum.all?(items, &valid_weight_entry?/1) do
      weigh(ctx, items)
    else
      Ctx.fail(ctx, :checkweight, :invalid_item_or_amount)
      0
    end
  end

  defp valid_weight_entry?({item_id, amount}) when amount >= 1,
    do: match?({:ok, _item}, ItemManagement.get_item_by_id(item_id))

  defp valid_weight_entry?(_entry), do: false

  defp weigh(%Ctx{game_state: gs}, items) do
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
