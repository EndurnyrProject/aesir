defmodule Aesir.ZoneServer.Unit.Player.Handlers.TradeHandler do
  @moduledoc """
  Owns the player-session side of trade invitations and accepted trade lifecycle events.
  """

  alias Aesir.Net.TradeCancelled
  alias Aesir.Net.TradeOpened
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.TradeRequestReceived
  alias Aesir.Net.TradeResponse
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skills.Novice.NvBasic
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
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

  def handle_trade_event(state, {:offer_update, _view}), do: {:noreply, state}

  # Task 11 makes completion reachable and applies its inventory delta.
  def handle_trade_event(state, {:completed, _delta}), do: {:noreply, state}

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

  defp clear_trade(%{trade: nil} = state, _reason), do: state

  defp clear_trade(%{trade: %{monitor: monitor}} = state, reason) do
    Process.demonitor(monitor, [:flush])

    game_state =
      case PlayerState.transition_to(state.game_state, :idle) do
        {:ok, game_state} -> game_state
        {:error, :invalid_transition} -> state.game_state
      end

    state
    |> StateCommit.commit(game_state)
    |> Map.put(:trade, nil)
    |> send_cancelled(reason)
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
