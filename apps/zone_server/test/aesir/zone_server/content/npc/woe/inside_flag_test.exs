defmodule Aesir.ZoneServer.Content.Npc.Woe.InsideFlagTest do
  @moduledoc """
  Covers the Task 5 inside castle flags: 222 placements across the FE
  castles and towns, sprite 722, silent on talk, emblem via `guild_id/1`.
  """

  use ExUnit.Case, async: false

  alias Aesir.Net.NpcDialog
  alias Aesir.ZoneServer.Content.Npc.Woe.FlagOwner
  alias Aesir.ZoneServer.Content.Npc.Woe.InsideFlag
  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.CastleStore
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Npc.Verifier, as: NpcVerifier
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @per_castle %{
    "aldeg_cas01" => 19,
    "aldeg_cas02" => 15,
    "aldeg_cas03" => 18,
    "aldeg_cas04" => 18,
    "aldeg_cas05" => 17,
    "gefg_cas01" => 7,
    "gefg_cas02" => 8,
    "gefg_cas03" => 9,
    "gefg_cas04" => 9,
    "gefg_cas05" => 7,
    "payg_cas01" => 8,
    "payg_cas02" => 8,
    "payg_cas03" => 8,
    "payg_cas04" => 8,
    "payg_cas05" => 8,
    "prtg_cas01" => 11,
    "prtg_cas02" => 13,
    "prtg_cas03" => 11,
    "prtg_cas04" => 11,
    "prtg_cas05" => 9
  }

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = CastleStore.init()
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([InsideFlag])
    :ok
  end

  test "declares 222 placements, all sprite 722, every unique name resolving to an FE castle" do
    placements = InsideFlag.spawn()

    assert length(placements) == 222
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
      InsideFlag.spawn()
      |> Enum.group_by(fn placement ->
        {:ok, map} = FlagOwner.castle_map(placement)
        map
      end)
      |> Map.new(fn {map, placements} -> {map, length(placements)} end)

    assert counts == @per_castle
  end

  test "the registry accepts inside flag placements with no cell/gid collisions" do
    entries = Enum.map(InsideFlag.spawn(), &{InsideFlag, &1})

    assert :ok = NpcVerifier.verify(entries)
  end

  test "on_talk is a single close with no dialog text" do
    placement = hd(InsideFlag.spawn())
    gid = NpcRegistry.entity_id(placement)

    ctx = %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      game_state: %PlayerState{
        character_id: 1,
        character_name: "TestPlayer",
        account_id: 100,
        map_name: placement.map,
        guild_id: 0
      },
      source: {:npc, :inside_flag_test},
      npc_gid: gid
    }

    {:ok, pid} = Interaction.start(self(), InsideFlag, ctx)
    ref = Process.monitor(pid)

    assert_receive {:send, _ch, {:npc_dialog, %NpcDialog{expect: :CLOSE, text: text}}}
    assert text in [nil, ""]

    assert_receive {:DOWN, ^ref, :process, ^pid, reason}
    assert reason in [:normal, :noproc]
  end

  test "guild_id/1 delegates to FlagOwner" do
    castle = CastleDb.all() |> hd()

    :ok =
      CastleStore.hydrate(%{
        castle.id => %{
          guild_id: 7,
          economy: 0,
          defense: 0,
          invested_economy: 0,
          invested_defense: 0,
          guardians: []
        }
      })

    placement = Enum.find(InsideFlag.spawn(), &(FlagOwner.castle_map(&1) == {:ok, castle.map}))

    assert InsideFlag.guild_id(placement) == 7
  end
end
