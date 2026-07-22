defmodule Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler do
  @moduledoc """
  Owns a player session's party and guild presence lifecycle: login/mid-session
  topic subscription and the initial roster snapshot, relaying live
  membership/option/notice/emblem changes to the client, and reconciling a
  character kicked/expelled or a party/guild disbanded while offline.

  `PlayerSession` routes its single `{:social, msg}` `handle_info` clause here
  through `info/2`, which discriminates the enveloped message and calls the
  matching entry point; those entry points return the GenServer-native
  `{:noreply, state}` tuple, while `attach_to_party/2`, `attach_to_guild/2`,
  `subscribe_party/1`, and `subscribe_guild/1` return the bare session map since
  they run mid-flow (from `PartyHandler`/`GuildHandler` dispatch or `init/1`),
  not as dispatch entry points.
  """

  require Logger

  alias Aesir.Net.GuildDisbanded
  alias Aesir.Net.GuildEmblemChanged
  alias Aesir.Net.PartyDisbanded
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Member, as: GuildMember
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Guild.View, as: GuildView
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member, as: PartyMember
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Party.View, as: PartyView
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.PartySync
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Phoenix.PubSub

  @doc """
  Routes a `:social`-enveloped session message to its handler. `PlayerSession`'s
  single `handle_info({:social, msg}, state)` clause delegates here; each head
  discriminates the party/guild lifecycle message and the "our party/guild vs
  stale broadcast" refinement happens in the entry points below.
  """
  @spec info(term(), SessionState.t()) :: {:noreply, SessionState.t()}
  def info({:party_updated, party_state}, state), do: party_updated(party_state, state)

  def info({:party_member_updated, party_id, member}, state),
    do: party_member_updated(party_id, member, state)

  def info({:party_disbanded, party_id, reason}, state),
    do: party_disbanded(party_id, reason, state)

  def info(:party_invite_expired, state), do: party_invite_expired(state)

  def info({:guild_updated, guild_state}, state), do: guild_updated(guild_state, state)

  def info({:guild_member_updated, guild_id, member}, state),
    do: guild_member_updated(guild_id, member, state)

  def info({:guild_disbanded, guild_id, reason}, state),
    do: guild_disbanded(guild_id, reason, state)

  def info({:guild_emblem_changed, guild_id, emblem_id}, state),
    do: guild_emblem_changed(guild_id, emblem_id, state)

  def info(:guild_invite_expired, state), do: guild_invite_expired(state)

  @doc """
  Subscribes the calling session to a party it just created or joined
  mid-session, updates `game_state.party_id`, and sends the initial
  `PartyInfo` snapshot. Must run inside the owning `PlayerSession` process
  (e.g. from `PartyHandler`, which executes inline during packet dispatch).
  Mirrors login attachment by subscribing before publishing the player's
  complete online snapshot, so the full roster reaches the client before the
  queued self-update is handled.
  """
  @spec attach_to_party(SessionState.t(), PartyState.t()) :: SessionState.t()
  def attach_to_party(%{game_state: game_state} = state, %PartyState{} = party_state) do
    PubSub.subscribe(Aesir.PubSub, "party:#{party_state.party_id}")

    state = StateCommit.commit(state, %{game_state | party_id: party_state.party_id})

    case sync_and_send_party(state, party_state.party_id) do
      {:ok, state} ->
        state

      {:error, _reason} ->
        PubSub.unsubscribe(Aesir.PubSub, "party:#{party_state.party_id}")
        reconcile_missing_party(state)
    end
  end

  @doc """
  Subscribes the calling session to a guild it just created or joined
  mid-session, updates `game_state.guild_id`, pushes the live presence snapshot
  into the (already-started) guild entry, and sends the resulting `GuildInfo`.
  Must run inside the owning `PlayerSession` process (from `GuildHandler`, which
  executes inline during packet dispatch). Mirrors `attach_to_party/2`.
  """
  @spec attach_to_guild(SessionState.t(), GuildState.t()) :: SessionState.t()
  def attach_to_guild(%{game_state: game_state} = state, %GuildState{guild_id: guild_id}) do
    PubSub.subscribe(Aesir.PubSub, "guild:#{guild_id}")

    state = StateCommit.commit(state, %{game_state | guild_id: guild_id})

    case sync_and_send_guild(state, guild_id) do
      {:ok, state} ->
        state

      {:error, _reason} ->
        PubSub.unsubscribe(Aesir.PubSub, "guild:#{guild_id}")
        reconcile_missing_guild(state)
    end
  end

  @doc """
  Joins the party's presence topic and sends the initial snapshot when the
  character is party'd at login. A missing party row or a live party that no
  longer lists this character (kicked while offline) silently resets
  `party_id` back to 0 instead of subscribing.
  """
  @spec subscribe_party(SessionState.t()) :: SessionState.t()
  def subscribe_party(%{game_state: %{party_id: 0}} = state), do: state

  def subscribe_party(%{game_state: %{party_id: party_id}} = state) do
    with {:ok, _party_state} <- PartyManager.ensure_started(party_id),
         :ok <- PubSub.subscribe(Aesir.PubSub, "party:#{party_id}"),
         {:ok, state} <- sync_and_send_party(state, party_id) do
      state
    else
      {:error, _reason} ->
        PubSub.unsubscribe(Aesir.PubSub, "party:#{party_id}")
        reconcile_missing_party(state)
    end
  end

  @doc """
  Subscribes to the guild topic and pushes an online presence snapshot for a
  character already in a guild at login (mirrors `subscribe_party/1`); a no-op
  when the player has no guild.
  """
  @spec subscribe_guild(SessionState.t()) :: SessionState.t()
  def subscribe_guild(%{game_state: %{guild_id: 0}} = state), do: state

  def subscribe_guild(%{game_state: %{guild_id: guild_id}} = state) do
    with {:ok, _guild_state} <- GuildManager.ensure_started(guild_id),
         :ok <- PubSub.subscribe(Aesir.PubSub, "guild:#{guild_id}"),
         {:ok, state} <- sync_and_send_guild(state, guild_id) do
      state
    else
      {:error, _reason} ->
        PubSub.unsubscribe(Aesir.PubSub, "guild:#{guild_id}")
        reconcile_missing_guild(state)
    end
  end

  @doc """
  A membership or option change on our own live party: relay the fresh
  `PartyInfo` snapshot. If we're no longer listed among the members (an ordinary
  kick/leave while online), unsubscribe and clear `party_id` instead so the
  topic subscription doesn't leak. A stale broadcast for a party we've already
  left is a no-op.
  """
  @spec party_updated(PartyState.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def party_updated(
        %PartyState{party_id: party_id} = party_state,
        %{game_state: %{party_id: party_id, character_id: char_id} = game_state} = state
      ) do
    if Map.has_key?(party_state.members, char_id) do
      MessageRouter.send_to(state.connection_pid, PartyView.party_info(party_state))
      {:noreply, state}
    else
      PubSub.unsubscribe(Aesir.PubSub, "party:#{party_id}")
      {:noreply, StateCommit.commit(state, %{game_state | party_id: 0})}
    end
  end

  def party_updated(%PartyState{}, state), do: {:noreply, state}

  @doc """
  Relays a single member's update for our current party; a stale update for
  another party is ignored.
  """
  @spec party_member_updated(non_neg_integer(), PartyMember.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def party_member_updated(
        party_id,
        %PartyMember{} = member,
        %{game_state: %{party_id: party_id}} = state
      ) do
    MessageRouter.send_to(state.connection_pid, PartyView.member_update(party_id, member))
    {:noreply, state}
  end

  def party_member_updated(_party_id, %PartyMember{}, state), do: {:noreply, state}

  @doc """
  Notifies the client that our party disbanded, unsubscribes, and clears
  `party_id`; a stale disband for a party we've left is ignored.
  """
  @spec party_disbanded(non_neg_integer(), String.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def party_disbanded(party_id, reason, %{game_state: %{party_id: party_id} = game_state} = state) do
    MessageRouter.send_to(state.connection_pid, %PartyDisbanded{
      party_id: party_id,
      reason: reason
    })

    PubSub.unsubscribe(Aesir.PubSub, "party:#{party_id}")
    {:noreply, StateCommit.commit(state, %{game_state | party_id: 0})}
  end

  def party_disbanded(_party_id, _reason, state), do: {:noreply, state}

  @doc "Clears the pending party invite when its expiry timer fires."
  @spec party_invite_expired(SessionState.t()) :: {:noreply, SessionState.t()}
  def party_invite_expired(state) do
    {:noreply, %{state | pending_party_invite: nil}}
  end

  @doc """
  A membership, position, or notice change on our own live guild: relay the
  fresh `GuildInfo` snapshot. If we're no longer listed among the members (an
  expel/leave while online), unsubscribe and clear `guild_id` so the topic
  subscription doesn't leak. A stale broadcast for a guild we've left is a
  no-op.
  """
  @spec guild_updated(GuildState.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def guild_updated(
        %GuildState{guild_id: guild_id} = guild_state,
        %{game_state: %{guild_id: guild_id, character_id: char_id} = game_state} = state
      ) do
    if Map.has_key?(guild_state.members, char_id) do
      MessageRouter.send_to(state.connection_pid, GuildView.guild_info(guild_state))
      {:noreply, state}
    else
      PubSub.unsubscribe(Aesir.PubSub, "guild:#{guild_id}")
      {:noreply, StateCommit.commit(state, %{game_state | guild_id: 0})}
    end
  end

  def guild_updated(%GuildState{}, state), do: {:noreply, state}

  @doc """
  Relays a single member's update for our current guild; a stale update for
  another guild is ignored.
  """
  @spec guild_member_updated(non_neg_integer(), GuildMember.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def guild_member_updated(
        guild_id,
        %GuildMember{} = member,
        %{game_state: %{guild_id: guild_id}} = state
      ) do
    MessageRouter.send_to(state.connection_pid, GuildView.member_update(guild_id, member))
    {:noreply, state}
  end

  def guild_member_updated(_guild_id, %GuildMember{}, state), do: {:noreply, state}

  @doc """
  Notifies the client that our guild disbanded, unsubscribes, and clears
  `guild_id`; a stale disband for a guild we've left is ignored.
  """
  @spec guild_disbanded(non_neg_integer(), String.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def guild_disbanded(guild_id, reason, %{game_state: %{guild_id: guild_id} = game_state} = state) do
    MessageRouter.send_to(state.connection_pid, %GuildDisbanded{
      guild_id: guild_id,
      reason: reason
    })

    PubSub.unsubscribe(Aesir.PubSub, "guild:#{guild_id}")
    {:noreply, StateCommit.commit(state, %{game_state | guild_id: 0})}
  end

  def guild_disbanded(_guild_id, _reason, state), do: {:noreply, state}

  @doc """
  Relays a guild emblem change to our client; a stale change for a guild we've
  left is ignored.
  """
  @spec guild_emblem_changed(non_neg_integer(), non_neg_integer(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def guild_emblem_changed(guild_id, emblem_id, %{game_state: %{guild_id: guild_id}} = state) do
    MessageRouter.send_to(state.connection_pid, %GuildEmblemChanged{
      guild_id: guild_id,
      emblem_id: emblem_id
    })

    {:noreply, state}
  end

  def guild_emblem_changed(_guild_id, _emblem_id, state), do: {:noreply, state}

  @doc "Clears the pending guild invite when its expiry timer fires."
  @spec guild_invite_expired(SessionState.t()) :: {:noreply, SessionState.t()}
  def guild_invite_expired(state) do
    {:noreply, %{state | pending_guild_invite: nil}}
  end

  defp sync_and_send_party(%{game_state: game_state} = state, party_id) do
    case PartySync.sync(game_state, online: true) do
      :ok ->
        send_current_party(state, party_id)

      {:error, reason} when reason in [:not_member, :not_found] ->
        {:error, reason}

      {:error, reason} ->
        Logger.warning(
          "Failed to synchronize party state for character #{game_state.character_id}: #{inspect(reason)}"
        )

        send_current_party(state, party_id)
    end
  end

  defp send_current_party(state, party_id) do
    case PartyManager.get(party_id) do
      {:ok, party_state} ->
        MessageRouter.send_to(state.connection_pid, PartyView.party_info(party_state))
        {:ok, state}

      {:error, _reason} = error ->
        error
    end
  end

  defp sync_and_send_guild(%{game_state: game_state} = state, guild_id) do
    case GuildSync.sync(game_state, online: true) do
      :ok ->
        {:ok, send_current_guild(state, guild_id)}

      {:error, reason} when reason in [:not_member, :not_found] ->
        {:error, reason}

      {:error, reason} ->
        Logger.warning(
          "Failed to synchronize guild state for character #{game_state.character_id}: #{inspect(reason)}"
        )

        {:ok, send_current_guild(state, guild_id)}
    end
  end

  defp send_current_guild(state, guild_id) do
    case GuildManager.get(guild_id) do
      {:ok, guild_state} ->
        MessageRouter.send_to(state.connection_pid, GuildView.guild_info(guild_state))
        state

      {:error, _reason} ->
        state
    end
  end

  # Kicked-while-offline reconciliation: the party row is gone, or the
  # character no longer appears in a still-live party's member list. Silent
  # per design -- no ack, just a fire-and-forget persist.
  defp reconcile_missing_party(%{game_state: game_state} = state) do
    CharacterPersistence.update_character(game_state.character_id, %{party_id: 0}, async: true)
    StateCommit.commit(state, %{game_state | party_id: 0})
  end

  # Guild disbanded while the character was offline: the guild entry can no
  # longer be rebuilt, so silently reset `guild_id` back to 0 (mirrors
  # `reconcile_missing_party`).
  defp reconcile_missing_guild(%{game_state: game_state} = state) do
    CharacterPersistence.update_character(game_state.character_id, %{guild_id: 0}, async: true)
    StateCommit.commit(state, %{game_state | guild_id: 0})
  end
end
