defmodule Aesir.ZoneServer.Unit.Player.Handlers.GuildHandler do
  @moduledoc """
  Translates each `Guild*Request` into a `Guild.Manager` call and acks the
  requester with a `GuildActionResult`, mirroring
  `Aesir.ZoneServer.Unit.Player.Handlers.PartyHandler`.

  `PlayerSession` is the single writer, so every `handle_*/2` function takes and
  returns the session `state` map. Membership and position gating read the
  requester's live `guild_id`/`guild_position` fresh from the `Character` row
  (the persistence source of truth `Guild.Manager` writes through) instead of
  trusting session state; the position/permission gate is resolved against the
  live guild entry via `Guild.Permissions.can?/3`.

  ## Create + Emperium

  Guild creation validates the name via the DB unique constraint *before* the
  Emperium (item 714) is consumed, so a failed create never burns the item. The
  Emperium presence is pre-checked, `Guild.Manager.create/2` runs, and only on
  success is exactly one Emperium removed through the proven inventory-removal
  path (`InventoryOps.remove/4` + `InventoryView.item_removed/2`, the same path
  `delitem` uses). Both steps run inline in the requester's single-writer
  session, so no other writer interleaves.

  ## Pending invites

  A `GuildInviteRequest` is validated and resolved entirely in the *requester's*
  session (INVITE permission, guild-not-full, target resolution, target not
  already guilded, target online), then handed to the *invitee's* session via
  `PlayerSession.deliver_guild_invite/2` -- a synchronous call, so the
  requester's ack reflects whether the invite was accepted for delivery. Storing
  `%{guild_id, inviter_char_id, expires_at}`, sending the `GuildInviteNotify`,
  and arming the 30s expiry timer all happen inside `handle_invite_delivery/2`,
  which runs on the invitee's session; the enveloped
  `{:social, :guild_invite_expired}` timer routes through `PlayerSession`'s
  single `:social` clause into `SocialHandler.guild_invite_expired/1`, which
  clears it.
  """

  require Logger

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Net.GuildActionResult
  alias Aesir.Net.GuildCreateRequest
  alias Aesir.Net.GuildEmblemData
  alias Aesir.Net.GuildEmblemRequest
  alias Aesir.Net.GuildEmblemUploadRequest
  alias Aesir.Net.GuildExpelRequest
  alias Aesir.Net.GuildInviteNotify
  alias Aesir.Net.GuildInviteRequest
  alias Aesir.Net.GuildInviteResponse
  alias Aesir.Net.GuildLeaveRequest
  alias Aesir.Net.GuildMemberPositionRequest
  alias Aesir.Net.GuildNoticeEditRequest
  alias Aesir.Net.GuildPositionEditRequest
  alias Aesir.Net.GuildSkillUpRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.EmblemValidator
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Permissions
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @invite_ttl_ms 30_000
  @emperium_id 714

  @doc """
  Creates a guild mastered by the requester, consuming one Emperium on success.
  Requires `guild_id == 0` and an Emperium present; the item is consumed only
  after `Guild.Manager.create/2` succeeds (design "Create (with Emperium)").
  """
  @spec handle_create_request(GuildCreateRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_create_request(%GuildCreateRequest{name: name}, state) do
    case create_guild(name, state) do
      {:ok, new_state} -> ack_result(new_state, "create", :ok)
      {:error, reason} -> ack_result(state, "create", {:error, reason})
    end
  end

  defp create_guild(name, state) do
    with {:ok, requester} <- fetch_character(requester_char_id(state)),
         :ok <- require_no_guild(requester),
         :ok <- require_emperium(state),
         {:ok, guild_state} <- GuildManager.create(name, requester) do
      new_state =
        state
        |> consume_emperium()
        |> SocialHandler.attach_to_guild(guild_state)

      {:ok, new_state}
    end
  end

  @doc """
  INVITE-gated invite. Validates the requester's permission, guild capacity, and
  the target's eligibility in the requester's own session, then hands delivery
  off to the invitee's session (design "Invite").
  """
  @spec handle_invite_request(GuildInviteRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_invite_request(
        %GuildInviteRequest{target_char_id: target_char_id, target_name: target_name},
        state
      ) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id),
           {:ok, guild_state} <- require_permission(requester.guild_id, char_id, :invite),
           :ok <- require_not_full(guild_state),
           {:ok, resolved_target_id} <- resolve_target(target_char_id, target_name),
           {:ok, target} <- fetch_character(resolved_target_id),
           :ok <- require_no_guild(target),
           {:ok, target_pid} <- fetch_target_pid(resolved_target_id) do
        deliver_invite(target_pid, guild_state, requester)
      end

    ack_result(state, "invite", result)
  end

  @doc """
  The invitee's accept/decline. Accept re-validates nothing beyond consuming the
  pending invite -- `Guild.Manager.add_member/2` re-validates capacity
  atomically and joins the target at the Newbie position (design
  "Invite/Accept"). Decline (and a missing/expired invite) just clears the
  pending invite, if any.
  """
  @spec handle_invite_response(GuildInviteResponse.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_invite_response(%GuildInviteResponse{guild_id: guild_id, accept: accept}, state) do
    case take_pending_invite(state, guild_id) do
      {:ok, _invite, cleared_state} -> resolve_invite(accept, guild_id, cleared_state)
      :error -> ack_result(state, "invite_response", {:error, :not_member})
    end
  end

  @doc "Leaves the current guild; the master leaving disbands it (design \"Leave\")."
  @spec handle_leave_request(GuildLeaveRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_leave_request(%GuildLeaveRequest{}, state) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        GuildManager.remove_member(requester.guild_id, char_id)
      end

    ack_result(state, "leave", result)
  end

  @doc "EXPEL-gated removal of a member; the Manager refuses to target the master (design \"Expel\")."
  @spec handle_expel_request(GuildExpelRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_expel_request(
        %GuildExpelRequest{target_char_id: target_char_id, reason: reason},
        state
      ) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        GuildManager.expel(requester.guild_id, char_id, target_char_id, reason)
      end

    ack_result(state, "expel", result)
  end

  @doc "`:notice`-gated guild notice edit."
  @spec handle_notice_edit_request(GuildNoticeEditRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_notice_edit_request(%GuildNoticeEditRequest{subject: subject, body: body}, state) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        GuildManager.set_notice(requester.guild_id, char_id, %{subject: subject, body: body})
      end

    ack_result(state, "notice_edit", result)
  end

  @doc "`:positions`-gated edit of one non-zero position slot (index 0 protected)."
  @spec handle_position_edit_request(GuildPositionEditRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_position_edit_request(
        %GuildPositionEditRequest{
          index: index,
          name: name,
          can_invite: can_invite,
          can_expel: can_expel,
          tax: tax
        },
        state
      ) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        GuildManager.edit_position(requester.guild_id, char_id, %{
          index: index,
          name: name,
          can_invite: can_invite,
          can_expel: can_expel,
          tax: tax
        })
      end

    ack_result(state, "position_edit", result)
  end

  @doc "Master-only assignment of a member to a position slot."
  @spec handle_member_position_request(GuildMemberPositionRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_member_position_request(
        %GuildMemberPositionRequest{target_char_id: target_char_id, index: index},
        state
      ) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        GuildManager.assign_member_position(requester.guild_id, char_id, target_char_id, index)
      end

    ack_result(state, "member_position", result)
  end

  @doc """
  Master-only (`:emblem`) emblem upload. Validates the blob as a 24x24 BMP via
  `EmblemValidator.validate/1` before touching the DB, then hands it to
  `Guild.Manager.change_emblem/3` (which bumps `emblem_id`, stores the blob, and
  broadcasts `GuildEmblemChanged`). Invalid emblem -> `:GUILD_ERR_INVALID_EMBLEM`;
  a non-master -> `:GUILD_ERR_NO_PERMISSION`; neither changes the stored data.
  """
  @spec handle_emblem_upload_request(GuildEmblemUploadRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_emblem_upload_request(%GuildEmblemUploadRequest{data: data}, state) do
    char_id = requester_char_id(state)

    result =
      with :ok <- EmblemValidator.validate(data),
           {:ok, requester} <- fetch_character(char_id) do
        GuildManager.change_emblem(requester.guild_id, char_id, data)
      end

    ack_result(state, "emblem_upload", result)
  end

  @doc """
  Serves a guild's current emblem blob. Reads `emblem_data`/`emblem_id` straight
  from Postgres (works from any node, the entry need not be running) and replies
  with a `GuildEmblemData`. A missing guild or a guild without an emblem acks an
  error instead of crashing.
  """
  @spec handle_emblem_request(GuildEmblemRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_emblem_request(%GuildEmblemRequest{guild_id: guild_id}, state) do
    case Repo.get(GuildModel, guild_id) do
      %GuildModel{emblem_data: data, emblem_id: emblem_id} when is_binary(data) ->
        MessageRouter.send_to(state.connection_pid, %GuildEmblemData{
          guild_id: guild_id,
          emblem_id: emblem_id,
          data: data
        })

        {:noreply, state}

      _ ->
        ack_result(state, "emblem_request", {:error, :not_found})
    end
  end

  @doc """
  Runs on the invitee's session, invoked from `PlayerSession`'s
  `handle_call({:social, {:deliver_guild_invite, invite}}, _from, state)`: stores the
  pending invite, sends the `GuildInviteNotify`, and arms the expiry timer.
  Rejects a second invite while one is already pending and unexpired.
  """
  @spec handle_invite_delivery(map(), SessionState.t()) ::
          {:reply, :ok | {:error, :invite_pending}, SessionState.t()}
  def handle_invite_delivery(invite, state) do
    if pending_invite_active?(state) do
      {:reply, {:error, :invite_pending}, state}
    else
      Process.send_after(self(), {:social, :guild_invite_expired}, @invite_ttl_ms)

      MessageRouter.send_to(state.connection_pid, %GuildInviteNotify{
        guild_id: invite.guild_id,
        guild_name: invite.guild_name,
        inviter_name: invite.inviter_name
      })

      pending = %{
        guild_id: invite.guild_id,
        inviter_char_id: invite.inviter_char_id,
        expires_at: System.monotonic_time(:millisecond) + @invite_ttl_ms
      }

      {:reply, :ok, %{state | pending_guild_invite: pending}}
    end
  end

  defp requester_char_id(%{game_state: game_state}), do: game_state.character_id

  defp fetch_character(char_id) do
    case Repo.get(Character, char_id) do
      nil -> {:error, :not_member}
      character -> {:ok, character}
    end
  end

  defp require_no_guild(%Character{guild_id: 0}), do: :ok
  defp require_no_guild(%Character{}), do: {:error, :already_in_guild}

  defp require_emperium(%{game_state: game_state}) do
    if Inventory.held_amount(game_state.inventory, @emperium_id) >= 1 do
      :ok
    else
      {:error, :no_emperium}
    end
  end

  defp consume_emperium(%{game_state: game_state} = state) do
    index = Inventory.stackable_index(game_state.inventory, @emperium_id)

    case InventoryOps.remove(game_state.character_id, game_state.inventory, index, 1) do
      {:ok, persisted, _change} ->
        MessageRouter.send_to(state.connection_pid, InventoryView.item_removed(index, 1))
        %{state | game_state: %{game_state | inventory: persisted}}

      {:error, reason} ->
        Logger.warning(
          "Guild created but Emperium consume failed for character " <>
            "#{game_state.character_id}: #{inspect(reason)}"
        )

        state
    end
  end

  defp require_permission(0, _char_id, _action), do: {:error, :not_member}

  defp require_permission(guild_id, char_id, action) do
    case GuildManager.get(guild_id) do
      {:ok, %GuildState{} = guild_state} ->
        if Permissions.can?(guild_state, char_id, action) do
          {:ok, guild_state}
        else
          {:error, :no_permission}
        end

      {:error, :not_found} ->
        {:error, :not_member}
    end
  end

  defp require_not_full(%GuildState{} = guild_state) do
    if GuildState.full?(guild_state), do: {:error, :guild_full}, else: :ok
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

  defp deliver_invite(target_pid, %GuildState{} = guild_state, %Character{} = requester) do
    invite = %{
      guild_id: guild_state.guild_id,
      guild_name: guild_state.name,
      inviter_char_id: requester.id,
      inviter_name: requester.name
    }

    PlayerSession.deliver_guild_invite(target_pid, invite)
  end

  defp take_pending_invite(
         %{pending_guild_invite: %{guild_id: guild_id} = invite} = state,
         guild_id
       ) do
    if invite_expired?(invite) do
      :error
    else
      {:ok, invite, %{state | pending_guild_invite: nil}}
    end
  end

  defp take_pending_invite(_state, _guild_id), do: :error

  defp invite_expired?(%{expires_at: expires_at}) do
    System.monotonic_time(:millisecond) >= expires_at
  end

  defp pending_invite_active?(%{pending_guild_invite: nil}), do: false
  defp pending_invite_active?(%{pending_guild_invite: invite}), do: not invite_expired?(invite)
  defp pending_invite_active?(_state), do: false

  defp resolve_invite(false, _guild_id, state) do
    ack_result(state, "invite_response", :ok)
  end

  defp resolve_invite(true, guild_id, state) do
    result =
      with {:ok, character} <- fetch_character(requester_char_id(state)) do
        GuildManager.add_member(guild_id, character)
      end

    ack_and_attach(state, "invite_response", result)
  end

  defp ack_and_attach(state, action, {:ok, %GuildState{} = guild_state} = result) do
    state
    |> SocialHandler.attach_to_guild(guild_state)
    |> ack_result(action, result)
  end

  defp ack_and_attach(state, action, result), do: ack_result(state, action, result)

  @doc """
  The guild master spends one guild skill point (`GuildSkillUpRequest`).

  Delegates validation to `GuildManager.allocate_skill_point/3`; the refreshed
  `GuildInfo` reaches every member (including the requester) through the
  guild-updated broadcast, so the reply here is only the `GuildActionResult`.
  """
  @spec handle_skill_up_request(GuildSkillUpRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_skill_up_request(%GuildSkillUpRequest{skill_id: skill_id}, state) do
    char_id = requester_char_id(state)

    result =
      with {:ok, requester} <- fetch_character(char_id) do
        GuildManager.allocate_skill_point(requester.guild_id, char_id, skill_id)
      end

    ack_result(state, "skill_up", result)
  end

  defp ack_result(state, action, :ok), do: ack(state, action, true, :GUILD_ERR_NONE)
  defp ack_result(state, action, {:ok, _}), do: ack(state, action, true, :GUILD_ERR_NONE)

  defp ack_result(state, action, {:error, reason}) do
    ack(state, action, false, map_error(reason))
  end

  defp ack(%{connection_pid: connection_pid} = state, action, success, error) do
    MessageRouter.send_to(connection_pid, %GuildActionResult{
      action: action,
      success: success,
      error: error
    })

    {:noreply, state}
  end

  defp map_error(:name_taken), do: :GUILD_ERR_NAME_TAKEN
  defp map_error(:invalid_name), do: :GUILD_ERR_NAME_TAKEN
  defp map_error(:already_in_guild), do: :GUILD_ERR_ALREADY_IN_GUILD
  defp map_error(:no_emperium), do: :GUILD_ERR_NO_EMPERIUM
  defp map_error(:guild_full), do: :GUILD_ERR_GUILD_FULL
  defp map_error(:no_permission), do: :GUILD_ERR_NO_PERMISSION
  defp map_error(:invalid_emblem), do: :GUILD_ERR_INVALID_EMBLEM
  defp map_error(:cannot_target_master), do: :GUILD_ERR_CANNOT_TARGET_MASTER
  defp map_error(:invalid_position), do: :GUILD_ERR_INVALID_POSITION
  defp map_error(:target_offline), do: :GUILD_ERR_TARGET_OFFLINE
  defp map_error(:invite_pending), do: :GUILD_ERR_TARGET_OFFLINE
  defp map_error(:not_member), do: :GUILD_ERR_NOT_MEMBER
  defp map_error(:not_master), do: :GUILD_ERR_NO_PERMISSION
  defp map_error(:no_skill_points), do: :GUILD_ERR_NO_SKILL_POINTS
  defp map_error(:prerequisite_not_met), do: :GUILD_ERR_SKILL_REQUIREMENT
  defp map_error(:unknown_skill), do: :GUILD_ERR_SKILL_REQUIREMENT
  defp map_error(:max_level_reached), do: :GUILD_ERR_SKILL_MAXED
  defp map_error(:not_found), do: :GUILD_ERR_NOT_MEMBER

  defp map_error(other) do
    Logger.warning("Unmapped guild error reason #{inspect(other)}, defaulting to NOT_MEMBER")
    :GUILD_ERR_NOT_MEMBER
  end
end
