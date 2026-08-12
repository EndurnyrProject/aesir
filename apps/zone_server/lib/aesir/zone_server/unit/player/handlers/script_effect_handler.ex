defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler do
  @moduledoc """
  The single-writer effect seam for the NPC interaction runtime.

  An NPC interaction runs in its own process and holds only a read snapshot of
  the player's `PlayerState`. Every state mutation it needs (`pay_zeny`,
  `give_item`, `give_item_rental`, `delitem`, `getexp`, `set_char_var`, `set_temp_var`, `jobchange`,
  `setquest`, `erasequest`, `completequest`, `changequest`) is routed here as a
  `{:npc, {:script_apply, op}}` `GenServer.call` so the player session stays the sole
  writer of its own state. This module applies the op to the authoritative
  state, persists the change, pushes the relevant proto to the client, and
  returns `{reply, new_state}` where `reply` is
  `{:ok, PlayerState.t()} | {:error, reason}`: the fresh `game_state` the
  interaction folds back into its `ctx`, or an error that halts the script. On
  any error the session state is returned untouched.
  """

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.BreakOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ExperienceHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Rental
  alias Aesir.ZoneServer.Unit.Zeny

  @type op ::
          {:pay_zeny, non_neg_integer()}
          | {:credit_zeny, non_neg_integer()}
          | {:give_item, integer(), pos_integer()}
          | {:give_item2, integer(), pos_integer(), map()}
          | {:give_items_atomic, [map()]}
          | {:get_named_item, integer(), String.t() | integer()}
          | {:give_item_rental, integer(), pos_integer(), keyword()}
          | {:give_item_bound, integer(), pos_integer(), 1 | 4}
          | {:delitem, integer(), pos_integer()}
          | {:delequip, non_neg_integer(), integer()}
          | {:successrefitem, non_neg_integer(), integer(), pos_integer()}
          | {:failedrefitem, non_neg_integer(), integer()}
          | {:disable_items}
          | {:nude}
          | {:getexp, non_neg_integer(), non_neg_integer()}
          | {:set_char_var, atom(), term()}
          | {:set_temp_var, atom(), term()}
          | {:change_job, non_neg_integer()}
          | {:reset_skills}
          | {:grant_skill, integer() | atom(), pos_integer()}
          | {:set_save_point, String.t(), non_neg_integer(), non_neg_integer()}
          | {:openstorage}
          | {:setcart, non_neg_integer()}
          | {:set_riding, boolean()}
          | {:set_falcon, boolean()}
          | {:refine, non_neg_integer(), integer(), RefineDatabase.cost_type(), boolean()}
          | {:repair, non_neg_integer()}
          | {:repairall}
          | {:setquest, QuestLog.quest_id()}
          | {:erasequest, QuestLog.quest_id()}
          | {:completequest, QuestLog.quest_id()}
          | {:changequest, QuestLog.quest_id(), QuestLog.quest_id()}

  @type reply :: {:ok, PlayerState.t()} | RefineOps.result() | {:error, term()}
  @type state :: %{
          required(:connection_pid) => pid(),
          required(:game_state) => PlayerState.t(),
          optional(atom()) => term()
        }

  @doc """
  GenServer-native entry point for the session's `{:npc, {:script_apply, op}}` call.

  Wraps `apply_op/2` and, on success, commits the new state to the unit
  registry and party/guild views via `StateCommit.commit/2`; on
  `{:error, reason}` the state is returned untouched.
  """
  @spec handle_script_apply(op(), state()) :: {:reply, reply(), state()}
  def handle_script_apply(op, state) do
    {reply, new_state} = apply_op(op, state)

    case reply do
      {:error, _reason} ->
        {:reply, reply, new_state}

      _ok_reply ->
        announce_change(op, new_state.game_state.character_id)
        {:reply, reply, StateCommit.commit(new_state, new_state.game_state)}
    end
  end

  # Announce the domain fact a successful script op represents, so reactors
  # (quest-icon bubbles today) can respond without this handler naming them.
  # Ops with no bearing on observable player state emit nothing.
  defp announce_change(op, char_id) do
    case op_fact(op) do
      :quest_changed -> PlayerEvents.quest_changed(char_id)
      :inventory_changed -> PlayerEvents.inventory_changed(char_id)
      :progression_changed -> PlayerEvents.progression_changed(char_id)
      :vars_changed -> PlayerEvents.vars_changed(char_id)
      nil -> :ok
    end
  end

  defp op_fact(op) when is_tuple(op) do
    case elem(op, 0) do
      tag when tag in [:setquest, :erasequest, :completequest, :changequest] ->
        :quest_changed

      tag when tag in [:change_job, :getexp] ->
        :progression_changed

      tag
      when tag in [
             :give_item,
             :give_item2,
             :delitem,
             :delequip,
             :successrefitem,
             :failedrefitem,
             :give_item_bound,
             :give_item_rental,
             :get_named_item,
             :give_items_atomic
           ] ->
        :inventory_changed

      tag when tag in [:set_char_var, :set_temp_var] ->
        :vars_changed

      _ ->
        nil
    end
  end

  defp op_fact(_op), do: nil

  @doc """
  Applies `op` to the session `state`, returning `{reply, new_state}`.

  `reply` is `{:ok, game_state}` on success (with the change persisted and pushed
  to the client) or `{:error, reason}` on failure, in which case `new_state`
  equals the input `state`.
  """
  @spec apply_op(op(), state()) :: {reply(), state()}
  def apply_op({:pay_zeny, amount}, %{game_state: gs} = state) do
    if gs.zeny < amount do
      {{:error, :not_enough_zeny}, state}
    else
      new_zeny = gs.zeny - amount
      new_gs = %{gs | zeny: new_zeny}

      StatusSync.send_param(state.connection_pid, StatusParams.zeny(), new_zeny)
      CharacterPersistence.update_character(gs.character_id, %{zeny: new_zeny}, async: true)

      commit(state, new_gs)
    end
  end

  def apply_op({:credit_zeny, amount}, %{game_state: gs} = state) do
    new_zeny = min(gs.zeny + amount, Zeny.max_zeny())
    new_gs = %{gs | zeny: new_zeny}

    StatusSync.send_param(state.connection_pid, StatusParams.zeny(), new_zeny)
    CharacterPersistence.update_character(gs.character_id, %{zeny: new_zeny}, async: true)

    commit(state, new_gs)
  end

  def apply_op({:give_item, item_id, qty}, %{game_state: gs} = state) do
    with {:ok, definition} <- fetch_definition(item_id),
         {:ok, persisted, change} <-
           InventoryOps.add(gs.character_id, gs.inventory, gs.stats, definition, qty) do
      push_added(state.connection_pid, persisted, change)
      commit(state, %{gs | inventory: persisted})
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  # rAthena `getitem2`: grants an item with explicit identify/refine/card
  # attributes through `InventoryOps.add`'s opts map. `attr`/`attr2` (the
  # element attribute) have no Aesir inventory field and are dropped by the
  # DSL before this op is built.
  def apply_op({:give_item2, item_id, qty, attrs}, %{game_state: gs} = state) do
    with {:ok, definition} <- fetch_definition(item_id),
         {:ok, persisted, change} <-
           InventoryOps.add(gs.character_id, gs.inventory, gs.stats, definition, qty, attrs) do
      push_added(state.connection_pid, persisted, change)
      commit(state, %{gs | inventory: persisted})
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:give_items_atomic, grants}, %{game_state: gs} = state) do
    case Inventory.give_many(gs.character_id, gs.inventory, gs.stats, grants) do
      {:ok, inventory} -> commit(state, %{gs | inventory: inventory})
      {:error, :insufficient_space} -> {{:error, :insufficient_space}, state}
    end
  end

  def apply_op({:get_named_item, item_id, target}, %{game_state: gs} = state) do
    with {:ok, definition} <- fetch_definition(item_id),
         {:ok, creator_char_id} <- CreatorNames.resolve_online_target(target),
         craft = ItemCraft.to_map(ItemCraft.signed(creator_char_id)),
         {:ok, persisted, change} <-
           InventoryOps.add(gs.character_id, gs.inventory, gs.stats, definition, 1, %{
             identify: 1,
             craft: craft
           }) do
      push_added(state.connection_pid, persisted, change)
      commit(state, %{gs | inventory: persisted})
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:give_item_rental, item_id, seconds, opts}, %{game_state: gs} = state) do
    with {:ok, definition} <- fetch_definition(item_id),
         true <- seconds > 0 || {:error, :bad_duration},
         true <- Rental.rentable_type?(definition) || {:error, :not_rentable},
         {:ok, persisted, change} <-
           InventoryOps.add(
             gs.character_id,
             gs.inventory,
             gs.stats,
             definition,
             1,
             opts
             |> Map.new()
             |> Map.take([:refine, :card0, :card1, :card2, :card3, :random_options])
             |> Map.put(:expire_time, Rental.expire_at(seconds, NaiveDateTime.utc_now()))
           ) do
      push_added(state.connection_pid, persisted, change)
      commit(state, %{gs | inventory: persisted})
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:give_item_bound, item_id, qty, bound}, %{game_state: gs} = state) do
    with {:ok, definition} <- fetch_definition(item_id),
         {:ok, persisted, change} <-
           InventoryOps.add(gs.character_id, gs.inventory, gs.stats, definition, qty, %{
             bound: bound
           }) do
      push_added(state.connection_pid, persisted, change)
      commit(state, %{gs | inventory: persisted})
    else
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:delitem, item_id, qty}, %{game_state: gs} = state) do
    with true <-
           Inventory.held_amount(gs.inventory, item_id) >= qty || {:error, :not_enough_items},
         index when is_integer(index) <- Inventory.stackable_index(gs.inventory, item_id),
         {:ok, persisted, _change} <-
           InventoryOps.remove(gs.character_id, gs.inventory, index, qty) do
      MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(index, qty))
      commit(state, %{gs | inventory: persisted})
    else
      {:error, reason} -> {{:error, reason}, state}
      nil -> {{:error, :not_enough_items}, state}
    end
  end

  # rAthena `delequip`: removes the equipped item at `index`. It is unequipped
  # first (appearance broadcast, stat recompute) so the client and stat layer
  # agree, then its row is deleted. The expected `nameid` is re-checked under
  # the single-writer as a TOCTOU guard against the script's snapshot being
  # stale; a non-equipped or missing item rejects the op.
  def apply_op({:delequip, index, nameid}, %{game_state: gs} = state) do
    case Map.get(gs.inventory, index) do
      %InventoryItem{nameid: ^nameid, equip: equip} when equip > 0 ->
        {:noreply, unequipped_state} = EquipmentHandler.handle_unequip(index, state)
        new_gs = unequipped_state.game_state

        case InventoryOps.remove(new_gs.character_id, new_gs.inventory, index, 1) do
          {:ok, persisted, _change} ->
            MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(index, 1))
            commit(unequipped_state, %{new_gs | inventory: persisted})

          {:error, reason} ->
            {{:error, reason}, unequipped_state}
        end

      %InventoryItem{nameid: ^nameid} ->
        {{:error, :not_equipped}, state}

      _not_or_changed ->
        {{:error, :no_item}, state}
    end
  end

  # rAthena `successrefitem`: force a script-driven refine success (+`up`)
  # on the equipped item at `index` with no material cost. The level is
  # mutated and stats recalculated in `RefineOps`; the owner's item view is
  # re-sent for the new +N. Error replies are passed through untouched.
  def apply_op({:successrefitem, index, nameid, up}, %{game_state: gs} = state) do
    case RefineOps.success(gs, index, nameid, up) do
      {new_gs, {:ok, _new_refine}} ->
        push_item_view(state.connection_pid, new_gs, index)
        commit(state, new_gs)

      {_gs, {:error, reason}} ->
        {{:error, reason}, state}
    end
  end

  # rAthena `failedrefitem`: force a script-driven refine failure that destroys
  # the equipped item at `index`. The removal is persisted and stats recalculated
  # in `RefineOps`; the owner's item view reflects the removal.
  def apply_op({:failedrefitem, index, nameid}, %{game_state: gs} = state) do
    case RefineOps.fail(gs, index, nameid) do
      {new_gs, {:ok, :destroyed}} ->
        MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(index, 1))
        commit(state, new_gs)

      {_gs, {:error, reason}} ->
        {{:error, reason}, state}
    end
  end

  # rAthena `disable_items` (disableitemuse): suppresses inventory item use for
  # the player while the script runs; `ItemHandler` rejects use requests until
  # the flag is cleared (a later script or a fresh session).
  def apply_op({:disable_items}, %{game_state: gs} = state) do
    commit(state, %{gs | disable_item_use: true})
  end

  def apply_op({:getexp, base_exp, job_exp}, state) do
    {:noreply, new_state} =
      ExperienceHandler.handle_gain_exp(
        apply_quest_exp_rate(base_exp),
        apply_quest_exp_rate(job_exp),
        state
      )

    {{:ok, new_state.game_state}, new_state}
  end

  # Unequips every equipped slot (rAthena `nude`) by folding the single-item
  # unequip over the currently-worn indices; each takeoff persists, acks, and
  # broadcasts its own appearance change. A no-op when nothing is equipped.
  def apply_op({:nude}, %{game_state: gs} = state) do
    new_state =
      gs.inventory
      |> Inventory.equipped_items()
      |> Map.keys()
      |> Enum.reduce(state, fn index, acc ->
        {:noreply, next} = EquipmentHandler.handle_unequip(index, acc)
        next
      end)

    {{:ok, new_state.game_state}, new_state}
  end

  def apply_op({:set_char_var, key, value}, %{game_state: gs} = state) do
    vars = Map.put(gs.vars, to_string(key), value)

    CharacterPersistence.update_character(gs.character_id, %{vars: vars}, async: true)

    commit(state, %{gs | vars: vars})
  end

  def apply_op({:set_temp_var, key, value}, %{game_state: gs} = state) do
    commit(state, %{gs | temp_vars: Map.put(gs.temp_vars, to_string(key), value)})
  end

  def apply_op({:change_job, job_id}, state) do
    case ProgressionHandler.apply_job_change(job_id, state) do
      {:ok, new_state} -> {{:ok, new_state.game_state}, new_state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:reset_skills}, state) do
    case ProgressionHandler.reset_skills(state) do
      {:ok, new_state} -> {{:ok, new_state.game_state}, new_state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:grant_skill, skill_id_or_name, level}, state) do
    case SkillLearningHandler.grant_skill(skill_id_or_name, level, state) do
      {:ok, new_state} -> {{:ok, new_state.game_state}, new_state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:set_save_point, map, x, y}, %{game_state: gs} = state) do
    new_gs = %{gs | save_map: map, save_x: x, save_y: y}

    CharacterPersistence.update_character(
      gs.character_id,
      %{save_map: map, save_x: x, save_y: y},
      async: true
    )

    commit(state, new_gs)
  end

  def apply_op({:openstorage}, state) do
    {:noreply, new_state} = StorageHandler.open(state)
    {{:ok, new_state.game_state}, new_state}
  end

  # rAthena `setcart`: type 0 removes the cart, any other type mounts it.
  # Both delegate to `CartHandler`, which enforces the mount gates
  # (MC_PUSHCART learned, empty cart on removal) and reports rejections to
  # the client; a rejection leaves the state untouched but still replies
  # `{:ok, gs}` so the script continues, matching rAthena's silent failure.
  def apply_op({:setcart, 0}, state) do
    {:noreply, new_state} = CartHandler.unmount(state)
    {{:ok, new_state.game_state}, new_state}
  end

  def apply_op({:setcart, _type}, %{game_state: gs} = state) do
    if gs.cart_type > 0 do
      {{:ok, gs}, state}
    else
      {:noreply, new_state} = CartHandler.mount(state)
      {{:ok, new_state.game_state}, new_state}
    end
  end

  # ponytail: only the owner's inventory view is re-sent here (design step 5).
  # Design step 4's own-client stat-param push after an equipped-item refine
  # is deferred — RefineOps already recalculates `new_gs.stats` server-side and
  # the registry sync below keeps other players' view of this unit correct;
  # only the owning client's own StatusParams push (str/def/atk/etc.) is
  # missing. Add a StatusSync push here (mirroring `apply_heal/3` in `Dsl`) if
  # a real refine NPC needs the owner's stat window to update live.
  def apply_op({:refine, index, nameid, cost_type, use_blessing?}, %{game_state: gs} = state) do
    {new_gs, result} = RefineOps.apply(gs, index, nameid, cost_type, use_blessing?)
    push_refine_view(state.connection_pid, new_gs, index, result)
    {result, %{state | game_state: new_gs}}
  end

  def apply_op({:repair, index}, %{game_state: gs} = state) do
    was_broken? = match?(%InventoryItem{attribute: 1}, Map.get(gs.inventory, index))

    case BreakOps.repair(gs, index) do
      {:ok, new_gs} ->
        if was_broken?, do: push_item_view(state.connection_pid, new_gs, index)
        commit(state, new_gs)

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  def apply_op({:repairall}, %{game_state: gs} = state) do
    broken_indices = for {index, %InventoryItem{attribute: 1}} <- gs.inventory, do: index

    case BreakOps.repair_all(gs) do
      {:ok, new_gs} ->
        Enum.each(broken_indices, &push_item_view(state.connection_pid, new_gs, &1))
        commit(state, new_gs)

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  # Unlike `setcart`'s silent rejection, a script mount is expected to
  # succeed: the KN_RIDING gate stays in MountHandler, and a rejected mount
  # (not learned, dead) is surfaced as `{:error, :cannot_mount}` instead of
  # continuing silently. `riding?/1` after the call is the only signal
  # `mount/1` exposes beyond the client-facing `MountResult` push, and it
  # also makes an already-mounted call a no-op success, matching `mount/1`'s
  # own idempotence.
  def apply_op({:set_riding, true}, state) do
    {:noreply, new_state} = MountHandler.mount(state)

    if MountHandler.riding?(new_state) do
      {{:ok, new_state.game_state}, new_state}
    else
      {{:error, :cannot_mount}, state}
    end
  end

  # Dismounting is always a no-op success (mounted or not), mirroring
  # `MountHandler.dismount/1`'s own MOUNT_NOT_MOUNTED no-op semantics.
  def apply_op({:set_riding, false}, state) do
    {:noreply, new_state} = MountHandler.dismount(state)
    {{:ok, new_state.game_state}, new_state}
  end

  def apply_op({:set_falcon, enabled?}, state) do
    case FalconHandler.set_falcon(state, enabled?) do
      {:ok, new_state} -> {{:ok, new_state.game_state}, new_state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  def apply_op({:setquest, quest_id}, %{game_state: gs} = state) do
    case QuestLog.add(gs.quest_log, quest_id) do
      {:ok, quest_log, entry} ->
        QuestPersistence.upsert(gs.character_id, {quest_id, entry})
        MessageRouter.send_to(state.connection_pid, QuestView.quest_added(quest_id, entry))
        commit(state, %{gs | quest_log: quest_log})

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  def apply_op({:erasequest, quest_id}, %{game_state: gs} = state) do
    case QuestLog.delete(gs.quest_log, quest_id) do
      {:ok, quest_log} ->
        QuestPersistence.delete(gs.character_id, quest_id)
        MessageRouter.send_to(state.connection_pid, QuestView.quest_removed(quest_id))
        commit(state, %{gs | quest_log: quest_log})

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  def apply_op({:completequest, quest_id}, %{game_state: gs} = state) do
    case QuestLog.complete(gs.quest_log, quest_id) do
      {:ok, quest_log} ->
        entry = Map.fetch!(quest_log, quest_id)
        QuestPersistence.upsert(gs.character_id, {quest_id, entry})

        MessageRouter.send_to(
          state.connection_pid,
          QuestView.quest_state_changed(quest_id, entry.state)
        )

        commit(state, %{gs | quest_log: quest_log})

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  def apply_op({:changequest, old_id, new_id}, %{game_state: gs} = state) do
    case QuestLog.change(gs.quest_log, old_id, new_id) do
      {:ok, quest_log, entry} ->
        QuestPersistence.delete(gs.character_id, old_id)
        QuestPersistence.upsert(gs.character_id, {new_id, entry})
        MessageRouter.send_to(state.connection_pid, QuestView.quest_removed(old_id))
        MessageRouter.send_to(state.connection_pid, QuestView.quest_added(new_id, entry))
        commit(state, %{gs | quest_log: quest_log})

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  @spec commit(state(), PlayerState.t()) :: {reply(), state()}
  defp commit(state, new_gs), do: {{:ok, new_gs}, %{state | game_state: new_gs}}

  @spec fetch_definition(integer()) :: {:ok, term()} | {:error, :item_not_found}
  defp fetch_definition(item_id) do
    case Items.by_id(item_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :item_not_found}
    end
  end

  defp push_added(connection_pid, inventory, change) do
    Enum.each(affected_indices(change), fn index ->
      item = PlayerState.get_by_index(inventory, index)
      MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))
    end)
  end

  # Re-sends the owner's item view for the touched refine index (design step
  # 5): the new +N on success/downgrade, the removal on break; nothing on a
  # plain/blessing-protected fail or a rejected attempt (nothing changed).
  @spec push_refine_view(pid(), PlayerState.t(), non_neg_integer(), RefineOps.result()) :: :ok
  defp push_refine_view(connection_pid, new_gs, index, {:ok, :success, _new_level}),
    do: push_item_view(connection_pid, new_gs, index)

  defp push_refine_view(connection_pid, new_gs, index, {:ok, :downgrade, _new_level}),
    do: push_item_view(connection_pid, new_gs, index)

  defp push_refine_view(connection_pid, _new_gs, index, {:ok, :broke}),
    do: MessageRouter.send_to(connection_pid, InventoryView.item_removed(index, 1))

  defp push_refine_view(_connection_pid, _new_gs, _index, {:ok, :fail}), do: :ok
  defp push_refine_view(_connection_pid, _new_gs, _index, {:error, _reason}), do: :ok

  # Re-sends the owner's item view for a mutated row (e.g. a refine downgrade or
  # a repair clearing the broken flag). No-op if the index no longer holds a row.
  @spec push_item_view(pid(), PlayerState.t(), non_neg_integer()) :: :ok
  defp push_item_view(connection_pid, new_gs, index) do
    case Map.get(new_gs.inventory, index) do
      %InventoryItem{} = item ->
        MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))

      nil ->
        :ok
    end
  end

  defp affected_indices({:added, index, _item}), do: [index]
  defp affected_indices({:stacked, index, _total}), do: [index]

  defp affected_indices({:split, [{topped_index, _}, {new_index, _}]}),
    do: [topped_index, new_index]

  # Scales script/quest EXP grants by the server quest-EXP rate before the
  # per-character status/equipment EXP bonuses are applied downstream.
  @spec apply_quest_exp_rate(non_neg_integer()) :: non_neg_integer()
  defp apply_quest_exp_rate(amount) do
    case Config.quest_exp_rate() do
      100 -> amount
      rate -> div(amount * rate, 100)
    end
  end
end
