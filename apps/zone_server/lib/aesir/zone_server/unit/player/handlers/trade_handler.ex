defmodule Aesir.ZoneServer.Unit.Player.Handlers.TradeHandler do
  @moduledoc """
  Owns the player-session side of trade invitations and accepted trade lifecycle events.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.TradeCancelled
  alias Aesir.Net.TradeCompleted
  alias Aesir.Net.TradeOfferUpdate
  alias Aesir.Net.TradeOpened
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.TradeRequestReceived
  alias Aesir.Net.TradeResponse
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Trade
  alias Aesir.ZoneServer.Unit.Trade.Session, as: TradeSession
  alias Aesir.ZoneServer.Unit.Trade.Supervisor, as: TradeSupervisor
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @invite_ttl_ms 30_000
  @trade_range 2

  @spec handle_trade_request(SessionState.t(), TradeRequest.t()) ::
          {:noreply, SessionState.t()}
  def handle_trade_request(state, %TradeRequest{target_gid: target_gid}) do
    result =
      with :ok <- eligible?(state),
           :ok <- reject_self(state.game_state.character_id, target_gid),
           {:ok, target, target_pid} <- player(target_gid),
           :ok <- in_range?(state.game_state, target) do
        deliver_request(target_pid, invite(state))
      end

    case result do
      :ok -> {:noreply, state}
      {:error, reason} -> {:noreply, send_cancelled(state, reason)}
    end
  end

  @spec handle_deliver_request(map(), SessionState.t()) ::
          {:reply, :ok | {:error, atom()}, SessionState.t()}
  def handle_deliver_request(invite, state) do
    case eligible?(state) do
      :ok ->
        expires_at = System.monotonic_time(:millisecond) + @invite_ttl_ms
        pending = Map.put(invite, :expires_at, expires_at)

        Process.send_after(
          self(),
          {:trade_invite_expired, invite.requester_char_id, expires_at},
          @invite_ttl_ms
        )

        MessageRouter.send_to(state.connection_pid, %TradeRequestReceived{
          char_id: invite.requester_char_id,
          name: invite.requester_name
        })

        {:reply, :ok, %{state | pending_trade_invite: pending}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @spec handle_trade_response(SessionState.t(), TradeResponse.t()) ::
          {:noreply, SessionState.t()}
  def handle_trade_response(state, %TradeResponse{accept: accept}) do
    case take_pending_invite(state) do
      {:ok, invite, state} when accept -> accept_invite(invite, state)
      {:ok, invite, state} -> decline_invite(invite, state)
      {:expired, invite, state} -> expire_invite(invite, state)
      :error -> {:noreply, state}
    end
  end

  @spec handle_invite_expiry(integer(), integer(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_invite_expiry(
        requester_char_id,
        expires_at,
        %{
          pending_trade_invite:
            %{requester_char_id: requester_char_id, expires_at: expires_at} = invite
        } = state
      ) do
    expire_invite(invite, %{state | pending_trade_invite: nil})
  end

  def handle_invite_expiry(_requester_char_id, _expires_at, state), do: {:noreply, state}

  @spec handle_invite_cancelled(atom(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_invite_cancelled(reason, %{trade: nil} = state) do
    {:noreply, send_cancelled(state, reason)}
  end

  def handle_invite_cancelled(_reason, state), do: {:noreply, state}

  @spec handle_accept(map(), SessionState.t()) ::
          {:reply, :ok | {:error, atom()}, SessionState.t()}
  def handle_accept(acceptor, state) do
    result =
      with :ok <- eligible?(state),
           {:ok, acceptor_state, acceptor_pid} <- player(acceptor.char_id),
           true <- acceptor_pid == acceptor.pid,
           :ok <- ensure_living(acceptor_state),
           :ok <- ensure_idle(acceptor_state),
           :ok <- in_range?(state.game_state, acceptor_state),
           {:ok, _trade_pid} <-
             TradeSupervisor.start_child(%{
               a: %{pid: self(), char_id: state.game_state.character_id},
               b: acceptor
             }) do
        :ok
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :busy}
      end

    case result do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, send_cancelled(state, reason)}
    end
  end

  @spec handle_add_item(SessionState.t(), integer(), integer()) ::
          {:noreply, SessionState.t()}
  def handle_add_item(%{trade: nil} = state, _index, _amount), do: {:noreply, state}

  def handle_add_item(state, client_index, amount) do
    row =
      PlayerState.get_by_index(state.game_state.inventory, PlayerState.server_index(client_index))

    with %Aesir.Commons.Models.InventoryItem{} = row <- row,
         true <- is_integer(row.id),
         true <- is_integer(amount) and amount >= 1 and amount <= row.amount,
         {:ok, %ItemDefinition{} = item_def} <- ItemManagement.get_item_by_id(row.nameid),
         :ok <- Trade.offerable?(row, item_def) do
      forward(state, &TradeSession.add_item(&1, row, amount))
    else
      _ -> {:noreply, state}
    end
  end

  @spec handle_remove_item(SessionState.t(), integer()) :: {:noreply, SessionState.t()}
  def handle_remove_item(%{trade: nil} = state, _index), do: {:noreply, state}

  def handle_remove_item(state, client_index) do
    case PlayerState.get_by_index(
           state.game_state.inventory,
           PlayerState.server_index(client_index)
         ) do
      %{id: row_id} when is_integer(row_id) ->
        forward(state, &TradeSession.remove_item(&1, row_id))

      _ ->
        {:noreply, state}
    end
  end

  @spec handle_set_zeny(SessionState.t(), integer()) :: {:noreply, SessionState.t()}
  def handle_set_zeny(%{trade: nil} = state, _zeny), do: {:noreply, state}

  def handle_set_zeny(state, zeny)
      when is_integer(zeny) and zeny >= 0 and zeny <= state.game_state.zeny do
    forward(state, &TradeSession.set_zeny(&1, zeny))
  end

  def handle_set_zeny(state, _zeny), do: {:noreply, state}

  @spec handle_lock(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_lock(%{trade: nil} = state), do: {:noreply, state}
  def handle_lock(state), do: forward(state, &TradeSession.lock/1)

  @spec handle_confirm(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_confirm(%{trade: nil} = state), do: {:noreply, state}

  def handle_confirm(state) do
    snapshot = %{inventory: state.game_state.inventory, stats: state.game_state.stats}
    forward(state, &TradeSession.confirm(&1, snapshot))
  end

  @spec handle_cancel(SessionState.t(), atom()) :: {:noreply, SessionState.t()}
  def handle_cancel(%{trade: nil} = state, _reason), do: {:noreply, state}

  def handle_cancel(state, reason) do
    TradeSession.cancel(state.trade.pid, reason)
    {:noreply, clear_trade(state, reason)}
  end

  @spec cancel_if_trading(SessionState.t(), atom()) :: SessionState.t()
  def cancel_if_trading(%{trade: nil} = state, _reason), do: state

  def cancel_if_trading(state, reason) do
    TradeSession.cancel(state.trade.pid, reason)
    clear_trade(state, reason)
  end

  @spec handle_trade_event(SessionState.t(), term()) :: {:noreply, SessionState.t()}
  def handle_trade_event(state, {:opened, trade_pid, partner_char_id}) do
    with nil <- state.trade,
         {:ok, partner_name} <- UnitRegistry.get_player_name(partner_char_id),
         {:ok, game_state} <- PlayerState.transition_to(state.game_state, :trading) do
      monitor = Process.monitor(trade_pid)
      state = StateCommit.commit(state, game_state)

      MessageRouter.send_to(state.connection_pid, %TradeOpened{
        partner_char_id: partner_char_id,
        partner_name: partner_name
      })

      {:noreply,
       %{state | trade: %{pid: trade_pid, monitor: monitor, partner_char_id: partner_char_id}}}
    else
      _ ->
        TradeSession.cancel(trade_pid, :busy)
        {:noreply, send_cancelled(state, :busy)}
    end
  end

  def handle_trade_event(state, {:cancelled, reason}) do
    {:noreply, clear_trade(state, reason)}
  end

  def handle_trade_event(%{trade: nil} = state, {:offer_update, _view}),
    do: {:noreply, state}

  def handle_trade_event(state, {:offer_update, view}) do
    MessageRouter.send_to(state.connection_pid, %TradeOfferUpdate{
      own: encode_entries(view.own.entries, state.game_state.inventory, :own),
      partner: encode_entries(view.partner.entries, state.game_state.inventory, :partner),
      own_zeny: view.own.zeny,
      partner_zeny: view.partner.zeny,
      own_locked: view.own.locked,
      partner_locked: view.partner.locked
    })

    {:noreply, state}
  end

  def handle_trade_event(%{trade: nil} = state, {:completed, _delta}),
    do: {:noreply, state}

  def handle_trade_event(state, {:completed, delta}) do
    old_inventory = state.game_state.inventory
    notify_item_changes(state.connection_pid, old_inventory, delta.inventory, delta.item_changes)
    StatusSync.send_param(state.connection_pid, StatusParams.zeny(), delta.zeny)

    game_state = %{state.game_state | inventory: delta.inventory, zeny: delta.zeny}
    {:ok, game_state} = PlayerState.transition_to(game_state, :idle)
    state = finish_trade(state, game_state)

    MessageRouter.send_to(state.connection_pid, %TradeCompleted{})
    {:noreply, state}
  end

  @spec handle_trade_down(reference(), pid(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_trade_down(
        monitor,
        pid,
        %{trade: %{monitor: monitor, pid: pid}} = state
      ) do
    {:noreply, clear_trade(state, :disconnected)}
  end

  def handle_trade_down(_monitor, _pid, state), do: {:noreply, state}

  defp accept_invite(invite, state) do
    acceptor = %{pid: self(), char_id: state.game_state.character_id}

    case accept_request(invite.requester_pid, acceptor) do
      :ok -> {:noreply, state}
      {:error, reason} -> {:noreply, send_cancelled(state, reason)}
    end
  end

  defp decline_invite(invite, state) do
    notify_invite_cancelled(invite.requester_pid, :declined)
    {:noreply, state}
  end

  defp expire_invite(invite, state) do
    notify_invite_cancelled(invite.requester_pid, :timeout)
    {:noreply, state}
  end

  defp take_pending_invite(%{pending_trade_invite: nil}), do: :error

  defp take_pending_invite(%{pending_trade_invite: invite} = state) do
    state = %{state | pending_trade_invite: nil}

    if System.monotonic_time(:millisecond) >= invite.expires_at do
      {:expired, invite, state}
    else
      {:ok, invite, state}
    end
  end

  defp invite(state) do
    %{
      requester_char_id: state.game_state.character_id,
      requester_pid: self(),
      requester_name: state.game_state.character_name
    }
  end

  defp eligible?(%{trade: trade, pending_trade_invite: pending, game_state: game_state}) do
    with :ok <- ensure_living(game_state),
         :ok <- ensure_idle(game_state),
         :ok <- ensure_empty(trade, pending) do
      nv_basic(game_state)
    end
  end

  defp ensure_living(%PlayerState{} = game_state) do
    if Unit.living?(game_state), do: :ok, else: {:error, :dead}
  end

  defp ensure_idle(%PlayerState{action_state: :idle}), do: :ok
  defp ensure_idle(%PlayerState{}), do: {:error, :busy}

  defp ensure_empty(nil, nil), do: :ok
  defp ensure_empty(_trade, _pending), do: {:error, :busy}

  defp nv_basic(%PlayerState{stats: %{progression: %{learned_skills: learned_skills}}}) do
    case NvBasic.allows_action?(learned_skills, :trade) do
      :ok -> :ok
      {:error, _reason} -> {:error, :invalid}
    end
  end

  defp reject_self(char_id, char_id), do: {:error, :invalid}
  defp reject_self(_requester_id, _target_id), do: :ok

  defp player(char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{} = game_state, pid}} when is_pid(pid) ->
        {:ok, game_state, pid}

      _ ->
        {:error, :invalid}
    end
  end

  defp in_range?(
         %PlayerState{map_name: map, x: x, y: y},
         %PlayerState{map_name: map, x: target_x, y: target_y}
       ) do
    if Geometry.in_tile_range?(x, y, target_x, target_y, @trade_range) do
      :ok
    else
      {:error, :too_far}
    end
  end

  defp in_range?(%PlayerState{}, %PlayerState{}), do: {:error, :too_far}

  defp deliver_request(pid, invite) do
    PlayerSession.deliver_trade_request(pid, invite)
  catch
    :exit, _reason -> {:error, :busy}
  end

  defp accept_request(pid, acceptor) do
    PlayerSession.trade_accept(pid, acceptor)
  catch
    :exit, _reason -> {:error, :busy}
  end

  defp notify_invite_cancelled(pid, reason), do: send(pid, {:trade_invite_cancelled, reason})

  defp forward(state, fun) do
    case fun.(state.trade.pid) do
      :ok -> {:noreply, state}
      {:error, _reason} -> {:noreply, state}
    end
  catch
    :exit, _reason -> {:noreply, clear_trade(state, :disconnected)}
  end

  defp encode_entries(entries, inventory, side) do
    Enum.map(entries, fn %{row_id: row_id, amount: amount, snapshot: snapshot} ->
      index = if side == :own, do: client_index_for_row(inventory, row_id), else: 0
      InventoryView.trade_item(index, snapshot, amount)
    end)
  end

  defp client_index_for_row(inventory, row_id) do
    case Enum.find(inventory, fn {_index, row} -> row.id == row_id end) do
      {index, _row} -> PlayerState.client_index(index)
      nil -> 0
    end
  end

  defp notify_item_changes(connection_pid, old_inventory, inventory, changes) do
    Enum.each(changes, fn
      {:removed, index} ->
        MessageRouter.send_to(
          connection_pid,
          InventoryView.item_removed(index, PlayerState.get_by_index(old_inventory, index).amount)
        )

      {:reduced, index, left} ->
        removed = PlayerState.get_by_index(old_inventory, index).amount - left
        MessageRouter.send_to(connection_pid, InventoryView.item_removed(index, removed))

      {:added, index, _item} ->
        send_item_added(connection_pid, inventory, index)

      {:stacked, index, _total} ->
        send_item_added(connection_pid, inventory, index)

      {:split, indices} ->
        Enum.each(indices, fn {index, _amount} ->
          send_item_added(connection_pid, inventory, index)
        end)
    end)
  end

  defp send_item_added(connection_pid, inventory, index) do
    item = PlayerState.get_by_index(inventory, index)
    MessageRouter.send_to(connection_pid, InventoryView.item_added(item, index))
  end

  defp clear_trade(%{trade: nil} = state, _reason), do: state

  defp clear_trade(state, reason) do
    game_state =
      case PlayerState.transition_to(state.game_state, :idle) do
        {:ok, game_state} -> game_state
        {:error, :invalid_transition} -> state.game_state
      end

    state
    |> finish_trade(game_state)
    |> send_cancelled(reason)
  end

  defp finish_trade(%{trade: %{monitor: monitor}} = state, game_state) do
    Process.demonitor(monitor, [:flush])

    state
    |> StateCommit.commit(game_state)
    |> Map.put(:trade, nil)
  end

  defp send_cancelled(state, reason) do
    MessageRouter.send_to(state.connection_pid, %TradeCancelled{reason: cancel_reason(reason)})
    state
  end

  defp cancel_reason(:declined), do: :TRADE_CANCEL_REASON_DECLINED
  defp cancel_reason(:timeout), do: :TRADE_CANCEL_REASON_TIMEOUT
  defp cancel_reason(:cancelled), do: :TRADE_CANCEL_REASON_CANCELLED
  defp cancel_reason(:too_far), do: :TRADE_CANCEL_REASON_TOO_FAR
  defp cancel_reason(:busy), do: :TRADE_CANCEL_REASON_BUSY
  defp cancel_reason(:dead), do: :TRADE_CANCEL_REASON_DEAD
  defp cancel_reason(:disconnected), do: :TRADE_CANCEL_REASON_DISCONNECTED
  defp cancel_reason(:capacity), do: :TRADE_CANCEL_REASON_CAPACITY
  defp cancel_reason(_reason), do: :TRADE_CANCEL_REASON_INVALID
end
