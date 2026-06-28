defmodule Aesir.ZoneServer.Integration.ArcherSkillsTest do
  @moduledoc """
  End-to-end coverage that the 1st-class Archer kit is playable on the real stack:

    1. The archer tree is learnable through the live session/learning flow, with
       prerequisites enforced (Vulture's Eye before Owl's Eye 3 and Arrow Shower
       before Double Strafe 5 are rejected; the full chain succeeds in order).
    2. Passive bonuses take effect from learned skills: Owl's Eye raises effective
       DEX and Vulture's Eye raises HIT.
    3. Improve Concentration applies `:sc_concentrate` and raises the caster's
       effective AGI/DEX.
    4. Double Strafe deals two weapon hits in one cast; Arrow Shower splashes the
       area and knocks targets back.

  The arrow ammunition mechanic (no-ammo gating, per-attack/per-cast consumption,
  and the equipped arrow driving attack element) is covered by the unit/handler/
  interpreter tests (`player_state_test`, `combat_action_handler_test`,
  `skill/interpreter_test`): the integration harness has no scaffolding to equip a
  bow + arrows on a live session, so those paths are asserted at that level.
  Vulture's Eye's bow-only range bonus is likewise unit-covered (`ac_vulture_test`,
  `player_state_test`) for the same no-equip-scaffolding reason.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.Knockback
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AcConcentration
  alias Aesir.ZoneServer.Mmo.Skills.AcDouble
  alias Aesir.ZoneServer.Mmo.Skills.AcShower
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats

  # rAthena class id for the 1st-class Archer; PlayerState derives job_id from it.
  @archer_class 3

  # SkillLearningHandler reject code for an unmet prerequisite.
  @missing_prerequisite 4

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp skill_def(name) do
    {:ok, definition} = Catalog.by_id(catalog_id(name))
    definition
  end

  defp recalc(player_pid) do
    state = get_player_state(player_pid)
    Stats.calculate_stats(state.stats, state.character_id)
  end

  defp effective(player_pid, stat), do: Stats.get_effective_stat(recalc(player_pid), stat)
  defp combat_hit(player_pid), do: recalc(player_pid).combat_stats.hit

  describe "archer tree is learnable in prerequisite order" do
    test "rejects out-of-order learning and accepts the gated chain" do
      owl = catalog_id(:ac_owl)
      vulture = catalog_id(:ac_vulture)
      concentration = catalog_id(:ac_concentration)
      double = catalog_id(:ac_double)
      shower = catalog_id(:ac_shower)

      player =
        start_player_session(
          id: 9401,
          name: "Archy",
          class: @archer_class,
          base_level: 50,
          job_level: 50,
          dex: 30,
          skill_point: 20
        )

      flush_packets()

      # Vulture's Eye requires Owl's Eye 3; with Owl's Eye unlearned it is rejected
      # and no point is spent.
      simulate_incoming_message(player.pid, %LearnSkill{skill_id: vulture})

      assert_receive {:packet_sent,
                      %LearnSkillResult{
                        skill_id: ^vulture,
                        ok: false,
                        reason: @missing_prerequisite
                      }, _},
                     1_000

      assert get_player_state(player.pid).stats.progression.learned_skills == %{}

      # Owl's Eye has no prerequisite; raise it to level 3 to unlock Vulture's Eye.
      for _ <- 1..3, do: learn(player.pid, owl)
      learn(player.pid, vulture)
      # Vulture's Eye 1 unlocks Improve Concentration.
      learn(player.pid, concentration)

      # Arrow Shower requires Double Strafe 5; with Double Strafe unlearned it is rejected.
      simulate_incoming_message(player.pid, %LearnSkill{skill_id: shower})

      assert_receive {:packet_sent,
                      %LearnSkillResult{
                        skill_id: ^shower,
                        ok: false,
                        reason: @missing_prerequisite
                      }, _},
                     1_000

      for _ <- 1..5, do: learn(player.pid, double)
      learn(player.pid, shower)

      progression = get_player_state(player.pid).stats.progression

      assert progression.learned_skills == %{
               owl => 3,
               vulture => 1,
               concentration => 1,
               double => 5,
               shower => 1
             }

      # 11 points spent (3 Owl + Vulture + Conc + 5 Double + Shower); the two rejected
      # attempts spent none.
      assert progression.skill_point == 9
    end
  end

  describe "passive stat bonuses from learned skills" do
    test "Owl's Eye raises effective DEX and Vulture's Eye raises HIT" do
      owl = catalog_id(:ac_owl)
      vulture = catalog_id(:ac_vulture)

      player =
        start_player_session(
          id: 9411,
          name: "Eyes",
          class: @archer_class,
          base_level: 50,
          job_level: 50,
          dex: 30,
          skill_point: 20
        )

      flush_packets()

      dex_before = effective(player.pid, :dex)

      for _ <- 1..3, do: learn(player.pid, owl)

      # Owl's Eye 3 adds +3 DEX.
      assert effective(player.pid, :dex) == dex_before + 3

      # With Owl's Eye unchanged, learning Vulture's Eye adds +1 HIT per level.
      hit_before = combat_hit(player.pid)
      for _ <- 1..5, do: learn(player.pid, vulture)

      assert combat_hit(player.pid) == hit_before + 5
    end
  end

  describe "Improve Concentration self-buff" do
    test "applies sc_concentrate and raises effective AGI/DEX" do
      caster =
        start_player_session(
          id: 9421,
          name: "Focus",
          class: @archer_class,
          base_level: 50,
          job_level: 50,
          agi: 60,
          dex: 60
        )

      on_exit(fn ->
        StatusStorage.remove_status(:player, caster.character.id, :sc_concentrate)
      end)

      flush_packets()

      agi_before = effective(caster.pid, :agi)
      dex_before = effective(caster.pid, :dex)

      caster_state = get_player_state(caster.pid)

      assert {:ok, ^caster_state} =
               AcConcentration.cast(caster_state, :self, 10, skill_def(:ac_concentration))

      assert StatusStorage.has_status?(:player, caster.character.id, :sc_concentrate)

      assert effective(caster.pid, :agi) > agi_before
      assert effective(caster.pid, :dex) > dex_before
    end
  end

  describe "Double Strafe" do
    test "deals two weapon hits to one target in a single cast" do
      caster =
        start_player_session(
          id: 9431,
          name: "Strafer",
          class: @archer_class,
          base_level: 50,
          job_level: 50,
          dex: 60,
          position: {150, 150}
        )

      mob =
        start_mob_session(unit_id: 94_310, map_name: "prontera", position: {151, 150}, hp: 5000)

      mob_id = mob.unit_id

      flush_packets()

      caster_state = get_player_state(caster.pid)

      assert {:ok, ^caster_state} =
               AcDouble.cast(caster_state, {:unit, mob_id}, 10, skill_def(:ac_double))

      assert_receive {:packet_sent, %SkillDamage{skill_id: 46, target_id: ^mob_id}, _}, 1_000
      assert_receive {:packet_sent, %SkillDamage{skill_id: 46, target_id: ^mob_id}, _}, 1_000
    end
  end

  describe "Arrow Shower" do
    test "splashes the area around the target and knocks targets back" do
      caster =
        start_player_session(
          id: 9441,
          name: "Rainer",
          class: @archer_class,
          base_level: 50,
          job_level: 50,
          dex: 60,
          position: {150, 150}
        )

      # Center mob sits at the splash center; the second mob is one cell out, so it
      # is both splashed and blown back (the center mob cannot be pushed from its
      # own cell).
      center =
        start_mob_session(unit_id: 94_410, map_name: "prontera", position: {150, 151}, hp: 5000)

      edge =
        start_mob_session(unit_id: 94_411, map_name: "prontera", position: {150, 152}, hp: 5000)

      center_id = center.unit_id
      edge_id = edge.unit_id

      flush_packets()

      caster_state = get_player_state(caster.pid)

      assert {:ok, ^caster_state} =
               AcShower.cast(caster_state, {:unit, center_id}, 1, skill_def(:ac_shower))

      assert_receive {:packet_sent, %SkillDamage{skill_id: 47, target_id: ^center_id}, _}, 1_000
      assert_receive {:packet_sent, %SkillDamage{skill_id: 47, target_id: ^edge_id}, _}, 1_000

      # The edge mob is blown back away from the center (a Knockback frame is sent to
      # nearby players); the center mob, sitting on the center cell, is not.
      assert_receive {:packet_sent, %Knockback{unit_id: ^edge_id}, _}, 1_000
    end
  end

  defp learn(player_pid, skill_id) do
    simulate_incoming_message(player_pid, %LearnSkill{skill_id: skill_id})
    # The enriched SkillList is the success ack; waiting on it serializes the async
    # learn cast before the next request/read.
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end
end
