defmodule Aesir.ZoneServer.Content.Npc.Woe.TreasureLeverTest do
  @moduledoc """
  Covers the Task 4 treasure-room exit lever: the 20 FE castle placements
  and the pull/decline dialog driven through `Script.Interaction`.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Content.Npc.Woe.TreasureLever
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @fe_castle_maps ~w(
    aldeg_cas01 aldeg_cas02 aldeg_cas03 aldeg_cas04 aldeg_cas05
    gefg_cas01 gefg_cas02 gefg_cas03 gefg_cas04 gefg_cas05
    payg_cas01 payg_cas02 payg_cas03 payg_cas04 payg_cas05
    prtg_cas01 prtg_cas02 prtg_cas03 prtg_cas04 prtg_cas05
  )

  @cells %{
    "aldeg_cas01" => {123, 223},
    "aldeg_cas02" => {139, 234},
    "aldeg_cas03" => {229, 267},
    "aldeg_cas04" => {83, 17},
    "aldeg_cas05" => {64, 8},
    "gefg_cas01" => {152, 117},
    "gefg_cas02" => {145, 114},
    "gefg_cas03" => {275, 289},
    "gefg_cas04" => {116, 123},
    "gefg_cas05" => {149, 107},
    "payg_cas01" => {295, 8},
    "payg_cas02" => {149, 149},
    "payg_cas03" => {163, 167},
    "payg_cas04" => {151, 47},
    "payg_cas05" => {161, 136},
    "prtg_cas01" => {15, 208},
    "prtg_cas02" => {207, 228},
    "prtg_cas03" => {193, 130},
    "prtg_cas04" => {275, 160},
    "prtg_cas05" => {281, 176}
  }

  @exits %{
    "aldeg_cas01" => {218, 176},
    "aldeg_cas02" => {78, 75},
    "aldeg_cas03" => {110, 119},
    "aldeg_cas04" => {67, 117},
    "aldeg_cas05" => {51, 179},
    "gefg_cas01" => {40, 49},
    "gefg_cas02" => {12, 67},
    "gefg_cas03" => {106, 24},
    "gefg_cas04" => {73, 47},
    "gefg_cas05" => {70, 53},
    "payg_cas01" => {120, 59},
    "payg_cas02" => {22, 261},
    "payg_cas03" => {50, 261},
    "payg_cas04" => {38, 285},
    "payg_cas05" => {277, 250},
    "prtg_cas01" => {112, 183},
    "prtg_cas02" => {94, 62},
    "prtg_cas03" => {51, 101},
    "prtg_cas04" => {259, 265},
    "prtg_cas05" => {36, 38}
  }

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([TreasureLever])
    :ok
  end

  test "declares one placement per FE castle map, sprite 111, dir 0, cells matching the table" do
    placements = TreasureLever.spawn()

    assert length(placements) == 20
    assert placements |> Enum.map(& &1.map) |> Enum.sort() == Enum.sort(@fe_castle_maps)
    assert Enum.all?(placements, &(&1.sprite == 111))
    assert Enum.all?(placements, &(&1.dir == 0))
    assert Enum.all?(placements, &(&1.name == "Lever"))

    unique_names = Enum.map(placements, & &1.unique_name)
    assert Enum.uniq(unique_names) == unique_names

    for placement <- placements do
      assert placement.unique_name == "Lever##{placement.map}"
      assert {placement.x, placement.y} == Map.fetch!(@cells, placement.map)
    end
  end

  test "pulling the lever warps back to the exit cell on the same map" do
    map = "aldeg_cas01"
    gid = gid_for(map)
    ctx = build_ctx(map, gid)

    test_pid = self()

    stub(PlayerSession, :script_apply, fn _pid, op ->
      send(test_pid, {:script_apply, op})
      {:ok, %PlayerState{character_id: 1, character_name: "TestPuller", account_id: 100}}
    end)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
    assert options == ["Pull.", "Do not."]

    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    assert_receive {:DOWN, ^ref, :process, ^pid, reason}
    assert reason in [:normal, :noproc]

    {x, y} = Map.fetch!(@exits, map)
    assert_received {:script_apply, {:warp, ^map, ^x, ^y}}
  end

  test "declining the pull closes without a warp" do
    map = "prtg_cas05"
    gid = gid_for(map)
    ctx = build_ctx(map, gid)

    test_pid = self()

    stub(PlayerSession, :script_apply, fn _pid, op ->
      send(test_pid, {:script_apply, op})
      {:ok, %PlayerState{character_id: 1, character_name: "TestPuller", account_id: 100}}
    end)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 2}}})

    assert_receive {:DOWN, ^ref, :process, ^pid, reason}
    assert reason in [:normal, :noproc]

    refute_received {:script_apply, {:warp, _map, _x, _y}}
  end

  defp gid_for(map) do
    placement = Enum.find(TreasureLever.spawn(), &(&1.map == map))
    NpcRegistry.entity_id(placement)
  end

  defp start_interaction(ctx), do: Interaction.start(self(), TreasureLever, ctx)

  defp build_ctx(map, gid) do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1,
        character_name: "TestPuller",
        account_id: 100,
        map_name: map
      },
      source: {:npc, :treasure_lever_test},
      npc_gid: gid
    }
  end
end
