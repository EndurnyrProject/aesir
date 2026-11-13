defmodule Aesir.ZoneServer.Unit.Player.Handlers.ChatHandler do
  @moduledoc """
  Handles player speech on the five chat channels.

  The client sends the words only; the server knows who is speaking and stamps
  the sender on the `ChatLine` it delivers. A line is checked in this order:
  length and blankness, the sender's mute status, then its item links. A line
  that passes is delivered by channel:

  - `CHAT_LOCAL`: the sender and every player that sees it.
  - `CHAT_PARTY` / `CHAT_GUILD`: the party or guild PubSub topic every member
    session, the sender included, is subscribed to.
  - `CHAT_TRADE`: the inter-server announcement topic, which every map
    coordinator fans out to its players, the sender included.
  - `CHAT_WHISPER`: the named player and the sender.

  Refusals the player should see come back as an error `ChatNotice`. GM commands
  are not chat: they arrive as their own `GmCommand` message.
  """

  require Logger

  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Net.ChatLine
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.ChatSend
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @chat_max_size 255
  @max_links 3
  # U+FFFC, the placeholder the client puts in the text where a link is shown.
  @link_marker "￼"

  @doc """
  Processes one `ChatSend`. Rejected lines are dropped; the state never changes.

  A muted sender is dropped without a reply on every channel, as rAthena's
  `clif_process_message` does for global, whisper, party and guild messages.
  """
  @spec handle_chat(ChatSend.t(), map()) :: {:noreply, map()}
  def handle_chat(%ChatSend{text: text} = msg, %{game_state: game_state} = state) do
    cond do
      byte_size(text) > @chat_max_size or String.trim(text) == "" ->
        Logger.warning(
          "Player #{game_state.character_id} sent a blank or oversized chat message."
        )

      not Interpreter.can_chat?(:player, game_state.character_id) ->
        Logger.debug("Chat blocked by status for player #{game_state.character_id}")

      true ->
        say(msg, state)
    end

    {:noreply, state}
  end

  defp say(%ChatSend{} = msg, %{game_state: game_state} = state) do
    case links(msg, game_state.inventory) do
      {:ok, links} ->
        packet = %ChatLine{
          channel: msg.channel,
          sender_gid: game_state.character_id,
          sender_name: game_state.character_name,
          text: msg.text,
          links: links
        }

        deliver(msg.channel, packet, msg, state)

      :error ->
        refuse(state, "You cannot link that item.")
    end
  end

  defp links(%ChatSend{link_indices: indices}, _inventory) when length(indices) > @max_links,
    do: :error

  # `link_indices` are client inventory indices, the same space as
  # `InventoryItem.index`.
  defp links(%ChatSend{text: text, link_indices: indices}, inventory) do
    markers = length(String.split(text, @link_marker)) - 1
    items = Enum.map(indices, &PlayerState.get_by_index(inventory, PlayerState.server_index(&1)))

    if length(indices) == markers and nil not in items do
      {:ok, Enum.map(items, &InventoryView.chat_link/1)}
    else
      :error
    end
  end

  defp deliver(:CHAT_LOCAL, packet, _msg, %{game_state: game_state} = state) do
    MessageRouter.send_to(state.connection_pid, packet)
    Broadcast.to_visible_players(game_state, packet, exclude_id: game_state.character_id)
  end

  defp deliver(:CHAT_PARTY, _packet, _msg, %{game_state: %{party_id: 0}} = state),
    do: refuse(state, "You are not in a party.")

  defp deliver(:CHAT_PARTY, packet, _msg, %{game_state: %{party_id: party_id}}),
    do: PubSub.broadcast(Aesir.PubSub, "party:#{party_id}", {:social, {:chat_line, packet}})

  defp deliver(:CHAT_GUILD, _packet, _msg, %{game_state: %{guild_id: 0}} = state),
    do: refuse(state, "You are not in a guild.")

  defp deliver(:CHAT_GUILD, packet, _msg, %{game_state: %{guild_id: guild_id}}),
    do: PubSub.broadcast(Aesir.PubSub, "guild:#{guild_id}", {:social, {:chat_line, packet}})

  defp deliver(:CHAT_TRADE, packet, _msg, _state), do: ServerPubSub.broadcast_announcement(packet)

  defp deliver(:CHAT_WHISPER, packet, %ChatSend{whisper_to: name}, state) do
    # NOTE: whispers resolve on this node only, look the name up cluster-wide once a second zone node runs
    case UnitRegistry.find_char_id_by_name(name) do
      {:ok, target_id} ->
        packet = %{packet | whisper_to: name}
        MessageRouter.send_to(state.connection_pid, packet)
        if target_id != state.game_state.character_id, do: Broadcast.to_player(target_id, packet)

      {:error, :not_found} ->
        refuse(state, "#{name} is not online.")
    end
  end

  defp deliver(channel, _packet, _msg, %{game_state: game_state}) do
    Logger.warning(
      "Player #{game_state.character_id} sent chat on unknown channel #{inspect(channel)}."
    )
  end

  defp refuse(state, text),
    do: MessageRouter.send_to(state.connection_pid, %ChatNotice{kind: :ERROR, text: text})
end
