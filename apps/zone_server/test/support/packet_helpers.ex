defmodule Aesir.ZoneServer.PacketHelpers do
  @moduledoc """
  Helper functions for simulating packet communication in integration tests.
  Provides utilities to simulate incoming packets from clients and
  verify outgoing packets to clients.
  """

  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @doc """
  Simulates an incoming packet from a client by sending it directly
  to a PlayerSession process.

  ## Parameters
  - player_pid: The PlayerSession process ID
  - packet_id: The packet ID (e.g., 0x007D)
  - packet_data: The parsed packet data

  ## Examples

      simulate_incoming_packet(player_pid, 0x007D, %{})

      simulate_incoming_packet(player_pid, 0x0089, %{
        dest_x: 100,
        dest_y: 100
      })
  """
  def simulate_incoming_packet(player_pid, packet_id, packet_data) when is_pid(player_pid) do
    # Send the packet directly to the PlayerSession process
    # This mimics what would happen when a packet arrives from the network
    send(player_pid, {:packet, packet_id, packet_data})
  end

  @doc """
  Simulates a player requesting to move.

  ## Examples

      simulate_move_request(player_pid, 150, 150)
  """
  def simulate_move_request(player_pid, dest_x, dest_y) do
    PlayerSession.request_move(player_pid, dest_x, dest_y)
  end

  @doc """
  Simulates a player attack action.

  ## Examples

      simulate_attack_action(player_pid, target_id, action)
  """
  def simulate_attack_action(player_pid, target_id, action \\ 0) do
    # CZ_REQUEST_ACT packet (0x0089) with action type 0 (attack)
    packet_data = %{
      target_gid: target_id,
      action: action
    }

    simulate_incoming_packet(player_pid, 0x0089, packet_data)
  end

  @doc """
  Waits for and returns all packets of a specific type sent within a timeout period.
  Useful for collecting multiple packets of the same type.

  ## Examples

      damage_packets = collect_packets_of_type(ZcNotifyActentry, 500)
      assert length(damage_packets) == 3
  """
  def collect_packets_of_type(packet_type, timeout \\ 100) do
    collect_packets_of_type_impl(packet_type, timeout, [])
  end

  defp collect_packets_of_type_impl(packet_type, timeout, acc) do
    receive do
      {:packet_sent, %{__struct__: ^packet_type} = packet, _binary} ->
        collect_packets_of_type_impl(packet_type, timeout, [packet | acc])
    after
      timeout -> Enum.reverse(acc)
    end
  end

  @doc """
  Clears all pending packet messages from the test process mailbox.
  Useful for test cleanup or when you want to ignore previous packets.

  ## Examples

      clear_packet_inbox()
  """
  def clear_packet_inbox do
    receive do
      {:packet_sent, _, _} -> clear_packet_inbox()
    after
      0 -> :ok
    end
  end

  @doc """
  Asserts that a packet sequence was sent in the correct order.

  ## Examples

      assert_packet_sequence([
        ZcNotifyMoveentry,
        ZcNotifyActentry,
        ZcStatusChange
      ])
  """
  def assert_packet_sequence(expected_types, timeout \\ 100) do
    Enum.each(expected_types, fn expected_type ->
      receive do
        {:packet_sent, %{__struct__: ^expected_type}, _binary} -> :ok
      after
        timeout ->
          raise "Expected packet type #{inspect(expected_type)} not received within #{timeout}ms"
      end
    end)
  end

  @doc """
  Simulates multiple incoming packets in sequence.
  Useful for testing multi-step interactions.

  ## Examples

      simulate_packet_sequence(player_pid, [
        {0x007D, %{}},  # LoadEndAck
        {0x0089, %{dest_x: 100, dest_y: 100}},  # Move request
        {0x0089, %{target_gid: mob_id, action: 0}}  # Attack request
      ])
  """
  def simulate_packet_sequence(player_pid, packet_list) when is_list(packet_list) do
    Enum.each(packet_list, fn {packet_id, packet_data} ->
      simulate_incoming_packet(player_pid, packet_id, packet_data)
      # Small delay to ensure proper ordering
      Process.sleep(10)
    end)
  end

  @doc """
  Gets a packet that was sent and matches a predicate function.

  ## Examples

      packet = find_sent_packet(fn p ->
        match?(%ZcNotifyActentry{target_id: ^target_id}, p)
      end)
  """
  def find_sent_packet(predicate_fn, timeout \\ 100) when is_function(predicate_fn, 1) do
    receive do
      {:packet_sent, packet, _binary} ->
        if predicate_fn.(packet) do
          packet
        else
          find_sent_packet(predicate_fn, timeout)
        end
    after
      timeout -> nil
    end
  end

  @doc """
  Waits for any packet to be sent and returns it.

  ## Examples

      packet = wait_for_any_packet()
      IO.inspect(packet)
  """
  def wait_for_any_packet(timeout \\ 100) do
    receive do
      {:packet_sent, packet, _binary} -> packet
    after
      timeout -> nil
    end
  end

  @doc """
  Counts how many packets of a specific type were sent.

  ## Examples

      count = count_packets_sent(ZcNotifyActentry, 500)
      assert count == 3
  """
  def count_packets_sent(packet_type, timeout \\ 100) do
    packets = collect_packets_of_type(packet_type, timeout)
    length(packets)
  end
end
