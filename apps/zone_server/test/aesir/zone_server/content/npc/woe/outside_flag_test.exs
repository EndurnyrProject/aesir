defmodule Aesir.ZoneServer.Content.Npc.Woe.OutsideFlagTest do
  @moduledoc """
  Covers the Task 5 outside castle flags: the 72 field-map placements and
  the unowned/other-guild/owner-member dialog paths driven through
  `Script.Interaction`.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.ZoneServer.Content.Npc.Woe.FlagOwner
  alias Aesir.ZoneServer.Content.Npc.Woe.InsideFlag
  alias Aesir.ZoneServer.Content.Npc.Woe.OutsideFlag
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Verifier, as: NpcVerifier
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @per_castle %{
    "aldeg_cas01" => 4,
    "aldeg_cas02" => 2,
    "aldeg_cas03" => 2,
    "aldeg_cas04" => 2,
    "aldeg_cas05" => 2,
    "gefg_cas01" => 4,
    "gefg_cas02" => 4,
    "gefg_cas03" => 6,
    "gefg_cas04" => 2,
    "gefg_cas05" => 4,
    "payg_cas01" => 4,
    "payg_cas02" => 4,
    "payg_cas03" => 4,
    "payg_cas04" => 4,
    "payg_cas05" => 4,
    "prtg_cas01" => 4,
    "prtg_cas02" => 4,
    "prtg_cas03" => 4,
    "prtg_cas04" => 4,
    "prtg_cas05" => 4
  }

  @entries %{
    "aldeg_cas01" => {218, 170},
    "aldeg_cas02" => {220, 190},
    "aldeg_cas03" => {205, 186},
    "aldeg_cas04" => {116, 217},
    "aldeg_cas05" => {167, 225},
    "gefg_cas01" => {197, 36},
    "gefg_cas02" => {178, 43},
    "gefg_cas03" => {221, 30},
    "gefg_cas04" => {168, 43},
    "gefg_cas05" => {168, 31},
    "payg_cas01" => {54, 144},
    "payg_cas02" => {278, 251},
    "payg_cas03" => {9, 263},
    "payg_cas04" => {40, 235},
    "payg_cas05" => {243, 27},
    "prtg_cas01" => {96, 173},
    "prtg_cas02" => {169, 55},
    "prtg_cas03" => {181, 215},
    "prtg_cas04" => {258, 247},
    "prtg_cas05" => {52, 41}
  }

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([OutsideFlag])
    :ok
  end

  test "declares 72 placements, all sprite 722, every unique name resolving to an FE castle" do
    placements = OutsideFlag.spawn()

    assert length(placements) == 72
    assert Enum.all?(placements, &(&1.sprite == 722))

    unique_names = Enum.map(placements, & &1.unique_name)
    assert Enum.uniq(unique_names) == unique_names

    for placement <- placements do
      assert {:ok, castle_map} = FlagOwner.castle_map(placement)
      assert {:ok, _castle} = CastleDb.by_map(castle_map)
    end
  end

  test "per-castle placement counts match the reference table" do
    counts =
      OutsideFlag.spawn()
      |> Enum.group_by(fn placement ->
        {:ok, map} = FlagOwner.castle_map(placement)
        map
      end)
      |> Map.new(fn {map, placements} -> {map, length(placements)} end)

    assert counts == @per_castle
  end

  test "the registry accepts outside flag placements with no cell/gid collisions" do
    entries = Enum.map(OutsideFlag.spawn(), &{OutsideFlag, &1})

    assert :ok = NpcVerifier.verify(entries)
  end

  test "unique names are unique across both OutsideFlag and InsideFlag" do
    unique_names =
      Enum.map(OutsideFlag.spawn(), & &1.unique_name) ++
        Enum.map(InsideFlag.spawn(), & &1.unique_name)

    assert length(unique_names) == 294
    assert Enum.uniq(unique_names) |> length() == 294
  end

  test "guild_id/1 delegates to FlagOwner" do
    castle = first_castle()
    :ok = CastleStore.hydrate(%{castle.id => row(9)})
    placement = placement_for(castle.map)

    assert OutsideFlag.guild_id(placement) == 9
  end

  test "an unowned castle shows the neutral edict then closes" do
    castle = first_castle()
    gid = gid_for(castle.map)
    ctx = build_ctx(castle.map, gid)

    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "no formal master of this castle"
    assert_clean_exit(ref, pid)
  end

  test "another guild's castle names the guild and master then closes" do
    castle = first_castle()
    gid = gid_for(castle.map)
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    stub(GuildManager, :get, fn 5 ->
      {:ok,
       %GuildState{
         guild_id: 5,
         name: "Baldur Guard",
         master_char_id: 1,
         members: %{1 => %Member{char_id: 1, name: "Someone", base_level: 99, online: true}}
       }}
    end)

    ctx = build_ctx(castle.map, gid, char_id: 2, guild_id: 0)
    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text =~ "Baldur Guard"
    assert text =~ "Someone"
    assert_clean_exit(ref, pid)
  end

  test "an owner member choosing to return warps to the flag entry cell" do
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

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU, options: options}}}
    assert options == ["Return to the guild castle.", "Quit."]

    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    assert_clean_exit(ref, pid)

    map = castle.map
    {x, y} = Map.fetch!(@entries, castle.map)
    assert_received {:script_apply, {:warp, ^map, ^x, ^y}}
  end

  test "an owner member choosing to quit closes without a warp" do
    castle = first_castle()
    gid = gid_for(castle.map)
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    ctx = build_ctx(castle.map, gid, char_id: 1, guild_id: 5)
    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    continue(pid, gid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 2}}})

    assert_clean_exit(ref, pid)
    refute_received {:script_apply, {:warp, _map, _x, _y}}
  end

  test "the owner changing between select and warp closes without a warp" do
    castle = first_castle()
    gid = gid_for(castle.map)
    :ok = CastleStore.hydrate(%{castle.id => row(5)})

    ctx = build_ctx(castle.map, gid, char_id: 1, guild_id: 5)
    {:ok, pid} = start_interaction(ctx)
    ref = Process.monitor(pid)

    continue(pid, gid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :MENU}}}
    :ok = CastleStore.hydrate(%{castle.id => row(6)})
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:choice, 1}}})

    assert_clean_exit(ref, pid)
    refute_received {:script_apply, {:warp, _map, _x, _y}}
  end

  defp continue(pid, gid) do
    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :NEXT}}}
    send(pid, {:npc_interact, %NpcInteract{npc_id: gid, response: {:continue, true}}})
  end

  defp first_castle, do: CastleDb.all() |> hd()

  defp gid_for(map), do: map |> placement_for() |> NpcRegistry.entity_id()

  defp placement_for(map) do
    Enum.find(OutsideFlag.spawn(), fn placement ->
      FlagOwner.castle_map(placement) == {:ok, map}
    end)
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

  defp start_interaction(ctx), do: Interaction.start(self(), OutsideFlag, ctx)

  defp build_ctx(map, gid, opts \\ []) do
    field_map = field_map_for(map)

    %Ctx{
      char_id: Keyword.get(opts, :char_id, 1),
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: Keyword.get(opts, :char_id, 1),
        character_name: "TestPlayer",
        account_id: 100,
        map_name: field_map,
        guild_id: Keyword.get(opts, :guild_id, 0)
      },
      source: {:npc, :outside_flag_test},
      npc_gid: gid
    }
  end

  defp field_map_for(map) do
    OutsideFlag.spawn()
    |> Enum.find(fn placement -> FlagOwner.castle_map(placement) == {:ok, map} end)
    |> Map.fetch!(:map)
  end
end
