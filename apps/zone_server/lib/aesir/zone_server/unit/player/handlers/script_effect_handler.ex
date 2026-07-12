defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler do
  @moduledoc """
  The single-writer effect seam for the NPC interaction runtime.

  An NPC interaction runs in its own process and holds only a read snapshot of
  the player's `PlayerState`. Every state mutation it needs (`pay_zeny`,
  `give_item`, `delitem`, `set_char_var`, `set_temp_var`, `jobchange`,
  `setquest`, `erasequest`, `completequest`, `changequest`) is routed here as a
  `{:script_apply, op}` `GenServer.call` so the player session stays the sole
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
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @type op ::
          {:pay_zeny, non_neg_integer()}
          | {:credit_zeny, non_neg_integer()}
          | {:give_item, integer(), pos_integer()}
          | {:delitem, integer(), pos_integer()}
          | {:set_char_var, atom(), term()}
          | {:set_temp_var, atom(), term()}
          | {:change_job, non_neg_integer()}
          | {:reset_skills}
          | {:set_save_point, String.t(), non_neg_integer(), non_neg_integer()}
          | {:openstorage}
          | {:refine, non_neg_integer(), integer(), RefineDatabase.cost_type(), boolean()}
          | {:setquest, QuestLog.quest_id()}
          | {:erasequest, QuestLog.quest_id()}
          | {:completequest, QuestLog.quest_id()}
          | {:changequest, QuestLog.quest_id(), QuestLog.quest_id()}

  @max_zeny 1_000_000_000

  @type reply :: {:ok, PlayerState.t()} | RefineOps.result() | {:error, term()}
  @type state :: %{
          required(:connection_pid) => pid(),
          required(:game_state) => PlayerState.t(),
          optional(atom()) => term()
        }

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
    new_zeny = min(gs.zeny + amount, @max_zeny)
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
    do: push_refined_item(connection_pid, new_gs, index)

  defp push_refine_view(connection_pid, new_gs, index, {:ok, :downgrade, _new_level}),
    do: push_refined_item(connection_pid, new_gs, index)

  defp push_refine_view(connection_pid, _new_gs, index, {:ok, :broke}),
    do: MessageRouter.send_to(connection_pid, InventoryView.item_removed(index, 1))

  defp push_refine_view(_connection_pid, _new_gs, _index, {:ok, :fail}), do: :ok
  defp push_refine_view(_connection_pid, _new_gs, _index, {:error, _reason}), do: :ok

  @spec push_refined_item(pid(), PlayerState.t(), non_neg_integer()) :: :ok
  defp push_refined_item(connection_pid, new_gs, index) do
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
end
