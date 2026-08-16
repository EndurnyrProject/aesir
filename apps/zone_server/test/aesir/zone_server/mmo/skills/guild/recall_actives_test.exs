defmodule Aesir.ZoneServer.Mmo.Skills.Guild.RecallActivesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdEmergencycall
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdItememergencycall
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @master_id 1
  @guild_id 5

  defp register_player(id, {x, y}) do
    player =
      %Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: "prontera",
        last_x: x,
        last_y: y,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 50,
        job_level: 50,
        class: 12
      }
      |> PlayerState.new()
      |> Map.put(:guild_id, @guild_id)

    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_unit(:player, id, x, y, "prontera")
    player
  end

  defp stub_guild(member_ids) do
    stub(GuildManager, :get, fn @guild_id ->
      {:ok,
       %{
         master_char_id: @master_id,
         members: Map.new(member_ids, &{&1, %{char_id: &1}})
       }}
    end)
  end

  defp capture_warps do
    test_pid = self()

    stub(PlayerSession, :warp, fn _pid, map, x, y ->
      send(test_pid, {:warped, map, x, y})
      :ok
    end)

    stub(MapCache, :walkable?, fn _map, _x, _y -> true end)
  end

  test "definitions carry the reference pacing" do
    assert {:ok, emergency} = Catalog.by_id(10_013)
    assert emergency.fixed_cast_time == [5_000]
    assert emergency.cooldown == [300_000]

    assert {:ok, item_variant} = Catalog.by_id(10_015)
    assert item_variant.max_level == 3
  end

  test "EMERGENCYCALL warps every online member (not the caster) to cells around the master" do
    master = register_player(@master_id, {10, 10})
    register_player(2, {40, 40})
    register_player(3, {50, 50})
    stub_guild([@master_id, 2, 3, 999])
    capture_warps()

    assert {:ok, _} = GdEmergencycall.cast(master, :self, 1, nil)

    assert_received {:warped, "prontera", x1, y1}
    assert_received {:warped, "prontera", x2, y2}
    refute_received {:warped, _, _, _}

    for {x, y} <- [{x1, y1}, {x2, y2}] do
      assert abs(x - 10) <= 1 and abs(y - 10) <= 1
    end
  end

  test "an unwalkable ring cell falls back to the master's own cell" do
    master = register_player(@master_id, {10, 10})
    register_player(2, {40, 40})
    stub_guild([@master_id, 2])

    test_pid = self()

    stub(PlayerSession, :warp, fn _pid, map, x, y ->
      send(test_pid, {:warped, map, x, y})
      :ok
    end)

    stub(MapCache, :walkable?, fn _map, _x, _y -> false end)

    assert {:ok, _} = GdEmergencycall.cast(master, :self, 1, nil)

    assert_received {:warped, "prontera", 10, 10}
  end

  test "ITEMEMERGENCYCALL caps the number of recalled members by level" do
    master = register_player(@master_id, {10, 10})
    member_ids = for id <- 2..12, do: id
    Enum.each(member_ids, &register_player(&1, {40, 40}))
    stub_guild([@master_id | member_ids])
    capture_warps()

    assert {:ok, _} = GdItememergencycall.cast(master, :self, 1, nil)

    warped =
      Enum.reduce_while(1..20, 0, fn _n, acc ->
        receive do
          {:warped, _, _, _} -> {:cont, acc + 1}
        after
          0 -> {:halt, acc}
        end
      end)

    assert warped == 7
  end

  test "non-masters and guildless casters are rejected" do
    stub_guild([@master_id])

    non_master = %PlayerState{character_id: 99, account_id: 99, guild_id: @guild_id}
    guildless = %PlayerState{character_id: 99, account_id: 99, guild_id: 0}

    assert {:error, :not_guild_master} = GdEmergencycall.validate(non_master, :self, 1, nil)
    assert {:error, :not_guild_master} = GdItememergencycall.validate(guildless, :self, 1, nil)
  end
end
