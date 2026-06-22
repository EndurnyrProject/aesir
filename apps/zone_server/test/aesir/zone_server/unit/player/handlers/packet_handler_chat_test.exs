defmodule Aesir.ZoneServer.Unit.Player.Handlers.PacketHandlerChatTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.ChatRequest
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  # Define a simple mock GenServer module for other player sessions
  defmodule MockOtherPlayerSession do
    use GenServer

    def start_link(test_pid) do
      GenServer.start_link(__MODULE__, test_pid)
    end

    @impl true
    def init(test_pid), do: {:ok, %{test_pid: test_pid}}

    @impl true
    def handle_cast(msg, %{test_pid: test_pid} = state) do
      # Forward to the test process's mailbox for assertion
      send(test_pid, {:mock_cast_received, msg})
      {:noreply, state}
    end
  end

  setup :verify_on_exit!

  @test_char_id 1
  @test_account_id 1
  @test_char_name "TestChar"
  @test_map "test_map"
  @test_x 100
  @test_y 100

  defp setup_player_state(visible_players \\ MapSet.new()) do
    character = %Character{
      id: @test_char_id,
      account_id: @test_account_id,
      name: @test_char_name,
      base_level: 1,
      job_level: 1,
      class: 1,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      max_hp: 100,
      hp: 100,
      max_sp: 100,
      sp: 100,
      status_point: 0,
      skill_point: 0,
      option: 0,
      karma: 0,
      manner: 0,
      party_id: 0,
      guild_id: 0,
      pet_id: 0,
      homun_id: 0,
      elemental_id: 0,
      hair: 0,
      hair_color: 0,
      clothes_color: 0,
      weapon: 0,
      shield: 0,
      head_top: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      last_map: @test_map,
      last_x: @test_x,
      last_y: @test_y,
      save_map: @test_map,
      save_x: @test_x,
      save_y: @test_y,
      partner_id: 0,
      online: 0,
      father: 0,
      mother: 0,
      child: 0,
      fame: 0,
      rename: 0,
      delete_date: nil,
      moves: 0,
      unban_time: nil,
      font: 0,
      uniqueitem_counter: 0,
      hotkey_rowshift: 0,
      clan_id: 0,
      last_login: nil,
      title_id: 0,
      show_equip: 0
    }

    # Initialize PlayerState using the new/1 function and then update visible_players
    game_state = PlayerState.new(character)
    game_state = %{game_state | visible_players: visible_players}

    # The test process itself will act as the connection_pid
    connection_pid = self()

    # Construct the full PlayerSession state map
    %{
      character: character,
      game_state: game_state,
      connection_pid: connection_pid,
      # Not directly used by PacketHandler for chat, so nil is fine
      connection_monitor_ref: nil
    }
  end

  describe "handle_message/2 for ChatRequest" do
    test "broadcasts message to self and visible players for a valid message" do
      other_player_char_id = 2
      # Start a real mock GenServer for the other player's session, passing the test PID
      {:ok, other_player_session_pid} = MockOtherPlayerSession.start_link(self())
      visible_players = MapSet.new([other_player_char_id])

      state = setup_player_state(visible_players)
      message_content = "Hello, world!"
      full_message = "#{@test_char_name} : #{message_content}"
      packet_data = %ChatRequest{message: full_message}

      # Mock UnitRegistry to return the real mock PID
      expect(UnitRegistry, :get_player_pid, 1, fn ^other_player_char_id ->
        {:ok, other_player_session_pid}
      end)

      {:noreply, ^state} = PacketHandler.handle_message(packet_data, state)

      # Self (connection_pid) receives the proto push on the World channel.
      assert_receive {:send, :world,
                      {:chat_message, %ChatMessage{gid: @test_char_id, message: ^full_message}}}

      # The other player's session receives the broadcast cast (PlayerSession.send_packet).
      assert_receive {:mock_cast_received,
                      {:send_packet, %ChatMessage{gid: @test_char_id, message: ^full_message}}}
    end

    @tag :capture_log
    test "does not broadcast if message length exceeds maximum" do
      state = setup_player_state()
      # 256 bytes, exceeds 255 for actual content + null
      long_message = String.duplicate("a", 256)
      full_message = "#{@test_char_name} : #{long_message}"
      packet_data = %ChatRequest{message: full_message}

      {:noreply, ^state} = PacketHandler.handle_message(packet_data, state)
      refute_receive {:send, _channel, _payload}
    end

    @tag :capture_log
    test "does not broadcast if message does not start with correct prefix" do
      state = setup_player_state()
      malformed_message = "Someone else : Hello!"
      packet_data = %ChatRequest{message: malformed_message}

      {:noreply, ^state} = PacketHandler.handle_message(packet_data, state)
      refute_receive {:send, _channel, _payload}
    end

    test "only broadcasts to self if no other players are visible" do
      # No visible players in setup_player_state default
      state = setup_player_state()
      message_content = "Solo chat!"
      full_message = "#{@test_char_name} : #{message_content}"
      packet_data = %ChatRequest{message: full_message}

      {:noreply, ^state} = PacketHandler.handle_message(packet_data, state)

      assert_receive {:send, :world,
                      {:chat_message, %ChatMessage{gid: @test_char_id, message: ^full_message}}}

      refute_receive {:mock_cast_received, _}
    end

    test "routes an @-prefixed message to the GM dispatcher without broadcasting" do
      other_player_char_id = 2
      visible_players = MapSet.new([other_player_char_id])

      state = setup_player_state(visible_players)
      full_message = "#{@test_char_name} : @nope 1 2"
      packet_data = %ChatRequest{message: full_message}

      {:noreply, ^state} = PacketHandler.handle_message(packet_data, state)

      # The dispatcher replies privately (unknown command), addressed to the GM.
      assert_receive {:send, :world,
                      {:chat_message,
                       %ChatMessage{gid: @test_char_id, message: "Unknown command"}}}

      # The raw command is never echoed/broadcast to visible players.
      refute_receive {:send, :world, {:chat_message, %ChatMessage{message: ^full_message}}}
    end

    test "handles visible player not found gracefully" do
      other_player_char_id = 2
      visible_players = MapSet.new([other_player_char_id])

      state = setup_player_state(visible_players)
      message_content = "Hello, world!"
      full_message = "#{@test_char_name} : #{message_content}"
      packet_data = %ChatRequest{message: full_message}

      # Mock UnitRegistry to return error for other player's PID
      expect(UnitRegistry, :get_player_pid, 1, fn ^other_player_char_id ->
        {:error, :not_found}
      end)

      {:noreply, ^state} = PacketHandler.handle_message(packet_data, state)

      assert_receive {:send, :world,
                      {:chat_message, %ChatMessage{gid: @test_char_id, message: ^full_message}}}

      # Should not send to the other player
      refute_receive {:mock_cast_received, _}
    end
  end
end
