defmodule Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler do
  @moduledoc """
  Translates each `Party*Request` into a `Party.Manager` call and acks the
  requester with a `PartyActionResult` (design "Flows": Create, Invite, and
  every leader-only action).

  `PlayerSession` is the single writer, so every `handle_*/2` function takes
  and returns the session `state` map, mirroring `CartHandler`. Membership
  mutations need the requester's live `party_id`, which isn't on `PlayerState`
  yet (`PlayerState.party_id` lands in a later task) -- every handler here
  reads it fresh from the `Character` row (the persistence source of truth
  `Party.Manager` itself writes through) instead of trusting session state.

  ## Pending invites

  A `PartyInviteRequest` is validated and resolved entirely in the
  *requester's* session (leader check, party-not-full, target resolution,
  target not already partied), then handed to the *invitee's* session via
  `PlayerSession.deliver_party_invite/2` -- a synchronous call, so the
  requester's ack reflects whether the invite was actually accepted for
  delivery (an invitee with an unexpired pending invite already rejects a
  second one, single-writer-safe since only the invitee's own session ever
  mutates its `:pending_party_invite`). Storing
  `%{party_id, inviter_char_id, expires_at}`, sending the `PartyInviteNotify`,
  and arming the 30s expiry timer
  (`Process.send_after(self(), {:social, :party_invite_expired}, 30_000)`) all
  happen inside `handle_invite_delivery/2`, which runs on the invitee's session
  (`self()` there is the invitee's own pid) -- the enveloped timer routes
  through `PlayerSession`'s single `:social` clause into
  `SocialHandler.party_invite_expired/1`, which clears it.
  """

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.PartyActionResult
  alias Aesir.Net.PartyCreateRequest
  alias Aesir.Net.PartyInviteNotify
  alias Aesir.Net.PartyInviteRequest
  alias Aesir.Net.PartyInviteResponse
  alias Aesir.Net.PartyKickRequest
  alias Aesir.Net.PartyLeaderRequest
  alias Aesir.Net.PartyLeaveRequest
  alias Aesir.Net.PartyOptionsRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @invite_ttl_ms 30_000

  @doc "Creates a party led by the requester (design \"Create\")."
  @spec handle_create_request(PartyCreateRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_create_request(%PartyCreateRequest{name: name}, state) do
    result =
      with {:ok, requester} <- fetch_character(requester_char_id(state)),
           :ok <- require_no_party(requester) do
        PartyManager.create(name, requester)
      end

    ack_and_attach(state, "create", result)
  end

  @doc """
  Leader-only invite. Validates leadership, room, and the target's
  eligibility in the requester's own session, then hands delivery off to the
  invitee's session (design "Invite").
  """
  @spec handle_invite_request(PartyInviteRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_invite_request(
        %PartyInviteRequest{target_char_id: target_char_id, target_name: target_name},
        state
      ) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id),
           {:ok, party_state} <- require_leader(requester.party_id, char_id),
           :ok <- require_not_full(party_state),
           {:ok, resolved_target_id} <- resolve_target(target_char_id, target_name),
           {:ok, target} <- fetch_character(resolved_target_id),
           :ok <- require_no_party(target),
           {:ok, target_pid} <- fetch_target_pid(resolved_target_id) do
        deliver_invite(target_pid, party_state, requester)
      end

    ack_result(state, "invite", result)
  end

  @doc """
  The invitee's accept/decline. Accept re-validates nothing beyond consuming
  the pending invite -- `Party.Manager.add_member/2` re-validates room and the
  same-account rule atomically (design "Invite/Accept"). Decline (and a
  missing/expired invite) just clears the pending invite, if any.
  """
  @spec handle_invite_response(PartyInviteResponse.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_invite_response(%PartyInviteResponse{party_id: party_id, accept: accept}, state) do
    case take_pending_invite(state, party_id) do
      {:ok, invite, cleared_state} -> resolve_invite(accept, invite, cleared_state)
      :error -> ack_result(state, "invite_response", {:error, :not_member})
    end
  end

  @doc "Leader-only kick; works for an offline target (design \"Kick\")."
  @spec handle_kick_request(PartyKickRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_kick_request(%PartyKickRequest{target_char_id: target_char_id}, state) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        PartyManager.kick(requester.party_id, char_id, target_char_id)
      end

    ack_result(state, "kick", result)
  end

  @doc "Leader-only leadership transfer (design \"Leader transfer\")."
  @spec handle_leader_request(PartyLeaderRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_leader_request(%PartyLeaderRequest{target_char_id: target_char_id}, state) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        PartyManager.transfer_leader(requester.party_id, char_id, target_char_id)
      end

    ack_result(state, "leader", result)
  end

  @doc "Leader-only EXP and item pickup share toggles (design \"Options\")."
  @spec handle_options_request(PartyOptionsRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_options_request(
        %PartyOptionsRequest{
          exp_share: exp_share,
          item_pickup_share: item_pickup_share
        },
        state
      ) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        PartyManager.set_options(requester.party_id, char_id, exp_share, item_pickup_share)
      end

    ack_result(state, "options", result)
  end

  @doc "Leaves the current party; the leader leaving disbands it (design \"Leave\")."
  @spec handle_leave_request(PartyLeaveRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_leave_request(%PartyLeaveRequest{}, state) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        PartyManager.remove_member(requester.party_id, char_id)
      end

    ack_result(state, "leave", result)
  end

  @doc """
  Runs on the invitee's session, invoked from `PlayerSession`'s
  `handle_call({:social, {:deliver_party_invite, invite}}, _from, state)`: stores the
  pending invite, sends the `PartyInviteNotify`, and arms the expiry timer.
  Rejects a second invite while one is already pending and unexpired.
  """
  @spec handle_invite_delivery(map(), SessionState.t()) ::
          {:reply, :ok | {:error, :invite_pending}, SessionState.t()}
  def handle_invite_delivery(invite, state) do
    if pending_invite_active?(state) do
      {:reply, {:error, :invite_pending}, state}
    else
      Process.send_after(self(), {:social, :party_invite_expired}, @invite_ttl_ms)

      MessageRouter.send_to(state.connection_pid, %PartyInviteNotify{
        party_id: invite.party_id,
        party_name: invite.party_name,
        inviter_name: invite.inviter_name
      })

      pending = %{
        party_id: invite.party_id,
        inviter_char_id: invite.inviter_char_id,
        expires_at: System.monotonic_time(:millisecond) + @invite_ttl_ms
      }

      {:reply, :ok, %{state | pending_party_invite: pending}}
    end
  end

  defp requester_char_id(%{game_state: game_state}), do: game_state.character_id

  defp fetch_character(char_id) do
    case Repo.get(Character, char_id) do
      nil -> {:error, :not_member}
      character -> {:ok, character}
    end
  end

  defp require_no_party(%Character{party_id: 0}), do: :ok
  defp require_no_party(%Character{}), do: {:error, :already_in_party}

  defp require_leader(0, _char_id), do: {:error, :not_leader}

  defp require_leader(party_id, char_id) do
    case PartyManager.get(party_id) do
      {:ok, %PartyState{leader_char_id: ^char_id} = party_state} -> {:ok, party_state}
      {:ok, %PartyState{}} -> {:error, :not_leader}
      {:error, :not_found} -> {:error, :not_member}
    end
  end

  defp require_not_full(%PartyState{} = party_state) do
    if PartyState.full?(party_state), do: {:error, :party_full}, else: :ok
  end

  defp resolve_target(target_char_id, _target_name) when target_char_id != 0 do
    {:ok, target_char_id}
  end

  defp resolve_target(0, target_name) do
    case UnitRegistry.find_char_id_by_name(target_name) do
      {:ok, char_id} -> {:ok, char_id}
      {:error, :not_found} -> {:error, :target_offline}
    end
  end

  defp fetch_target_pid(char_id) do
    case UnitRegistry.get_player_pid(char_id) do
      {:ok, pid} -> {:ok, pid}
      {:error, :not_found} -> {:error, :target_offline}
    end
  end

  defp deliver_invite(target_pid, %PartyState{} = party_state, %Character{} = requester) do
    invite = %{
      party_id: party_state.party_id,
      party_name: party_state.name,
      inviter_char_id: requester.id,
      inviter_name: requester.name
    }

    PlayerSession.deliver_party_invite(target_pid, invite)
  end

  defp take_pending_invite(
         %{pending_party_invite: %{party_id: party_id} = invite} = state,
         party_id
       ) do
    if invite_expired?(invite) do
      :error
    else
      {:ok, invite, %{state | pending_party_invite: nil}}
    end
  end

  defp take_pending_invite(_state, _party_id), do: :error

  defp invite_expired?(%{expires_at: expires_at}) do
    System.monotonic_time(:millisecond) >= expires_at
  end

  defp pending_invite_active?(%{pending_party_invite: nil}), do: false
  defp pending_invite_active?(%{pending_party_invite: invite}), do: not invite_expired?(invite)
  defp pending_invite_active?(_state), do: false

  defp resolve_invite(false, _invite, state) do
    ack_result(state, "invite_response", :ok)
  end

  defp resolve_invite(true, invite, state) do
    result =
      with {:ok, character} <- fetch_character(requester_char_id(state)) do
        PartyManager.add_member(invite.party_id, character)
      end

    ack_and_attach(state, "invite_response", result)
  end

  defp ack_and_attach(state, action, {:ok, %PartyState{} = party_state} = result) do
    state
    |> SocialHandler.attach_to_party(party_state)
    |> ack_result(action, result)
  end

  defp ack_and_attach(state, action, result), do: ack_result(state, action, result)

  defp ack_result(state, action, :ok), do: ack(state, action, true, :NONE)
  defp ack_result(state, action, {:ok, _}), do: ack(state, action, true, :NONE)

  defp ack_result(state, action, {:error, reason}) do
    ack(state, action, false, map_error(reason))
  end

  defp ack(%{connection_pid: connection_pid} = state, action, success, error) do
    MessageRouter.send_to(connection_pid, %PartyActionResult{
      action: action,
      success: success,
      error: error
    })

    {:noreply, state}
  end

  defp map_error(:name_taken), do: :NAME_TAKEN
  defp map_error(:invalid_name), do: :NAME_TAKEN
  defp map_error(:already_in_party), do: :ALREADY_IN_PARTY
  defp map_error(:party_full), do: :PARTY_FULL
  defp map_error(:not_leader), do: :NOT_LEADER
  defp map_error(:level_range), do: :LEVEL_RANGE
  defp map_error(:same_account), do: :SAME_ACCOUNT
  defp map_error(:target_offline), do: :TARGET_OFFLINE
  defp map_error(:invite_pending), do: :TARGET_OFFLINE
  defp map_error(:not_member), do: :NOT_MEMBER
  defp map_error(:not_same_map), do: :NOT_SAME_MAP
  defp map_error(:not_found), do: :NOT_MEMBER

  defp map_error(other) do
    Logger.warning("Unmapped party error reason #{inspect(other)}, defaulting to NOT_MEMBER")
    :NOT_MEMBER
  end
end
