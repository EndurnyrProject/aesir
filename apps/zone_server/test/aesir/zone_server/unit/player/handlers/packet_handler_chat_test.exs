defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerChatTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.InterServer.PubSub, as: ServerPubSub
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ChatLine
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.ChatSend
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Stands in for another player's session and forwards its casts to the test.
  defmodule MockOtherPlayerSession do
    use GenServer

    def start_link(test_pid) do
      GenServer.start_link(__MODULE__, test_pid)
    end

    @impl true
    def init(test_pid), do: {:ok, %{test_pid: test_pid}}

    @impl true
    def handle_cast(msg, %{test_pid: test_pid} = state) do
      send(test_pid, {:mock_cast_received, msg})
      {:noreply, state}
    end
  end

  setup :verify_on_exit!

  @char_id 1
  @char_name "TestChar"
  @link "￼"

  # The test process acts as the sender's connection.
  defp state_for(attrs \\ []) do
    game_state =
      struct(
        %PlayerState{
          character_id: @char_id,
          character_name: @char_name,
          visible_players: MapSet.new()
        },
        attrs
      )

    %{game_state: game_state, connection_pid: self(), connection_monitor_ref: nil}
  end

  defp say(state, attrs) do
    assert {:noreply, ^state} = PacketHandler.handle_message(struct(ChatSend, attrs), state)
  end

  defp other_player(char_id) do
    {:ok, pid} = MockOtherPlayerSession.start_link(self())
    expect(UnitRegistry, :get_player_pid, fn ^char_id -> {:ok, pid} end)
  end

  defp unique_id, do: System.unique_integer([:positive])

  defp assert_refused do
    assert_receive {:send, :world,
                    {:chat_notice, %ChatNotice{kind: :ERROR, text: "You cannot link that item."}}}

    refute_received {:send, _channel, {:chat_line, _line}}
  end

  describe "CHAT_LOCAL" do
    test "reaches the sender and the players that see it, with the name in its own field" do
      other_player(2)
      state = state_for(visible_players: MapSet.new([2]))

      say(state, channel: :CHAT_LOCAL, text: "Hello, world!")

      line = %ChatLine{
        channel: :CHAT_LOCAL,
        sender_gid: @char_id,
        sender_name: @char_name,
        text: "Hello, world!"
      }

      assert_receive {:send, :world, {:chat_line, ^line}}
      assert_receive {:mock_cast_received, {:send_packet, ^line}}
    end

    test "reaches only the sender when nobody is in view" do
      say(state_for(), channel: :CHAT_LOCAL, text: "Solo chat!")

      assert_receive {:send, :world, {:chat_line, %ChatLine{text: "Solo chat!"}}}
      refute_receive {:mock_cast_received, _}, 50
    end

    test "skips a visible player whose session is gone" do
      expect(UnitRegistry, :get_player_pid, fn 2 -> {:error, :not_found} end)

      say(state_for(visible_players: MapSet.new([2])), channel: :CHAT_LOCAL, text: "Anyone?")

      assert_receive {:send, :world, {:chat_line, %ChatLine{text: "Anyone?"}}}
    end

    test "a line starting with @ is ordinary speech, not a command" do
      say(state_for(), channel: :CHAT_LOCAL, text: "@item 501 1")

      assert_receive {:send, :world, {:chat_line, %ChatLine{text: "@item 501 1"}}}
      refute_received {:send, _channel, {:chat_notice, _notice}}
    end
  end

  describe "rejected text" do
    @describetag :capture_log

    test "drops a line over 255 bytes" do
      say(state_for(), channel: :CHAT_LOCAL, text: String.duplicate("a", 256))

      refute_receive {:send, _channel, _payload}, 50
    end

    test "delivers a line of exactly 255 bytes" do
      text = String.duplicate("a", 255)

      say(state_for(), channel: :CHAT_LOCAL, text: text)

      assert_receive {:send, :world, {:chat_line, %ChatLine{text: ^text}}}
    end

    test "drops a blank line" do
      say(state_for(), channel: :CHAT_LOCAL, text: "  \n ")

      refute_receive {:send, _channel, _payload}, 50
    end
  end

  describe "CHAT_PARTY and CHAT_GUILD" do
    test "a party line is published on the party topic" do
      party_id = unique_id()
      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{party_id}")

      say(state_for(party_id: party_id), channel: :CHAT_PARTY, text: "pull")

      assert_receive {:social,
                      {:chat_line,
                       %ChatLine{
                         channel: :CHAT_PARTY,
                         sender_gid: @char_id,
                         sender_name: @char_name,
                         text: "pull"
                       }}}

      refute_received {:send, _channel, _payload}
    end

    test "a guild line is published on the guild topic" do
      guild_id = unique_id()
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{guild_id}")

      say(state_for(guild_id: guild_id), channel: :CHAT_GUILD, text: "woe at 8")

      assert_receive {:social, {:chat_line, %ChatLine{channel: :CHAT_GUILD, text: "woe at 8"}}}
      refute_received {:send, _channel, _payload}
    end

    test "a member session forwards a published line to its own client" do
      state = state_for()
      line = %ChatLine{channel: :CHAT_PARTY, sender_gid: 2, sender_name: "Friend", text: "hi"}

      assert {:noreply, ^state} = SocialHandler.info({:chat_line, line}, state)

      assert_receive {:send, :world, {:chat_line, ^line}}
    end

    test "a sender outside a party is told so" do
      say(state_for(), channel: :CHAT_PARTY, text: "pull")

      assert_receive {:send, :world,
                      {:chat_notice, %ChatNotice{kind: :ERROR, text: "You are not in a party."}}}

      refute_received {:send, _channel, {:chat_line, _line}}
    end

    test "a sender outside a guild is told so" do
      say(state_for(), channel: :CHAT_GUILD, text: "woe at 8")

      assert_receive {:send, :world,
                      {:chat_notice, %ChatNotice{kind: :ERROR, text: "You are not in a guild."}}}

      refute_received {:send, _channel, {:chat_line, _line}}
    end
  end

  describe "CHAT_TRADE" do
    test "is published on the server-wide announcement topic" do
      ServerPubSub.subscribe_to_announcements()
      text = "S> Jellopy #{unique_id()}"

      say(state_for(), channel: :CHAT_TRADE, text: text)

      assert_receive {:announcement,
                      %ChatLine{channel: :CHAT_TRADE, sender_name: @char_name, text: ^text}}
    end
  end

  describe "CHAT_WHISPER" do
    test "reaches the named player and the sender, naming the recipient" do
      expect(UnitRegistry, :find_char_id_by_name, fn "Friend" -> {:ok, 2} end)
      other_player(2)

      say(state_for(), channel: :CHAT_WHISPER, text: "psst", whisper_to: "Friend")

      line = %ChatLine{
        channel: :CHAT_WHISPER,
        sender_gid: @char_id,
        sender_name: @char_name,
        text: "psst",
        whisper_to: "Friend"
      }

      assert_receive {:send, :world, {:chat_line, ^line}}
      assert_receive {:mock_cast_received, {:send_packet, ^line}}
    end

    test "a whisper to oneself arrives once" do
      expect(UnitRegistry, :find_char_id_by_name, fn @char_name -> {:ok, @char_id} end)
      reject(&UnitRegistry.get_player_pid/1)

      say(state_for(), channel: :CHAT_WHISPER, text: "note", whisper_to: @char_name)

      assert_receive {:send, :world, {:chat_line, %ChatLine{whisper_to: @char_name}}}
      refute_received {:send, _channel, _payload}
    end

    test "an offline recipient gets the sender a notice" do
      expect(UnitRegistry, :find_char_id_by_name, fn "Ghost" -> {:error, :not_found} end)

      say(state_for(), channel: :CHAT_WHISPER, text: "psst", whisper_to: "Ghost")

      assert_receive {:send, :world,
                      {:chat_notice, %ChatNotice{kind: :ERROR, text: "Ghost is not online."}}}

      refute_received {:send, _channel, {:chat_line, _line}}
    end
  end

  describe "item links" do
    setup do
      stub(ItemManagement, :get_item_by_id, fn _nameid -> {:error, :item_not_found} end)

      sword = %InventoryItem{
        nameid: 1201,
        amount: 4,
        identify: 1,
        refine: 7,
        equip: 2,
        favorite: 1,
        random_options: []
      }

      # Session index 0 is client index 2.
      {:ok, state: state_for(inventory: %{0 => sword})}
    end

    test "a linked item is expanded with its slot fields zeroed", %{state: state} do
      say(state, channel: :CHAT_LOCAL, text: "look #{@link}", link_indices: [2])

      assert_receive {:send, :world, {:chat_line, %ChatLine{links: [link]}}}
      assert %{nameid: 1201, refine: 7, identified: true} = link
      assert %{index: 0, amount: 0, location: 0, favorite: false} = link
    end

    test "an index that is not in the inventory is refused", %{state: state} do
      say(state, channel: :CHAT_LOCAL, text: "look #{@link}", link_indices: [9])

      assert_refused()
    end

    test "a link count that differs from the markers is refused", %{state: state} do
      say(state, channel: :CHAT_LOCAL, text: "look #{@link} #{@link}", link_indices: [2])
      assert_refused()

      say(state, channel: :CHAT_LOCAL, text: "look", link_indices: [2])
      assert_refused()
    end

    test "more than three links are refused", %{state: state} do
      text = String.duplicate(@link, 4)

      say(state, channel: :CHAT_LOCAL, text: text, link_indices: [2, 2, 2, 2])

      assert_refused()
    end
  end
end
