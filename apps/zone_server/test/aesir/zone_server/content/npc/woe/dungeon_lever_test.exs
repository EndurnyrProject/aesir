defmodule Aesir.ZoneServer.Content.Npc.Woe.DungeonLeverTest do
  @moduledoc """
  Covers the Task 4 guild dungeon lever: the 20 FE castle placements and the
  unowned/owner-member/non-member dialog paths driven through
  `Script.Interaction`.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Content.Npc.Woe.DungeonLever
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
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
    "aldeg_cas01" => {211, 181},
    "aldeg_cas02" => {194, 136},
    "aldeg_cas03" => {200, 177},
    "aldeg_cas04" => {76, 64},
    "aldeg_cas05" => {22, 205},
    "gefg_cas01" => {78, 84},
    "gefg_cas02" => {167, 40},
    "gefg_cas03" => {221, 43},
    "gefg_cas04" => {58, 75},
    "gefg_cas05" => {65, 22},
    "payg_cas01" => {101, 25},
    "payg_cas02" => {278, 247},
    "payg_cas03" => {38, 42},
    "payg_cas04" => {52, 48},
    "payg_cas05" => {249, 15},
    "prtg_cas01" => {94, 200},
    "prtg_cas02" => {84, 72},
    "prtg_cas03" => {5, 70},
    "prtg_cas04" => {56, 283},
    "prtg_cas05" => {212, 95}
  }

  @dungeons %{
    "aldeg_cas01" => {"gld_dun02", 32, 122},
    "aldeg_cas02" => {"gld_dun02", 79, 30},
    "aldeg_cas03" => {"gld_dun02", 165, 38},
    "aldeg_cas04" => {"gld_dun02", 160, 148},
    "aldeg_cas05" => {"gld_dun02", 103, 169},
    "gefg_cas01" => {"gld_dun04", 39, 258},
    "gefg_cas02" => {"gld_dun04", 125, 270},
    "gefg_cas03" => {"gld_dun04", 268, 251},
    "gefg_cas04" => {"gld_dun04", 268, 108},
    "gefg_cas05" => {"gld_dun04", 230, 35},
    "payg_cas01" => {"gld_dun01", 186, 165},
    "payg_cas02" => {"gld_dun01", 54, 165},
    "payg_cas03" => {"gld_dun01", 54, 39},
    "payg_cas04" => {"gld_dun01", 186, 39},
    "payg_cas05" => {"gld_dun01", 223, 202},
    "prtg_cas01" => {"gld_dun03", 28, 251},
    "prtg_cas02" => {"gld_dun03", 164, 268},
    "prtg_cas03" => {"gld_dun03", 164, 179},
    "prtg_cas04" => {"gld_dun03", 268, 203},
    "prtg_cas05" => {"gld_dun03", 199, 28}
  }

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([DungeonLever])
    :ok
  end

  test "declares one placement per FE castle map, sprite 111, dir 0, cells matching the table" do
    placements = DungeonLever.spawn()

    assert length(placements) == 20
    assert placements |> Enum.map(& &1.map) |> Enum.sort() == Enum.sort(@fe_castle_maps)
    assert Enum.all?(placements, &(&1.sprite == 111))
    assert Enum.all?(placements, &(&1.dir == 0))
    assert Enum.all?(placements, &(&1.name == "Dungeon Lever"))

    unique_names = Enum.map(placements, & &1.unique_name)
    assert Enum.uniq(unique_names) == unique_names

    for placement <- placements do
      assert placement.unique_name == "Dungeon Lever##{placement.map}"
      assert {placement.x, placement.y} == Map.fetch!(@cells, placement.map)
    end
  end

  test "an unowned castle ends after one dialog, no select" do
    castle = first_castle()
    gid = gid_for(castle.map)
    ctx = build_ctx(castle.map, gid)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "another ordeal"
    assert_clean_exit(ref, pid)
  end

  test "an owning member's pull warps to the dungeon map and cell" do
    castle = first_castle()
    gid = gid_for(castle.map)
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    test_pid = self()

    stub(PlayerSession, :script_apply, fn _pid, op ->
      send(test_pid, {:script_apply, op})
      {:ok, %PlayerState{character_id: 1, character_name: "TestMember", account_id: 100}}
    end)

    ctx = build_ctx(castle.map, gid, char_id: 1, guild_id: 5)
    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    continue(pid, gid)
    continue(pid, gid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
    assert options == ["Pull.", "Don't pull."]

    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    assert_clean_exit(ref, pid)

    {dungeon_map, x, y} = Map.fetch!(@dungeons, castle.map)
    assert_received {:script_apply, {:warp, ^dungeon_map, ^x, ^y}}
  end

  test "a non-owner's pull is told nothing happened, no warp" do
    castle = first_castle()
    gid = gid_for(castle.map)
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    ctx = build_ctx(castle.map, gid, char_id: 2)
    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    continue(pid, gid)
    continue(pid, gid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "Nothing happened."
    assert_clean_exit(ref, pid)

    refute_received {:script_apply, {:warp, _map, _x, _y}}
  end

  test "declining the pull closes without a warp" do
    castle = first_castle()
    gid = gid_for(castle.map)
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    ctx = build_ctx(castle.map, gid, char_id: 1, guild_id: 5)
    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    continue(pid, gid)
    continue(pid, gid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 2}}})

    assert_clean_exit(ref, pid)
    refute_received {:script_apply, {:warp, _map, _x, _y}}
  end

  defp continue(pid, gid) do
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})
  end

  defp first_castle, do: CastleDb.all() |> hd()

  defp gid_for(map) do
    placement = Enum.find(DungeonLever.spawn(), &(&1.map == map))
    NpcRegistry.entity_id(placement)
  end

  defp row(guild_id, overrides \\ %{}) do
    Map.merge(
      %{
        guild_id: guild_id,
        economy: 0,
        defense: 0,
        invested_economy: 0,
        invested_defense: 0,
        guardians: []
      },
      overrides
    )
  end

  defp assert_clean_exit(ref, pid) do
    assert_receive {:DOWN, ^ref, :process, ^pid, reason}, 500
    assert reason in [:normal, :noproc]
  end

  defp start_interaction(ctx), do: Interaction.start(self(), DungeonLever, ctx)

  defp build_ctx(map, gid, opts \\ []) do
    %Ctx{
      char_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: Keyword.get(opts, :char_id, 1),
        character_name: "TestPuller",
        account_id: 100,
        map_name: map,
        guild_id: Keyword.get(opts, :guild_id, 0)
      },
      source: {:npc, :dungeon_lever_test},
      npc_gid: gid
    }
  end
end
