defmodule Aesir.ZoneServer.Mmo.Skills.Guild.RecallActivesTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Map.MapData
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

  defp register_player(id, {x, y}, opts \\ []) do
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
      |> Map.merge(%{guild_id: @guild_id, action_state: Keyword.get(opts, :action_state, :idle)})

    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_unit(:player, id, x, y, "prontera")
    player
  end

  # `slots` maps a member's char id to its slot in the guild's member list.
  defp stub_guild(slots) do
    members =
      Map.new(slots, fn {char_id, slot} ->
        {char_id, %{Member.new(char_id, "m#{char_id}", 50, true, 19) | slot: slot}}
      end)

    guild = %GuildState{
      guild_id: @guild_id,
      name: "G",
      master_char_id: @master_id,
      members: members
    }

    stub(GuildManager, :get, fn @guild_id -> {:ok, guild} end)
  end

  defp capture_warps(walkable? \\ true) do
    test_pid = self()

    stub(PlayerSession, :warp, fn _pid, map, x, y ->
      send(test_pid, {:warped, map, x, y})
      :ok
    end)

    stub(MapData, :walkable?, fn _map, _x, _y -> walkable? end)
  end

  defp warps do
    receive do
      {:warped, "prontera", x, y} -> [{x, y} | warps()]
    after
      0 -> []
    end
  end

  test "Urgent Call warps the online, living members in slot order to their slot's ring cell" do
    master = register_player(@master_id, {10, 10})
    register_player(2, {40, 40})
    register_player(4, {40, 40}, action_state: :dead)
    register_player(5, {40, 40})
    register_player(6, {40, 40})
    stub_guild(%{@master_id => 0, 6 => 10, 2 => 1, 3 => 3, 4 => 4, 5 => 5})
    capture_warps()

    assert {:ok, _} = GdEmergencycall.cast(master, :self, 1, nil)

    # Slot 1 is ring {1, 0}, slot 5 is ring {1, -1}, slot 10 wraps to ring {1, 0}.
    assert warps() == [{11, 10}, {11, 9}, {11, 10}]
  end

  test "an unwalkable ring cell falls back to the master's own cell" do
    master = register_player(@master_id, {10, 10})
    register_player(2, {40, 40})
    stub_guild(%{@master_id => 0, 2 => 1})
    capture_warps(false)

    assert {:ok, _} = GdEmergencycall.cast(master, :self, 1, nil)

    assert warps() == [{10, 10}]
  end

  test "Item Emergency Call stops once its level's number of members were warped" do
    master = register_player(@master_id, {10, 10})
    register_player(2, {40, 40}, action_state: :dead)
    Enum.each(3..12, &register_player(&1, {40, 40}))
    stub_guild(Map.new(1..12, &{&1, &1 - 1}))
    capture_warps()

    assert {:ok, _} = GdItememergencycall.cast(master, :self, 1, nil)

    assert length(warps()) == 7
  end

  test "a non-master or guildless caster is dropped silently at cast begin" do
    stub_guild(%{@master_id => 0})

    non_master = %PlayerState{character_id: 99, account_id: 99, guild_id: @guild_id}
    guildless = %PlayerState{character_id: 99, account_id: 99, guild_id: 0}

    assert {:error, :guild_skill_unavailable} =
             GdEmergencycall.validate(non_master, :self, 1, nil)

    assert {:error, :guild_skill_unavailable} =
             GdItememergencycall.validate(guildless, :self, 1, nil)
  end

  test "Leap, or Lope at level 3, doubles Urgent Call's cast time after its early stage" do
    master = register_player(@master_id, {10, 10})
    with_skills = &put_in(master.stats.progression.learned_skills, &1)

    assert GdEmergencycall.scale_cast_time(master, :self, 1, 5_000) == 5_000
    assert GdEmergencycall.scale_cast_time(with_skills.(%{426 => 1}), :self, 1, 5_000) == 10_000
    assert GdEmergencycall.scale_cast_time(with_skills.(%{5_023 => 2}), :self, 1, 5_000) == 5_000
    assert GdEmergencycall.scale_cast_time(with_skills.(%{5_023 => 3}), :self, 1, 5_000) == 10_000
  end

  describe "cooldowns the effect arms" do
    setup do
      stub_guild(%{@master_id => 0})
      %{master: register_player(@master_id, {10, 10}), now: 1_000}
    end

    @tag game_mode: :renewal
    test "renewal re-arms the cast skill's own cooldown", %{master: master, now: now} do
      definition = GdItememergencycall.definition()
      master = %{master | skill_cooldowns: %{10_015 => now + 250_000}}

      assert GdItememergencycall.rearm_cooldowns(master, 1, definition, now).skill_cooldowns ==
               %{10_015 => now + 300_000}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal blocks the four guild skills, not the scroll's own", %{
      master: master,
      now: now
    } do
      definition = GdItememergencycall.definition()
      blocked = GdItememergencycall.rearm_cooldowns(master, 1, definition, now)

      assert blocked.skill_cooldowns ==
               Map.new([10_010, 10_011, 10_012, 10_013], &{&1, now + 300_000})
    end

    test "a caster whose guild is gone arms nothing", %{master: master, now: now} do
      stub(GuildManager, :get, fn @guild_id -> {:error, :not_found} end)
      definition = GdEmergencycall.definition()

      assert GdEmergencycall.rearm_cooldowns(master, 1, definition, now).skill_cooldowns == %{}
    end
  end
end
