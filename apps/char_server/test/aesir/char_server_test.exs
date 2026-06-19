defmodule Aesir.CharServerTest do
  use ExUnit.Case, async: true
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.CharServer
  alias Aesir.CharServer.Characters
  alias Aesir.CharServer.CharacterSession
  alias Aesir.CharServer.Packets.HcAcceptEnter
  alias Aesir.CharServer.Packets.HcBlockCharacter
  alias Aesir.CharServer.Packets.HcCharacterList
  alias Aesir.CharServer.Packets.HcCharlistNotify
  alias Aesir.CharServer.Packets.HcNotifyZonesvr
  alias Aesir.CharServer.Packets.HcRefuseEnter
  alias Aesir.Commons.SessionManager

  describe "handle_packet/3 for packet 0x0065 (character list request)" do
    test "successfully handles character list request with valid session" do
      parsed_data = %{aid: 1001, login_id1: 123, login_id2: 456, sex: 0}
      session_data = %{}

      updated_session = %{account_id: 1001, authenticated: true, username: "testuser"}

      character_list = [
        %{id: 1, name: "TestChar1", level: 1},
        %{id: 2, name: "TestChar2", level: 5}
      ]

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:ok, updated_session}
      end)

      Characters
      |> stub(:list_characters, fn 1001, ^updated_session ->
        {:ok, character_list}
      end)

      assert {:ok, ^updated_session, response_packets} =
               CharServer.handle_packet(0x0065, parsed_data, session_data)

      assert length(response_packets) == 6

      # Find the HcAcceptEnter packet in the response
      assert Enum.any?(response_packets, fn packet ->
               match?(%HcAcceptEnter{characters: ^character_list}, packet)
             end)

      # HC_CHARLIST_NOTIFY (0x09A0) must follow the char list and precede the block list,
      # matching rAthena's chclif_mmo_char_send order (006B -> 09A0 -> 020D).
      char_list_idx = Enum.find_index(response_packets, &match?(%HcAcceptEnter{}, &1))
      notify_idx = Enum.find_index(response_packets, &match?(%HcCharlistNotify{}, &1))
      block_idx = Enum.find_index(response_packets, &match?(%HcBlockCharacter{}, &1))

      assert char_list_idx < notify_idx
      assert notify_idx < block_idx
    end

    test "exposes a consistent slot count across 0x082D and 0x09A0 (5 pages of 3)" do
      parsed_data = %{aid: 1001, login_id1: 123, login_id2: 456, sex: 0}
      session_data = %{}
      updated_session = %{account_id: 1001, authenticated: true, username: "testuser"}

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:ok, updated_session}
      end)

      Characters
      |> stub(:list_characters, fn 1001, ^updated_session ->
        {:ok, []}
      end)

      assert {:ok, ^updated_session, response_packets} =
               CharServer.handle_packet(0x0065, parsed_data, session_data)

      slot_config = Enum.find(response_packets, &match?(%HcCharacterList{}, &1))
      notify = Enum.find(response_packets, &match?(%HcCharlistNotify{}, &1))

      # Producible (selectable) slots and the notify page-source must agree, so the
      # client never renders fewer pages than there are usable slots.
      assert slot_config.producible_slots == slot_config.valid_slots
      assert notify.char_slots == slot_config.producible_slots

      # 15 slots -> max(15 / 3, 1) = 5 navigable pages.
      assert <<0x09A0::16-little, total::32-little>> = HcCharlistNotify.build(notify)
      assert total == 5
    end

    test "handles session validation failure" do
      parsed_data = %{aid: 1001, login_id1: 123, login_id2: 456, sex: 0}
      session_data = %{}

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:error, :session_validation_failed}
      end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data, [%HcRefuseEnter{reason: 0}]} =
                   CharServer.handle_packet(0x0065, parsed_data, session_data)
        end)

      assert log =~ "Session validation failed for account 1001: session_validation_failed"
    end

    test "handles session account mismatch" do
      parsed_data = %{aid: 1001, login_id1: 123, login_id2: 456, sex: 0}
      session_data = %{}

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:error, :session_account_mismatch}
      end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data, [%HcRefuseEnter{reason: 0}]} =
                   CharServer.handle_packet(0x0065, parsed_data, session_data)
        end)

      assert log =~ "Session validation failed for account 1001: session_account_mismatch"
    end

    test "handles character list retrieval failure" do
      parsed_data = %{aid: 1001, login_id1: 123, login_id2: 456, sex: 0}
      session_data = %{}
      updated_session = %{account_id: 1001, authenticated: true}

      CharacterSession
      |> stub(:validate_character_session, fn 1001, 123, 456, 0 ->
        {:ok, updated_session}
      end)

      Characters
      |> stub(:list_characters, fn 1001, ^updated_session ->
        {:error, :database_error}
      end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data, [%HcRefuseEnter{reason: 0}]} =
                   CharServer.handle_packet(0x0065, parsed_data, session_data)
        end)

      assert log =~ "Failed to get characters for account 1001"
    end
  end

  describe "handle_packet/3 for packet 0x0066 (character selection)" do
    test "successfully handles character selection" do
      parsed_data = %{slot: 0}
      session_data = %{account_id: 1001}

      character = %{
        id: 5,
        name: "SelectedChar",
        last_map: "prontera.gat"
      }

      updated_session = %{
        account_id: 1001,
        selected_character: character
      }

      Characters
      |> stub(:select_character, fn 1001, 0 ->
        {:ok, character}
      end)

      CharacterSession
      |> stub(:update_session_for_character_selection, fn
        ^session_data, ^character ->
          {:ok, updated_session}
      end)

      SessionManager
      |> stub(:get_servers, fn :zone_server ->
        [
          %{
            status: :online,
            player_count: 0,
            ip: {127, 0, 0, 1},
            port: 5121,
            metadata: %{
              cluster_id: "default"
            }
          }
        ]
      end)

      expected_response = %HcNotifyZonesvr{
        char_id: 5,
        map_name: "prontera.gat",
        ip: {127, 0, 0, 1},
        port: 5121
      }

      assert {:ok, ^updated_session, [^expected_response]} =
               CharServer.handle_packet(0x0066, parsed_data, session_data)
    end

    test "handles character selection failure" do
      parsed_data = %{slot: 0}
      session_data = %{account_id: 1001}

      Characters
      |> stub(:select_character, fn 1001, 0 ->
        {:error, :character_not_found}
      end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_packet(0x0066, parsed_data, session_data)
        end)

      assert log =~ "Character selection failed for slot 0: character_not_found"
    end

    test "handles session update failure during character selection" do
      parsed_data = %{slot: 0}
      session_data = %{account_id: 1001}

      character = %{id: 5, name: "TestChar"}

      Characters
      |> stub(:select_character, fn 1001, 0 ->
        {:ok, character}
      end)

      CharacterSession
      |> stub(:update_session_for_character_selection, fn
        ^session_data, ^character ->
          {:error, :session_update_failed}
      end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_packet(0x0066, parsed_data, session_data)
        end)

      assert log =~ "Character selection failed for slot 0: session_update_failed"
    end

    test "uses default port when zone server port not configured" do
      parsed_data = %{slot: 0}
      session_data = %{account_id: 1001}

      character = %{
        id: 5,
        name: "TestChar",
        last_map: "prontera.gat"
      }

      updated_session = %{account_id: 1001, selected_character: character}

      Characters
      |> stub(:select_character, fn 1001, 0 ->
        {:ok, character}
      end)

      CharacterSession
      |> stub(:update_session_for_character_selection, fn
        ^session_data, ^character ->
          {:ok, updated_session}
      end)

      SessionManager
      |> stub(:get_servers, fn :zone_server ->
        [
          %{
            status: :online,
            player_count: 0,
            ip: {127, 0, 0, 1},
            port: 5121,
            metadata: %{
              cluster_id: "default"
            }
          }
        ]
      end)

      expected_response = %HcNotifyZonesvr{
        char_id: 5,
        map_name: "prontera.gat",
        ip: {127, 0, 0, 1},
        port: 5121
      }

      assert {:ok, ^updated_session, [^expected_response]} =
               CharServer.handle_packet(0x0066, parsed_data, session_data)
    end
  end

  describe "handle_packet/3 for unknown packets" do
    test "handles unknown packet gracefully" do
      parsed_data = %{some_field: "value"}
      session_data = %{account_id: 1001}
      unknown_packet_id = 0x9999

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_packet(unknown_packet_id, parsed_data, session_data)
        end)

      assert log =~ "Unhandled packet in CharServer: 0x9999"
    end

    test "handles multiple unknown packets" do
      session_data = %{account_id: 1001}

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_packet(0x1111, %{}, session_data)

          assert {:ok, ^session_data} =
                   CharServer.handle_packet(0x2222, %{}, session_data)

          assert {:ok, ^session_data} =
                   CharServer.handle_packet(0x3333, %{}, session_data)
        end)

      assert log =~ "Unhandled packet in CharServer: 0x1111"
      assert log =~ "Unhandled packet in CharServer: 0x2222"
      assert log =~ "Unhandled packet in CharServer: 0x3333"
    end
  end

  describe "edge cases and error handling" do
    test "handles missing account_id in session_data for character selection" do
      parsed_data = %{slot: 0}
      session_data = %{}

      Characters
      |> stub(:select_character, fn nil, 0 ->
        {:error, :invalid_account}
      end)

      log =
        capture_log(fn ->
          assert {:ok, ^session_data} =
                   CharServer.handle_packet(0x0066, parsed_data, session_data)
        end)

      assert log =~ "Character selection failed for slot 0: invalid_account"
    end
  end

  # Helper functions
end
