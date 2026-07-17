defmodule Aesir.ZoneServer.Integration.AcolyteStage2Test do
  @moduledoc """
  End-to-end coverage that the Acolyte Stage 2/3 kit is playable on the real
  stack. Drives the real subsystems (skill learning, skill modules, the unified
  damage calculator, status interpreter/storage, ground skill-units, the warp
  handler and player sessions); only the network transport and the empty test
  map cache are faked.

    1. Demon Bane — a real combatant built from a session that learned
       AL_DEMONBANE deals more physical damage to an undead/demon mob than a
       fresh acolyte, through the real `DamageCalculator` and the mob's DEF.
    2. Divine Protection — a real combatant that learned AL_DP takes less
       physical damage from an undead/demon attacker (added soft DEF).
    3. Aqua Benedicta — casting AL_HOLYWATER on a water cell commits a Holy
       Water (523) to the caster's inventory and emits the commit-path
       `ItemAdded`; off water `validate/4` rejects with `{:error, :not_on_water}`.
    4. Pneuma — an occupant of a placed 3x3 Pneuma field gets `:sc_pneuma`, whose
       real `absorb_damage` blocks a long-ranged physical hit while melee and
       magic pass through.
    5. Teleport — the real `cast/4` -> `pending_warp` -> `commit_cast` ->
       `WarpHandler.warp` path relocates the caster (lv1 random cell, lv2 save
       point).
    6. Tree gates — the live learning flow enforces AL_DP/AL_DEMONBANE
       prerequisites that the catalogued passives now activate.

  ## Scoping

  - The combat checks drive `DamageCalculator.calculate_damage/3` (the core of
    the real combat path, where Demon Bane / Divine Protection apply) with
    combatants produced by the production `to_combatant` builder, rather than the
    full `Combat.execute_attack` hit roll. `:rand` is seeded identically per pair
    so the only difference is the modifier under test (player weapon variance /
    mob attack roll would otherwise mask the delta).
  - Teleport and the on-water Aqua Benedicta cast run through the real session
    cast/commit path; the empty test map cache means `MapCache`/`MapData` are
    stubbed and `Mimic.allow`-ed into the session process (mirrors `warp_test`),
    but the warp and inventory commit themselves are real.
  - The Pneuma field is placed via the real `Skill.Unit.place/4` and its real
    `on_interval`, then the real `StatusInterpreter.absorb_damage/4` (the same
    call `Combat.apply_unit_damage` makes) is asserted directly, to avoid racing
    the 100ms ground-unit tick.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.LearnSkillResult
  alias Aesir.Net.MapMove
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skills.AlHolywater
  alias Aesir.ZoneServer.Mmo.Skills.AlPneuma
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # rAthena class id for the 1st-class Acolyte; PlayerState derives job_id from it.
  @acolyte_class 4

  # SkillLearningHandler reject code for an unmet prerequisite.
  @missing_prerequisite 4

  @holy_water_id 523

  describe "Demon Bane raises real physical damage vs undead/demon" do
    test "a learned Demon Bane attacker out-damages a fresh one, reduced through DEF" do
      dp = catalog_id(:al_dp)
      demonbane = catalog_id(:al_demonbane)

      bane =
        start_player_session(
          id: 9401,
          name: "Bane",
          class: @acolyte_class,
          base_level: 60,
          str: 40,
          dex: 30,
          skill_point: 20
        )

      plain =
        start_player_session(
          id: 9402,
          name: "Plain",
          class: @acolyte_class,
          base_level: 60,
          str: 40,
          dex: 30
        )

      # Real learning flow: Demon Bane is gated behind Divine Protection lv3.
      for _ <- 1..3, do: learn(bane.pid, dp)
      for _ <- 1..5, do: learn(bane.pid, demonbane)

      bane_combatant = combatant(bane.pid)
      plain_combatant = combatant(plain.pid)

      assert bane_combatant.demon_bane_level == 5
      assert plain_combatant.demon_bane_level == 0

      undead =
        CombatTestHelper.create_mob_combatant(
          unit_id: 94_050,
          race: :undead,
          def: 30,
          base_level: 40
        )

      assert seeded_physical_damage(bane_combatant, undead) >
               seeded_physical_damage(plain_combatant, undead)

      # Against a non-undead/demon target the bonus is absent, so both are equal.
      brute =
        CombatTestHelper.create_mob_combatant(
          unit_id: 94_051,
          race: :brute,
          def: 30,
          base_level: 40
        )

      assert seeded_physical_damage(bane_combatant, brute) ==
               seeded_physical_damage(plain_combatant, brute)
    end
  end

  describe "Divine Protection reduces real physical damage from undead/demon" do
    test "a learned DP defender takes less from an undead attacker, via added soft DEF" do
      dp = catalog_id(:al_dp)

      warded =
        start_player_session(
          id: 9411,
          name: "Warded",
          class: @acolyte_class,
          base_level: 60,
          vit: 30,
          skill_point: 20
        )

      bare =
        start_player_session(
          id: 9412,
          name: "Bare",
          class: @acolyte_class,
          base_level: 60,
          vit: 30
        )

      for _ <- 1..5, do: learn(warded.pid, dp)

      warded_combatant = combatant(warded.pid)
      bare_combatant = combatant(bare.pid)

      assert warded_combatant.divine_protection_level == 5
      assert bare_combatant.divine_protection_level == 0

      undead_attacker =
        CombatTestHelper.create_mob_combatant(
          unit_id: 94_060,
          race: :undead,
          atk: 300,
          base_level: 50
        )

      assert seeded_physical_damage(undead_attacker, warded_combatant) <
               seeded_physical_damage(undead_attacker, bare_combatant)

      # A non-undead/demon attacker triggers no Divine Protection, so both match.
      brute_attacker =
        CombatTestHelper.create_mob_combatant(
          unit_id: 94_061,
          race: :brute,
          atk: 300,
          base_level: 50
        )

      assert seeded_physical_damage(brute_attacker, warded_combatant) ==
               seeded_physical_damage(brute_attacker, bare_combatant)
    end
  end

  describe "Aqua Benedicta (AL_HOLYWATER)" do
    test "casting on a water cell commits a Holy Water and notifies the client" do
      holywater = catalog_id(:al_holywater)

      # Aqua Benedicta is the one new skill that persists (an inventory row with a
      # FK to characters), so its caster is a real DB-backed character; everything
      # downstream (in-memory add, DB persist, commit-path notify) runs for real.
      character = persist_acolyte("priestess")

      caster =
        start_player_session(character: character, map_name: "prontera", position: {150, 150})

      learn(caster.pid, holywater)
      flush_packets()

      # The empty test map cache cannot report a water cell, so the two map
      # collaborators `validate/4` consults are stubbed into the session process.
      stub(MapCache, :get, fn _map -> {:ok, %MapData{name: "prontera"}} end)
      stub(MapData, :check_cell, fn _map, _x, _y, :chk_water -> true end)
      Mimic.allow(MapCache, self(), caster.pid)
      Mimic.allow(MapData, self(), caster.pid)

      simulate_incoming_message(caster.pid, %SkillCast{
        skill_id: holywater,
        level: 1,
        target_id: caster.character.id
      })

      assert_receive {:packet_sent, %ItemAdded{nameid: @holy_water_id, amount: 1}, _}, 2_000

      inventory = get_player_state(caster.pid).inventory
      assert Enum.any?(inventory, fn {_index, item} -> item.nameid == @holy_water_id end)
    end

    test "off a water cell the cast is rejected by validate/4" do
      holywater = catalog_id(:al_holywater)
      {:ok, definition} = Catalog.by_id(holywater)

      caster =
        start_player_session(id: 9422, name: "Dryad", class: @acolyte_class, base_level: 60)

      state = get_player_state(caster.pid)

      stub(MapCache, :get, fn _map -> {:ok, %MapData{name: "prontera"}} end)
      stub(MapData, :check_cell, fn _map, _x, _y, :chk_water -> false end)

      assert {:error, :not_on_water} = AlHolywater.validate(state, :self, 1, definition)
    end
  end

  describe "Pneuma blocks long-ranged physical hits on its field" do
    test "an occupant absorbs ranged physical but melee and magic pass through" do
      # An isolated cell well away from the default test positions, so the
      # field's occupant scan only touches this test's own units (the shared
      # spatial index retains stray entities across integration tests).
      field = {290, 290}

      caster =
        start_player_session(
          id: 9431,
          name: "Cleric",
          class: @acolyte_class,
          base_level: 60,
          position: field
        )

      victim =
        start_player_session(
          id: 9432,
          name: "Guarded",
          class: @acolyte_class,
          base_level: 60,
          position: {291, 290}
        )

      caster_state = get_player_state(caster.pid)
      {:ok, group} = SkillUnit.place(caster_state, :al_pneuma, 1, field)

      on_exit(fn ->
        SkillUnit.destroy(group.group_id)
        StatusStorage.remove_status(:player, caster.character.id, :sc_pneuma)
        StatusStorage.remove_status(:player, victim.character.id, :sc_pneuma)
      end)

      # The field's real tick grants sc_pneuma to occupants of its 3x3 footprint.
      assert {:ok, _group} = AlPneuma.on_interval(group, System.monotonic_time(:millisecond))
      assert StatusStorage.has_status?(:player, victim.character.id, :sc_pneuma)

      ranged_physical = %{dmg_type: :physical, is_short: false, element: :neutral}
      melee_physical = %{dmg_type: :physical, is_short: true, element: :neutral}
      ranged_magic = %{dmg_type: :magic, is_short: false, element: :holy}

      victim_id = victim.character.id

      assert StatusInterpreter.absorb_damage(:player, victim_id, 500, ranged_physical) == 0
      assert StatusInterpreter.absorb_damage(:player, victim_id, 500, melee_physical) == 500
      assert StatusInterpreter.absorb_damage(:player, victim_id, 500, ranged_magic) == 500
    end
  end

  describe "Teleport relocates the caster via the real warp path" do
    test "lv1 relocates to a (stubbed-random) walkable cell on the current map" do
      teleport = catalog_id(:al_teleport)
      ruwach = catalog_id(:al_ruwach)

      player =
        start_player_session(
          id: 9441,
          name: "Blink",
          class: @acolyte_class,
          base_level: 60,
          position: {150, 150},
          skill_point: 5
        )

      learn(player.pid, ruwach)
      learn(player.pid, teleport)
      flush_packets()

      # The warp path is real; only the map cache is faked. `Cell.random_traversable`
      # picks a random in-bounds cell via `:rand.uniform(xs/ys)`, so a 1x1 map makes
      # the destination deterministic at {0, 0} with every cell stubbed walkable.
      stub(MapCache, :get, fn _map -> {:ok, %MapData{name: "prontera", xs: 1, ys: 1}} end)
      stub(MapData, :walkable?, fn _map, _x, _y -> true end)
      Mimic.allow(MapCache, self(), player.pid)
      Mimic.allow(MapData, self(), player.pid)

      simulate_incoming_message(player.pid, %SkillCast{
        skill_id: teleport,
        level: 1,
        target_id: player.character.id
      })

      assert_receive {:packet_sent, %MapMove{map_name: "prontera", x: 0, y: 0}, _}, 1_000

      state = get_player_state(player.pid)
      assert {state.x, state.y} == {0, 0}
      assert state.map_name == "prontera"
    end

    test "lv2 relocates to the save point" do
      teleport = catalog_id(:al_teleport)
      ruwach = catalog_id(:al_ruwach)

      player =
        start_player_session(
          id: 9442,
          name: "Recall",
          class: @acolyte_class,
          base_level: 60,
          position: {180, 200},
          skill_point: 5
        )

      learn(player.pid, ruwach)
      for _ <- 1..2, do: learn(player.pid, teleport)
      flush_packets()

      stub(MapCache, :get, fn _map -> {:ok, %MapData{name: "prontera"}} end)
      stub(MapData, :walkable?, fn _map, _x, _y -> true end)
      Mimic.allow(MapCache, self(), player.pid)
      Mimic.allow(MapData, self(), player.pid)

      saved = get_player_state(player.pid)
      assert {saved.save_map, saved.save_x, saved.save_y} == {"prontera", 150, 150}

      simulate_incoming_message(player.pid, %SkillCast{
        skill_id: teleport,
        level: 2,
        target_id: player.character.id
      })

      assert_receive {:packet_sent, %MapMove{map_name: "prontera", x: 150, y: 150}, _}, 1_000

      state = get_player_state(player.pid)
      assert {state.x, state.y} == {150, 150}
    end
  end

  describe "Acolyte tree gates enforce in the live learning flow" do
    test "DP is learnable with no prereqs; Demon Bane gates behind DP lv3" do
      dp = catalog_id(:al_dp)
      demonbane = catalog_id(:al_demonbane)

      player =
        start_player_session(
          id: 9451,
          name: "Pupil",
          class: @acolyte_class,
          base_level: 60,
          skill_point: 10
        )

      flush_packets()

      # Demon Bane needs DP lv3; with nothing learned the request is rejected and
      # no skill point is spent.
      simulate_incoming_message(player.pid, %LearnSkill{skill_id: demonbane})

      assert_receive {:packet_sent,
                      %LearnSkillResult{
                        skill_id: ^demonbane,
                        ok: false,
                        reason: @missing_prerequisite
                      }, _},
                     1_000

      progression = get_player_state(player.pid).stats.progression
      assert progression.learned_skills == %{}
      assert progression.skill_point == 10

      # Divine Protection has no prerequisite; raise it to 3, then Demon Bane unlocks.
      for _ <- 1..3, do: learn(player.pid, dp)
      learn(player.pid, demonbane)

      progression = get_player_state(player.pid).stats.progression
      assert progression.learned_skills == %{dp => 3, demonbane => 1}
      assert progression.skill_point == 6
    end
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  # Inserts a DB-backed Acolyte (account + character) so inventory persistence
  # (a real FK to characters) succeeds end-to-end. The sandbox rolls it back.
  defp persist_acolyte(name) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: name,
        user_pass: "password",
        sex: "M",
        email: "#{name}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: name,
        class: @acolyte_class,
        base_level: 60,
        job_level: 50,
        int: 60,
        dex: 80,
        max_hp: 500,
        hp: 500,
        max_sp: 200,
        sp: 200,
        skill_point: 5,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      }
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp combatant(player_pid), do: PlayerState.to_combatant(get_player_state(player_pid))

  # Runs the real damage calculator with a fixed RNG state so the only delta
  # between a pair of calls is the race modifier under test (player weapon
  # variance / mob attack roll are otherwise random). Skips criticals, which
  # skills do not roll, to keep the comparison purely on the modifier.
  defp seeded_physical_damage(attacker, defender) do
    :rand.seed(:exsss, {7, 11, 13})

    {:ok, %{damage: damage}} =
      DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

    damage
  end

  defp learn(player_pid, skill_id) do
    simulate_incoming_message(player_pid, %LearnSkill{skill_id: skill_id})
    # The enriched SkillList is the success ack; waiting on it serializes the
    # async learn cast before the next request/read.
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end
end
