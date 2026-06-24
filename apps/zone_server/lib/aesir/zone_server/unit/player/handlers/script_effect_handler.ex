defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler do
  @moduledoc """
  The single-writer effect seam for the NPC interaction runtime.

  An NPC interaction runs in its own process and holds only a read snapshot of
  the player's `PlayerState`. Every state mutation it needs (`pay_zeny`,
  `give_item`, `delitem`, `set_char_var`) is routed here as a
  `{:script_apply, op}` `GenServer.call` so the player session stays the sole
  writer of its own state. This module applies the op to the authoritative
  state, persists the change, pushes the relevant proto to the client, and
  returns `{reply, new_state}` where `reply` is
  `{:ok, PlayerState.t()} | {:error, reason}`: the fresh `game_state` the
  interaction folds back into its `ctx`, or an error that halts the script. On
  any error the session state is returned untouched.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @type op ::
          {:pay_zeny, non_neg_integer()}
          | {:give_item, integer(), pos_integer()}
          | {:delitem, integer(), pos_integer()}
          | {:set_char_var, atom(), term()}

  @type reply :: {:ok, PlayerState.t()} | {:error, term()}
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
      MessageRouter.send_to(state.connection_pid, PacketHandler.item_removed(index, qty))
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
      MessageRouter.send_to(connection_pid, PacketHandler.item_added(item, index))
    end)
  end

  defp affected_indices({:added, index, _item}), do: [index]
  defp affected_indices({:stacked, index, _total}), do: [index]

  defp affected_indices({:split, [{topped_index, _}, {new_index, _}]}),
    do: [topped_index, new_index]
end
