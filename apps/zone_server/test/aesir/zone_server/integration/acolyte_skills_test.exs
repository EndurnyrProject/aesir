defmodule Aesir.ZoneServer.Integration.AcolyteSkillsTest do
  @moduledoc """
  End-to-end coverage that the Acolyte Tier 1 kit is playable on the real stack:

    1. The Tier 1 tree is learnable through the live session/learning flow, with
       prerequisites enforced (learning Inc AGI before Heal lv3 is rejected; the
       Heal -> Inc AGI -> Dec AGI and Heal -> Cure chains succeed in order).
    2. A real `AlHeal.cast/4` against an ally session restores that ally's HP over
       the PubSub heal path, bounded by max HP.
    3. A real `AlRuwach.cast/4` applies `:sc_ruwach` to the caster in ETS-backed
       `StatusStorage`, and its first pulse reveals a concealed unit and emits a
       holy splash at a nearby mob.

  Drives the real subsystems (skill learning, skill modules, Combat, status
  interpreter/storage, player/mob sessions). Only the network transport is faked
  by the `IntegrationCase` connection process.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillList
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlRuwach
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  # rAthena class id for the 1st-class Acolyte; PlayerState derives job_id from it.
  @acolyte_class 4

  # SkillLearningHandler reject code for an unmet prerequisite.
  @missing_prerequisite 4

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp current_hp(player_pid), do: get_player_state(player_pid).stats.current_state.hp
  defp max_hp(player_pid), do: get_player_state(player_pid).stats.derived_stats.max_hp

  describe "Tier 1 tree is learnable in prerequisite order" do
    test "rejects out-of-order learning and accepts the Heal-gated chains" do
      heal = catalog_id(:al_heal)
      incagi = catalog_id(:al_incagi)
      decagi = catalog_id(:al_decagi)
      cure = catalog_id(:al_cure)

      player =
        start_player_session(
          id: 9101,
          name: "Acco",
          class: @acolyte_class,
          base_level: 50,
          job_level: 50,
          int: 40,
          skill_point: 10
        )

      flush_packets()

      # Inc AGI requires Heal lv3; with Heal unlearned the request is rejected and
      # no point is spent.
      simulate_incoming_message(player.pid, %LearnSkill{skill_id: incagi})

      assert_receive {:packet_sent,
                      %LearnSkillResult{
                        skill_id: ^incagi,
                        ok: false,
                        reason: @missing_prerequisite
                      }, _},
                     1_000

      progression = get_player_state(player.pid).stats.progression
      assert progression.learned_skills == %{}
      assert progression.skill_point == 10

      # Heal has no prerequisite; raise it to level 3.
      for _ <- 1..3, do: learn(player.pid, heal)
      assert learned_level(player.pid, heal) == 3

      # Heal lv3 unlocks Inc AGI, Inc AGI lv1 unlocks Dec AGI, Heal lv2 unlocks Cure.
      learn(player.pid, incagi)
      learn(player.pid, decagi)
      learn(player.pid, cure)

      progression = get_player_state(player.pid).stats.progression

      assert progression.learned_skills == %{
               heal => 3,
               incagi => 1,
               decagi => 1,
               cure => 1
             }

      # 6 points spent (3 Heal + Inc + Dec + Cure); the rejected attempt spent none.
      assert progression.skill_point == 4
    end
  end

  describe "Heal lands on an ally session" do
    test "AlHeal cast restores the ally's HP, clamped to max HP" do
      healer =
        start_player_session(
          id: 9201,
          name: "Healer",
          class: @acolyte_class,
          base_level: 50,
          int: 40
        )

      ally = start_player_session(id: 9202, name: "Ally", class: @acolyte_class, base_level: 50)

      ally_max = max_hp(ally.pid)
      start_hp = current_hp(ally.pid)

      # Open a small wound so the heal has room to work without risking death.
      PlayerSession.apply_damage(ally.pid, 10, nil)
      assert current_hp(ally.pid) == start_hp - 10

      healer_state = get_player_state(healer.pid)

      {:ok, heal_def} = Catalog.by_id(catalog_id(:al_heal))

      assert {:ok, ^healer_state} =
               AlHeal.cast(healer_state, {:unit, ally.character.id}, 10, heal_def)

      healed = current_hp(ally.pid)
      assert healed > start_hp - 10
      assert healed <= ally_max
    end

    test "the PubSub heal path applies the exact amount and never exceeds max HP" do
      ally =
        start_player_session(id: 9203, name: "Patient", class: @acolyte_class, base_level: 50)

      ally_max = max_hp(ally.pid)
      start_hp = current_hp(ally.pid)

      # Drop to 1 HP (alive) for a deterministic, sub-max restore.
      PlayerSession.apply_damage(ally.pid, start_hp - 1, nil)
      assert current_hp(ally.pid) == 1

      :ok = Combat.apply_heal(ally.character.id, 5, nil)
      assert current_hp(ally.pid) == 6

      # A heal larger than the remaining pool clamps at max HP.
      :ok = Combat.apply_heal(ally.character.id, 1_000_000, nil)
      assert current_hp(ally.pid) == ally_max
    end
  end

  describe "Ruwach aura" do
    test "applies sc_ruwach, reveals a concealed unit, and emits a holy splash" do
      caster =
        start_player_session(
          id: 9301,
          name: "Seer",
          class: @acolyte_class,
          base_level: 50,
          int: 40,
          position: {150, 150}
        )

      hidden =
        start_player_session(id: 9302, name: "Sneak", class: @acolyte_class, position: {151, 150})

      # These statuses live in the shared StatusStorage; clear them even if an
      # assertion below fails, so the global StatusTickManager does not keep
      # pulsing the aura after this world is torn down (bare ETS deletes, safe to
      # run from the on_exit process once the entities are gone).
      on_exit(fn ->
        StatusStorage.remove_status(:player, caster.character.id, :sc_ruwach)
        StatusStorage.remove_status(:player, hidden.character.id, :sc_hiding)
      end)

      assert :ok =
               StatusInterpreter.apply_status(:player, hidden.character.id, :sc_hiding,
                 caster_id: hidden.character.id
               )

      assert StatusStorage.has_status?(:player, hidden.character.id, :sc_hiding)

      mob =
        start_mob_session(unit_id: 93_050, map_name: "prontera", position: {150, 151}, hp: 100)

      flush_packets()

      caster_state = get_player_state(caster.pid)
      {:ok, ruwach_def} = Catalog.by_id(catalog_id(:al_ruwach))
      assert {:ok, ^caster_state} = AlRuwach.cast(caster_state, :self, 1, ruwach_def)

      assert StatusStorage.has_status?(:player, caster.character.id, :sc_ruwach)

      # The first pulse fires on apply: the concealed ally is revealed in radius 2.
      refute StatusStorage.has_status?(:player, hidden.character.id, :sc_hiding)

      # ...and the pulse splashes the in-range mob with a holy AL_RUWACH hit.
      mob_id = mob.unit_id

      assert_receive {:packet_sent, %SkillDamage{skill_id: 24, target_id: ^mob_id}, _}, 1_000
    end
  end

  defp learn(player_pid, skill_id) do
    simulate_incoming_message(player_pid, %LearnSkill{skill_id: skill_id})
    # The enriched SkillList is the success ack; waiting on it serializes the
    # async learn cast before the next request/read.
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end

  defp learned_level(player_pid, skill_id) do
    get_player_state(player_pid).stats.progression.learned_skills[skill_id]
  end
end
