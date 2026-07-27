defmodule Aesir.ZoneServer.Integration.CrusaderSkillsTest do
  @moduledoc """
  End-to-end acceptance coverage for the Crusader kit against the real
  subsystems: live `PlayerSession`/`MobSession`, the ETS-backed `StatusStorage`
  and tick manager, the real combat path (`Combat.execute_mob_attack`,
  `DamageCalculator`), the real `Party.Manager`, and the real skill/ground-unit
  machinery. Only the network transport is faked (via `IntegrationCase`).

  The four engine seams the kit adds each get exercised through a real hit:

    * `before_weapon_hit` — Guard (`sc_autoguard`) intercepts a live mob swing
      before any damage, with a seeded RNG so the per-level block roll lands.
    * damage-taken families — Defender (`sc_defender`) cuts a long-range hit
      through the real `DamageCalculator` while a melee hit is untouched.
    * `after_damage_taken` — Reflect Shield (`sc_reflectshield`) returns part of a
      melee mob's damage to it through the async reflect path, no loop.
    * Devotion redirection — a mob hit on a devoted party member lands on the
      Crusader instead, and every break condition (range, either death, map
      change, expiry) tears the link down.

  Devotion is cast through the live session (`SkillCast`), so the party
  membership, level-gap and range gates all run for real. The defensive toggles
  are applied by calling each skill module's `cast/4` directly rather than
  through the session: that runs the real toggle + Devotion mirror fan-out, and
  deliberately skips only the shield-equipped cast gate (unit-tested per skill),
  which is not the behavior under test here and would otherwise force equipping a
  real shield item on every fixture.

  `HitCalculations.calculate_hit_result` is stubbed to `:hit` (the same seam the
  sibling mob-cast test stubs) so a swing under test always lands; the combat
  path itself is unstubbed. Bounded polling (`eventually/2`) waits on the async
  apply/reflect/redirect casts and the 1s status ticks rather than fixed sleeps,
  matching the existing integration precedent.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  import Mimic

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkill
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage, as: SkillUnitStorage
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrAutoguard
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrDefender
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrReflectshield
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DevotedBy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @map "prontera"
  @crusader_class 14

  @cr_devotion 255
  @cr_grandcross 254

  # Seed whose first `:rand.uniform(100)` is 8: below every Guard block chance
  # from level 2 up, so a level-10 (30%) block deterministically lands.
  @block_seed {1, 1, 1}

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    on_exit(&ClusterTestHelper.clear_all/0)

    :ok
  end

  describe "Devotion lifecycle" do
    test "a mob hit on the devotee lands on the Crusader, and the devotee is unharmed" do
      %{crusader: crusader, devotee: devotee} = devoted_pair()

      mob = spawn_mob(9_610, {151, 150})

      crusader_hp = current_hp(crusader.pid)
      devotee_hp = current_hp(devotee.pid)

      assert :ok = Combat.execute_mob_attack(mob_state(mob), devotee.character.id)

      assert eventually(fn -> current_hp(crusader.pid) < crusader_hp end)
      assert current_hp(devotee.pid) == devotee_hp
    end

    test "the link breaks when the Crusader walks out of range and the devotee takes the hit" do
      %{crusader: crusader, devotee: devotee} = devoted_pair()

      mob = spawn_mob(9_611, {151, 150})
      devotee_hp = current_hp(devotee.pid)

      SpatialIndex.update_unit_position(:player, crusader.character.id, 200, 200, @map)

      assert :ok = Combat.execute_mob_attack(mob_state(mob), devotee.character.id)

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, devotee.character.id, :sc_devotion)
             end)

      assert current_hp(devotee.pid) < devotee_hp
      assert DevotedBy.count(crusader.character.id) == 0
    end

    test "the link breaks when the devotee dies" do
      %{crusader: crusader, devotee: devotee} = devoted_pair()

      PlayerSession.apply_damage(devotee.pid, 999_999_999, nil)
      assert eventually(fn -> get_player_state(devotee.pid).action_state == :dead end)

      assert eventually(fn -> DevotedBy.count(crusader.character.id) == 0 end)
    end

    test "the link breaks when the Crusader dies, and the killing redirect leaves the devotee unharmed" do
      %{crusader: crusader, devotee: devotee} = devoted_pair(crusader_attrs: %{hp: 5, max_hp: 5})

      mob = spawn_mob(9_613, {151, 150})
      devotee_hp = current_hp(devotee.pid)

      assert :ok = Combat.execute_mob_attack(mob_state(mob), devotee.character.id)

      assert eventually(fn -> get_player_state(crusader.pid).action_state == :dead end)
      assert current_hp(devotee.pid) == devotee_hp

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, devotee.character.id, :sc_devotion)
             end)
    end

    test "a map change on the devotee clears both sides of the link" do
      %{crusader: crusader, devotee: devotee} = devoted_pair()

      StatusInterpreter.remove_on_map_change(:player, devotee.character.id)

      refute StatusStorage.has_status?(:player, devotee.character.id, :sc_devotion)
      assert eventually(fn -> DevotedBy.count(crusader.character.id) == 0 end)
    end

    test "the link expires on its own duration and cascades to the Crusader" do
      %{crusader: crusader, devotee: devotee} = party_pair()

      link_devotion(crusader.character.id, devotee.character.id, 250)

      assert StatusStorage.has_status?(:player, devotee.character.id, :sc_devotion)
      assert DevotedBy.count(crusader.character.id) == 1

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, devotee.character.id, :sc_devotion)
             end)

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, crusader.character.id, :sc_devoted_by)
             end)
    end

    test "toggling Defender mid-devotion mirrors it onto the devotee, and toggling off removes it" do
      %{crusader: crusader, devotee: devotee} = devoted_pair()
      crusader_id = crusader.character.id
      devotee_id = devotee.character.id

      refute StatusStorage.has_status?(:player, devotee_id, :sc_defender)

      toggle_defensive(CrDefender, crusader.pid, 5)

      assert eventually(fn ->
               match?(
                 %{val1: 5, state: %{mirrored_from: ^crusader_id}},
                 StatusStorage.get_status(:player, devotee_id, :sc_defender)
               )
             end)

      toggle_defensive(CrDefender, crusader.pid, 5)

      assert eventually(fn ->
               not StatusStorage.has_status?(:player, devotee_id, :sc_defender)
             end)
    end
  end

  describe "Autoguard" do
    test "blocks a real mob swing end to end, taking zero damage while the stance persists" do
      crusader = start_solo_crusader(9_620, {150, 150})
      mob = spawn_mob(9_621, {151, 150})

      toggle_defensive(CrAutoguard, crusader.pid, 10)
      assert StatusStorage.has_status?(:player, crusader.character.id, :sc_autoguard)

      crusader_hp = current_hp(crusader.pid)

      :rand.seed(:exsss, @block_seed)
      assert :intercepted = Combat.execute_mob_attack(mob_state(mob), crusader.character.id)

      assert current_hp(crusader.pid) == crusader_hp
      assert StatusStorage.has_status?(:player, crusader.character.id, :sc_autoguard)
    end
  end

  describe "Defender" do
    test "reduces a long-range hit through the real damage calculator but not a melee one" do
      crusader = start_solo_crusader(9_630, {150, 150})

      defender = PlayerState.to_combatant(get_player_state(crusader.pid))
      ranged = CombatTestHelper.create_mob_combatant(unit_id: 96_301, attack_range: 5, atk: 500)
      melee = CombatTestHelper.create_mob_combatant(unit_id: 96_302, attack_range: 1, atk: 500)

      ranged_before = seeded_damage(ranged, defender)
      melee_before = seeded_damage(melee, defender)

      toggle_defensive(CrDefender, crusader.pid, 5)

      ranged_after = seeded_damage(ranged, defender)
      melee_after = seeded_damage(melee, defender)

      assert ranged_after < ranged_before
      assert melee_after == melee_before
    end
  end

  describe "Reflect Shield" do
    test "returns part of a melee mob's damage to it without looping" do
      crusader = start_solo_crusader(9_640, {150, 150}, %{vit: 1})
      mob = spawn_mob(9_641, {151, 150}, hp: 100_000)

      toggle_defensive(CrReflectshield, crusader.pid, 10)

      crusader_hp = current_hp(crusader.pid)
      mob_hp = current_mob_hp(mob.pid)

      assert :ok = Combat.execute_mob_attack(mob_state(mob), crusader.character.id)

      assert eventually(fn -> current_hp(crusader.pid) < crusader_hp end)
      assert eventually(fn -> current_mob_hp(mob.pid) < mob_hp end)

      reflected = mob_hp - current_mob_hp(mob.pid)
      taken = crusader_hp - current_hp(crusader.pid)

      assert reflected > 0
      assert reflected < taken
    end
  end

  describe "Grand Cross" do
    test "full cast: deducts 20% max HP, roots the caster, damages the cross with half self-damage and blinds an undead mob" do
      crusader =
        start_solo_crusader(9_650, {150, 150}, %{max_hp: 2_000, hp: 2_000, max_sp: 200, sp: 200})

      undead = spawn_mob(9_651, {151, 150}, hp: 100_000, race: :undead)

      max_hp = max_hp(crusader.pid)
      cost = div(max_hp * 20, 100)
      mob_hp = current_mob_hp(undead.pid)

      flush_packets()

      simulate_incoming_message(crusader.pid, %SkillCast{
        skill_id: @cr_grandcross,
        level: 10,
        target_id: crusader.character.id
      })

      assert eventually(fn ->
               match?(
                 %{center: {150, 150}, origin: {150, 150}},
                 Enum.find(SkillUnitStorage.all(), &(&1.skill_name == :cr_grandcross))
               )
             end)

      assert_packet_sent_with(GroundSkill, fn packet ->
        assert packet.skill_id == @cr_grandcross
        assert packet.src_id == crusader.character.id
        assert packet.level == 10
        assert packet.x == 150
        assert packet.y == 150
      end)

      assert eventually(fn -> current_hp(crusader.pid) <= max_hp - cost end, 6_000)

      refute StatusInterpreter.can_move?(:player, crusader.character.id)

      post_cost_hp = current_hp(crusader.pid)
      assert eventually(fn -> current_hp(crusader.pid) < post_cost_hp end)
      assert eventually(fn -> current_mob_hp(undead.pid) < mob_hp end)
      assert eventually(fn -> StatusStorage.has_status?(:mob, undead.unit_id, :sc_blind) end)
    end
  end

  defp devoted_pair(opts \\ []) do
    %{crusader: crusader, devotee: devotee} = pair = party_pair(opts)

    simulate_incoming_message(crusader.pid, %SkillCast{
      skill_id: @cr_devotion,
      level: 1,
      target_id: devotee.character.id
    })

    assert eventually(fn ->
             StatusStorage.has_status?(:player, devotee.character.id, :sc_devotion) and
               DevotedBy.linked?(crusader.character.id, devotee.character.id)
           end)

    pair
  end

  defp party_pair(opts \\ []) do
    crusader_char =
      insert_character(
        "crusader",
        Map.merge(
          %{
            class: @crusader_class,
            base_level: 55,
            max_hp: 5_000,
            hp: 5_000,
            max_sp: 500,
            sp: 500,
            learned_skills: %{Integer.to_string(@cr_devotion) => 5}
          },
          Keyword.get(opts, :crusader_attrs, %{})
        )
      )

    {:ok, _state} = PartyManager.create("Templars#{crusader_char.id}", crusader_char)
    party_id = Repo.get(Character, crusader_char.id).party_id

    devotee_char =
      insert_character(
        "devotee",
        Map.merge(
          %{class: 0, base_level: 50, vit: 1, max_hp: 5_000, hp: 5_000},
          Keyword.get(opts, :devotee_attrs, %{})
        )
      )

    {:ok, _state} = PartyManager.add_member(party_id, devotee_char)

    crusader = start_session(Repo.get(Character, crusader_char.id), {152, 150})
    devotee = start_session(Repo.get(Character, devotee_char.id), {150, 150})

    %{crusader: crusader, devotee: devotee, party_id: party_id}
  end

  defp start_solo_crusader(id, position, overrides \\ %{}) do
    character =
      insert_character(
        "solocru#{id}",
        Map.merge(
          %{
            class: @crusader_class,
            base_level: 55,
            max_hp: 5_000,
            hp: 5_000,
            max_sp: 500,
            sp: 500,
            learned_skills: %{Integer.to_string(@cr_grandcross) => 10}
          },
          overrides
        )
      )

    start_session(character, position)
  end

  # Applies a Devotion link with a custom duration through the same interpreter
  # primitives `CrDevotion.cast/4` uses, so the expiry cascade can be observed
  # without waiting the skill's fixed 30s.
  defp link_devotion(crusader_id, devotee_id, duration) do
    link_id = make_ref()

    :ok =
      StatusInterpreter.apply_status(:player, devotee_id, :sc_devotion,
        caster_id: crusader_id,
        duration: duration,
        state: %{peer: {:player, crusader_id}, link_id: link_id, range: 7}
      )

    :ok = DevotedBy.link(crusader_id, devotee_id, link_id)
  end

  defp toggle_defensive(module, crusader_pid, level) do
    state = get_player_state(crusader_pid)
    assert {:ok, _caster} = module.cast(state, :self, level, module.definition())
  end

  defp seeded_damage(attacker, defender) do
    :rand.seed(:exsss, {7, 11, 13})

    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    damage
  end

  defp start_session(character, {x, y}) do
    session = start_player_session(character: character, map_name: @map, position: {x, y})
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp spawn_mob(unit_id, {x, y}, opts \\ []) do
    mob =
      start_mob_session(
        Keyword.merge(
          [unit_id: unit_id, map_name: @map, position: {x, y}, max_hp: 5_000, hp: 5_000],
          opts
        )
      )

    on_exit(fn -> end_mob_session(mob) end)
    mob
  end

  defp insert_character(prefix, overrides) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "#{prefix}#{uniq}",
        userid: "#{prefix}#{uniq}",
        user_pass: "password",
        email: "#{prefix}#{uniq}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "#{prefix}#{uniq}",
          class: 0,
          base_level: 50,
          job_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          max_hp: 5_000,
          hp: 5_000,
          max_sp: 500,
          sp: 500,
          last_map: @map,
          last_x: 150,
          last_y: 150,
          save_map: @map,
          save_x: 150,
          save_y: 150
        },
        overrides
      )

    {:ok, character} =
      %Character{}
      |> Character.changeset(attrs)
      |> Repo.insert()

    character
  end

  defp mob_state(mob), do: get_mob_state(mob.pid)
  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp
  defp max_hp(pid), do: get_player_state(pid).stats.derived_stats.max_hp
  defp current_mob_hp(pid), do: get_mob_state(pid).hp
end
