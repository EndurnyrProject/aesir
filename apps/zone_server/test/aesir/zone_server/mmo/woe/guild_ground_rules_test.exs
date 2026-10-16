defmodule Aesir.ZoneServer.Mmo.Woe.GuildGroundRulesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdBattleorder
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdEmergencyMove
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdRegeneration
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GdRestore
  alias Aesir.ZoneServer.Mmo.Skills.Guild.GuildArea
  alias Aesir.ZoneServer.Mmo.Skills.Guild.Recall
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @master_id 1
  @guild_id 5
  @area_skills [
    {GdBattleorder, 10_010},
    {GdRegeneration, 10_011},
    {GdRestore, 10_012},
    {GdEmergencyMove, 10_019}
  ]

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    stub_guild([@master_id])
    :ok
  end

  # Members take slots in list order.
  defp stub_guild(member_ids) do
    members =
      member_ids
      |> Enum.with_index()
      |> Map.new(fn {id, slot} ->
        {id, %{Member.new(id, "m#{id}", 50, true, 19) | slot: slot}}
      end)

    guild = %GuildState{
      guild_id: @guild_id,
      name: "G",
      master_char_id: @master_id,
      members: members
    }

    stub(GuildManager, :get, fn @guild_id -> {:ok, guild} end)
  end

  defp caster(map_name) do
    %PlayerState{
      character_id: @master_id,
      account_id: 1,
      guild_id: @guild_id,
      map_name: map_name
    }
  end

  defp register_member(id, map_name, pid \\ self()) do
    member = %PlayerState{
      character_id: id,
      account_id: id,
      guild_id: @guild_id,
      map_name: map_name
    }

    :ok = UnitRegistry.register_player(member, pid)
    member
  end

  defp assert_valid(skill, skill_id, caster) do
    {:ok, definition} = Catalog.by_id(skill_id)
    assert :ok = skill.validate(caster, :self, 1, definition)
  end

  test "area actives allow off-hours castle ground" do
    :ok = MapFlags.set_runtime("castle", :gvg_castle, true)
    caster = caster("castle")

    for {skill, skill_id} <- @area_skills, do: assert_valid(skill, skill_id, caster)
  end

  test "area actives reject ordinary ground and allow active GvG ground" do
    for {skill, skill_id} <- @area_skills do
      {:ok, definition} = Catalog.by_id(skill_id)
      assert {:error, :not_gvg_ground} = skill.validate(caster("ordinary"), :self, 1, definition)
    end

    :ok = MapFlags.set_runtime("active", :gvg, true)
    for {skill, skill_id} <- @area_skills, do: assert_valid(skill, skill_id, caster("active"))
  end

  test "both Urgent Calls are refused off GvG ground before the cast begins, never at its end" do
    :ok = MapFlags.set_runtime("active", :gvg, true)
    :ok = MapFlags.set_runtime("castle", :gvg_castle, true)

    for skill_id <- [10_013, 10_015] do
      assert {:error, :not_gvg_ground} =
               PlayerCaster.castable_state(caster("ordinary"), skill_id, :begin)

      assert :ok = PlayerCaster.castable_state(caster("active"), skill_id, :begin)
      assert :ok = PlayerCaster.castable_state(caster("castle"), skill_id, :begin)
      assert :ok = PlayerCaster.castable_state(caster("ordinary"), skill_id, :completion)
    end

    for {_skill, skill_id} <- @area_skills,
        do: assert(:ok = PlayerCaster.castable_state(caster("ordinary"), skill_id, :begin))
  end

  test "the area effect does not check the ground again" do
    caster = caster("ordinary")
    :ok = SpatialIndex.add_unit(:player, @master_id, 10, 10, "ordinary")
    register_member(2, "ordinary")
    :ok = SpatialIndex.add_unit(:player, 2, 11, 10, "ordinary")

    assert GuildArea.guildmates_in_range(caster, 15) == [2]
  end

  test "the recall effect does not check the ground again" do
    register_member(2, "source")
    :ok = SpatialIndex.add_unit(:player, @master_id, 10, 10, "ordinary")
    stub_guild([@master_id, 2])
    stub(MapData, :walkable?, fn _map, _x, _y -> true end)
    test_pid = self()

    stub(PlayerSession, :warp, fn _pid, map, _x, _y ->
      send(test_pid, {:warped, map})
      :ok
    end)

    assert :ok = Recall.summon_members(caster("ordinary"), :all)
    assert_received {:warped, "ordinary"}
  end

  test "recall skips nowarp sources without counting them toward the cap" do
    :ok = SpatialIndex.add_unit(:player, @master_id, 10, 10, "destination")
    :ok = MapFlags.set_runtime("blocked_source", :nowarp, true)

    member_ids = [@master_id | Enum.to_list(2..16)]
    candidate_ids = Enum.reject(member_ids, &(&1 == @master_id))
    blocked_id = Enum.at(candidate_ids, 2)
    expected_ids = candidate_ids |> Enum.reject(&(&1 == blocked_id)) |> Enum.take(7)
    later_eligible_id = Enum.at(candidate_ids, 7)
    test_pid = self()

    member_pids =
      Map.new(candidate_ids, fn id ->
        pid =
          spawn(fn ->
            receive do
              {:warp, map} -> send(test_pid, {:warped, id, map})
            end
          end)

        source_map = if id == blocked_id, do: "blocked_source", else: "source"
        register_member(id, source_map, pid)
        {id, pid}
      end)

    on_exit(fn -> Enum.each(member_pids, fn {_id, pid} -> Process.exit(pid, :kill) end) end)

    stub_guild(member_ids)
    stub(MapData, :walkable?, fn _map, _x, _y -> true end)

    stub(PlayerSession, :warp, fn pid, map, _x, _y ->
      send(pid, {:warp, map})
      :ok
    end)

    assert later_eligible_id in expected_ids
    assert :ok = Recall.summon_members(caster("destination"), 7)

    for id <- expected_ids, do: assert_receive({:warped, ^id, "destination"})
    refute_receive {:warped, ^blocked_id, _map}
  end

  test "recall permits a nowarp source when that source is GvG ground" do
    :ok = MapFlags.set_runtime("destination", :gvg_castle, true)
    :ok = MapFlags.set_runtime("source_castle", :gvg_castle, true)
    :ok = MapFlags.set_runtime("source_castle", :nowarp, true)
    :ok = SpatialIndex.add_unit(:player, @master_id, 10, 10, "destination")
    register_member(2, "source_castle")

    stub_guild([@master_id, 2])
    stub(MapData, :walkable?, fn _map, _x, _y -> true end)
    test_pid = self()

    stub(PlayerSession, :warp, fn _pid, map, _x, _y ->
      send(test_pid, {:warped, map})
      :ok
    end)

    assert :ok = Recall.summon_members(caster("destination"), :all)
    assert_received {:warped, "destination"}
  end
end
