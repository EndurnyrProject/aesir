defmodule Aesir.ZoneServer.Map.CoordinatorAnnouncementTest do
  @moduledoc """
  Verifies the `Coordinator` fans a global `{:announcement, packet}` it receives
  on the inter-server `servers:announce` topic to the players on its own map via
  `Announcement.deliver_local/2`.
  """

  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Net.Announcement, as: AnnouncementMsg
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Map.Coordinator

  setup :verify_on_exit!

  @map_name "coordinator_announcement_test_map"

  test "delivers a received global announcement to the map's local players" do
    test_pid = self()

    packet = %AnnouncementMsg{text: "hello", color: 0, style: :TOP, source_name: ""}

    stub(Announcement, :deliver_local, fn recv_packet, map_name ->
      send(test_pid, {:delivered, recv_packet, map_name})
      :ok
    end)

    state = %Coordinator{map_name: @map_name}

    assert {:noreply, ^state} = Coordinator.handle_info({:announcement, packet}, state)

    assert_received {:delivered, ^packet, @map_name}
  end
end
