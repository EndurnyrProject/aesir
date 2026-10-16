defmodule Aesir.ZoneServer.Unit.Mob.MobStateTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  defmodule TestAtkBuff do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mob_atk_buff,
      no_dispel: false,
      no_clear_buff: false,
      properties: [:buff]

    @impl true
    def modifiers(instance, _context), do: %{atk: instance.val1}
  end

  defmodule TestBatkBuff do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mob_batk_buff,
      no_dispel: false,
      no_clear_buff: false,
      properties: [:buff]

    @impl true
    def modifiers(_instance, _context), do: %{batk: 7}
  end

  defmodule TestFleeRate do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mob_flee_rate,
      no_dispel: false,
      no_clear_buff: false,
      properties: [:debuff]

    @impl true
    def modifiers(_instance, _context), do: %{flee_rate: -50}
  end

  defmodule TestMagicRates do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mob_magic_rates,
      no_dispel: false,
      no_clear_buff: false,
      properties: [:debuff]

    @impl true
    def modifiers(_instance, _context), do: %{matk_rate: 100, mdef2_rate: -60}
  end

  defp build_mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      atk2: 70,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "attack motion, attack delay and rest" do
    defp motion_state(motion, delay, rate) do
      state = build_mob_state()

      %{
        state
        | mob_data: %{state.mob_data | attack_motion: motion, attack_delay: delay},
          stat_bonus: %{aspd_rate: rate}
      }
    end

    test "the motion scales by the rate and stays between 100 and 8000" do
      assert MobState.get_attack_motion(motion_state(500, 1_200, 20)) == 400
      assert MobState.get_attack_motion(motion_state(110, 1_200, 50)) == 100
      assert MobState.get_attack_motion(motion_state(9_000, 9_000, 0)) == 8_000
    end

    test "the delay only ever shortens and never drops below the motion" do
      assert MobState.get_attack_delay(motion_state(500, 1_200, 25)) == 900
      assert MobState.get_attack_delay(motion_state(500, 1_200, -50)) == 1_200
      assert MobState.get_attack_delay(motion_state(1_000, 800, 0)) == 1_000
    end

    test "a rest lasts the motion and never shortens a longer one" do
      state = motion_state(500, 1_200, 0)
      assert MobState.thinking?(state, 0)

      rested = MobState.rest(state, 10_000)
      refute MobState.thinking?(rested, 10_499)
      assert MobState.thinking?(rested, 10_500)

      assert MobState.rest(%{rested | next_think_at: 20_000}, 10_000).next_think_at == 20_000
    end
  end

  describe "stolen_from" do
    test "a freshly built mob state is not stolen from" do
      state = build_mob_state()

      assert state.stolen_from == false
    end

    test "mark_stolen/1 sets the stolen_from flag to true" do
      state = build_mob_state()

      updated = MobState.mark_stolen(state)

      assert updated.stolen_from == true
    end
  end

  describe "initiated_by_self?" do
    test "a freshly built mob state did not initiate combat itself" do
      state = build_mob_state()

      assert state.initiated_by_self? == false
    end

    test "set_initiated/2 toggles the initiated_by_self? flag" do
      state = build_mob_state()

      assert MobState.set_initiated(state, true).initiated_by_self? == true
      assert MobState.set_initiated(state, false).initiated_by_self? == false
    end
  end

  describe "walk delays" do
    test "block movement until their monotonic expiry without shortening an existing delay" do
      state = build_mob_state()
      delayed = MobState.apply_walk_delay(state, 1_600, 10_000)
      extended = MobState.apply_walk_delay(delayed, 500, 10_500)

      assert extended.walk_delay_until == 11_600
      assert MobState.walk_delayed?(extended, 11_599)
      refute MobState.walk_delayed?(extended, 11_600)
    end

    test "the zero sentinel does not block a negative monotonic clock" do
      state = build_mob_state()
      now = System.monotonic_time(:millisecond)

      refute MobState.walk_delayed?(state, now)

      delayed = MobState.apply_walk_delay(state, 1_600, now)
      assert delayed.walk_delay_until == now + 1_600
      assert MobState.walk_delayed?(delayed, now)
    end
  end

  describe "hit_type/2 and hit_skill/2" do
    test "record the killing attack type and skill per attacker" do
      state =
        build_mob_state()
        |> MobState.note_hit_type(42, :magic, 14)
        |> MobState.note_hit_type(99, :melee, nil)

      assert {MobState.hit_type(state, 42), MobState.hit_skill(state, 42)} == {:magic, 14}
      assert {MobState.hit_type(state, 99), MobState.hit_skill(state, 99)} == {:melee, nil}
      assert {MobState.hit_type(state, 7), MobState.hit_skill(state, 7)} == {:other, nil}
    end
  end

  describe "attacked events" do
    test "set_attacked/3 stores the attacker and keeps the norm attacker of a non-norm hit" do
      state = build_mob_state()

      norm = MobState.set_attacked(state, {:player, 1}, true)
      assert {norm.attacked_ref, norm.norm_attacked_ref} == {{:player, 1}, {:player, 1}}

      later = MobState.set_attacked(norm, {:player, 2}, false)
      assert {later.attacked_ref, later.norm_attacked_ref} == {{:player, 2}, {:player, 1}}

      cleared = MobState.clear_attacked(later)
      assert {cleared.attacked_ref, cleared.norm_attacked_ref} == {nil, nil}
    end
  end

  describe "leaving the self-initiated skill state" do
    test "an attacked mob keeps its skill state until its next state change or attack" do
      angry = %{build_mob_state() | ai_state: :combat, initiated_by_self?: true}
      attacked = MobState.set_attacked(angry, {:player, 1}, false)

      assert MobState.skill_state(attacked) == :angry
      assert MobState.skill_state(MobState.settle_skill_state(attacked)) == :berserk
      assert MobState.skill_state(MobState.set_ai_state(attacked, :chase)) == :rush
      assert MobState.skill_state(MobState.set_ai_state(angry, :chase)) == :follow
      assert MobState.settle_skill_state(angry) == angry
    end
  end

  describe "skill cooldowns" do
    test "a freshly built mob state has no skill cooldowns" do
      state = build_mob_state()

      assert state.skill_cooldowns == %{}
    end

    test "a skill with no cooldown entry is ready" do
      state = build_mob_state()

      assert MobState.skill_ready?(state, 1, 0)
    end

    test "put_skill_cooldown/3 gates the skill until now reaches expires_at" do
      state =
        build_mob_state()
        |> MobState.put_skill_cooldown(1, 5_000)

      assert state.skill_cooldowns == %{1 => 5_000}
      refute MobState.skill_ready?(state, 1, 4_999)
      assert MobState.skill_ready?(state, 1, 5_000)
      assert MobState.skill_ready?(state, 1, 5_001)
    end
  end

  describe "casting" do
    test "a freshly built mob state is not casting" do
      state = build_mob_state()

      assert state.casting == nil
    end

    test "set_casting/2 and clear_casting/1 round-trip" do
      cast = %{skill: "NPC_FIREATTACK", target: 42, complete_at: 5_000}
      state = build_mob_state()

      set = MobState.set_casting(state, cast)
      assert set.casting == cast

      assert MobState.clear_casting(set).casting == nil
    end
  end

  describe "master link" do
    test "a freshly built mob state has no master" do
      state = build_mob_state()

      assert state.master_id == nil
    end

    test "set_master/2 sets the master instance id" do
      state = build_mob_state()

      assert MobState.set_master(state, 99).master_id == 99
    end
  end

  describe "to_combatant/1 attack bounds" do
    defp bounded(atk2 \\ 70) do
      state = build_mob_state()
      %{state | mob_data: %{state.mob_data | atk2: atk2}}
    end

    defp register(state) do
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
      state
    end

    @tag game_mode: :pre_renewal
    test "a classic monster rolls Attack to Attack2 with no status ATK and INT-based MATK" do
      stats = MobState.to_combatant(bounded()).combat_stats

      assert {stats.atk_min, stats.atk_max, stats.atk} == {50, 70, 0}
      # INT 20: 20 + (20 / 7)^2 .. 20 + (20 / 5)^2
      assert {stats.matk_min, stats.matk_max} == {24, 36}
    end

    @tag game_mode: :renewal
    test "a renewal monster rolls 80 to 120 percent plus STR and level, MATK from INT, level and MATK" do
      stats = MobState.to_combatant(bounded()).combat_stats

      assert {stats.atk_min, stats.atk_max, stats.atk} == {40, 60, 65}
      # 20 + 25 + 60 * 70 / 100 .. 20 + 25 + 60 * 130 / 100
      assert {stats.matk_min, stats.matk_max} == {87, 123}
    end

    @tag game_mode: :pre_renewal
    test "a classic Attack2 below Attack rolls Attack2 only" do
      stats = MobState.to_combatant(bounded(30)).combat_stats

      assert {stats.atk_min, stats.atk_max} == {30, 30}
    end

    @tag game_mode: :pre_renewal
    test "Guard Up raises both classic bounds and status ATK" do
      stats = MobState.to_combatant(%{bounded() | stat_bonus: %{atk: 10}}).combat_stats

      assert {stats.atk_min, stats.atk_max, stats.atk} == {60, 80, 10}
    end

    @tag game_mode: :pre_renewal
    test "a classic guardian's status ATK takes status ATK modifiers, a plain monster's does not" do
      Registry.register_module(TestBatkBuff)
      plain = register(bounded())
      guardian = register(%{bounded() | instance_id: 2, stat_bonus: %{atk: 10}})

      for state <- [plain, guardian],
          do: StatusStorage.apply_status(:mob, state.instance_id, TestBatkBuff.id())

      assert MobState.to_combatant(plain).combat_stats.atk == 0
      assert MobState.to_combatant(guardian).combat_stats.atk == 10 + 7
    end

    @tag game_mode: :renewal
    test "Guard Up raises both renewal bounds after the variance and status ATK" do
      stats = MobState.to_combatant(%{bounded() | stat_bonus: %{atk: 10}}).combat_stats

      assert {stats.atk_min, stats.atk_max, stats.atk} == {50, 70, 75}
    end

    @tag game_mode: :renewal
    test "renewal Mystical Amplification scales the MATK bounds before flat MATK" do
      state = register(bounded())
      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_magicpower, val1: 10)
      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_impositio, val2: 5)

      stats = MobState.to_combatant(state).combat_stats

      assert {stats.matk_min, stats.matk_max} ==
               {87 + div(87 * 50, 100) + 5, 123 + div(123 * 50, 100) + 5}
    end

    test "a MATK rate is a player bonus and leaves a monster's MATK alone" do
      state = register(bounded())
      Registry.register_module(TestMagicRates)
      baseline = MobState.to_combatant(state).combat_stats

      :ok = StatusStorage.apply_status(:mob, state.instance_id, TestMagicRates.id())
      rated = MobState.to_combatant(state).combat_stats

      assert {rated.matk_min, rated.matk_max} == {baseline.matk_min, baseline.matk_max}
    end
  end

  describe "to_combatant/1 magic stats" do
    test "carries the maximum MATK as matk and hard mdef in combat_stats" do
      combatant = MobState.to_combatant(build_mob_state())

      assert combatant.combat_stats.matk == combatant.combat_stats.matk_max
      assert combatant.combat_stats.mdef == 10
    end

    test "Heal's MATK band is the base band plus the database MATK, without status MATK" do
      state = register(build_mob_state())
      :ok = StatusStorage.apply_status(:mob, state.instance_id, :sc_magicpower, val1: 10)
      stats = MobState.to_combatant(state).combat_stats
      base = MobState.to_combatant(%{state | instance_id: 99}).combat_stats
      matk = state.mob_data.matk

      assert {stats.heal_matk_min, stats.heal_matk_max} ==
               {base.matk_min + matk, base.matk_max + matk}
    end

    @tag game_mode: :renewal
    test "Renewal soft_mdef uses non-player level scaling" do
      assert MobState.to_combatant(build_mob_state()).combat_stats.soft_mdef == 11

      base = build_mob_state()
      %MobDefinition{} = base_mob_data = base.mob_data

      mob_data = %MobDefinition{
        base_mob_data
        | level: 50,
          stats: %{base_mob_data.stats | int: 30}
      }

      state = %MobState{base | mob_data: mob_data}

      combatant = MobState.to_combatant(state)

      assert combatant.combat_stats.soft_mdef == 20
    end

    @tag game_mode: :pre_renewal
    test "classic soft_mdef uses INT and half VIT" do
      base = build_mob_state()
      assert MobState.to_combatant(base).combat_stats.soft_mdef == 45

      mob_data = %{base.mob_data | level: 50, stats: %{base.mob_data.stats | int: 30}}
      assert MobState.to_combatant(%{base | mob_data: mob_data}).combat_stats.soft_mdef == 55
    end

    test "combatants do not gain natural perfect dodge from mob LUK" do
      assert MobState.to_combatant(build_mob_state()).combat_stats.perfect_dodge == 0
    end
  end

  describe "to_combatant/1 relationships" do
    test "an owned mob keeps mob roots and hostility" do
      owned_mob = %MobState{build_mob_state() | owner_player_id: 10} |> MobState.to_combatant()
      owner = Combatant.new!(%{unit_type: :player, unit_id: 10})

      assert owned_mob.unit_type == :mob
      assert owned_mob.social_root == {:mob, owned_mob.unit_id}
      assert owned_mob.reward_root == nil
      assert Relationship.enemy?(owner, owned_mob)
      assert Relationship.enemy?(owned_mob, owner)
    end
  end

  describe "to_combatant/1 attack delay" do
    test "carries the mob's attack_delay as attack_delay_ms" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.attack_delay_ms == state.mob_data.attack_delay
    end
  end

  describe "to_combatant/1 passive skill levels" do
    test "mob combatant passive skill levels are 0" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.divine_protection_level == 0
      assert combatant.demon_bane_level == 0
      assert combatant.dragonology_level == 0
      assert combatant.skin_temper_level == 0
    end
  end

  describe "to_combatant/1 race2" do
    test "carries the mob's secondary groups" do
      base = build_mob_state()
      state = %MobState{base | mob_data: %{base.mob_data | race_groups: [:golem]}}

      assert MobState.to_combatant(state).race2 == [:golem]
    end
  end

  describe "to_combatant/1 class and equip_modifiers" do
    test "a normal mob (no :boss mode) combatant has class :normal" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.class == :normal
    end

    test "a mob with the :boss mode has combatant class :boss" do
      base = build_mob_state()
      mob_data = %{base.mob_data | modes: [:boss]}
      state = %MobState{base | mob_data: mob_data}

      combatant = MobState.to_combatant(state)

      assert combatant.class == :boss
    end

    test "mob combatant equip_modifiers is always an empty map" do
      state = build_mob_state()

      combatant = MobState.to_combatant(state)

      assert combatant.equip_modifiers == %{}
    end
  end

  describe "to_combatant/1 status immunity" do
    test "an ordinary mob combatant is not status immune" do
      combatant = build_mob_state() |> MobState.to_combatant()

      refute combatant.status_immune
    end

    test "a mob with the :status_immune mode exposes immunity on its combatant" do
      base = build_mob_state()
      state = %MobState{base | mob_data: %{base.mob_data | modes: [:status_immune]}}

      assert MobState.to_combatant(state).status_immune
    end
  end

  describe "to_combatant/1 status modifiers" do
    test "flee_rate halves final mob FLEE" do
      state = build_mob_state()
      Registry.register_module(TestFleeRate)
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
      baseline = MobState.to_combatant(state).combat_stats.flee

      :ok = StatusStorage.apply_status(:mob, state.instance_id, TestFleeRate.id())
      assert MobState.to_combatant(state).combat_stats.flee == div(baseline, 2)
    end

    test "mdef2_rate scales soft MDEF" do
      state = register(build_mob_state())
      Registry.register_module(TestMagicRates)
      baseline = MobState.to_combatant(state).combat_stats

      :ok = StatusStorage.apply_status(:mob, state.instance_id, TestMagicRates.id())
      rated = MobState.to_combatant(state).combat_stats

      assert rated.soft_mdef == div(baseline.soft_mdef * 40, 100)
    end

    test "an :atk status bonus is a player bonus and leaves a monster's attack alone" do
      state = register(build_mob_state())
      Registry.register_module(TestAtkBuff)
      baseline = MobState.to_combatant(state).combat_stats

      StatusStorage.apply_status(:mob, state.instance_id, :sc_test_mob_atk_buff, val1: 30)
      buffed = MobState.to_combatant(state).combat_stats

      assert {buffed.atk, buffed.atk_min, buffed.atk_max} ==
               {baseline.atk, baseline.atk_min, baseline.atk_max}
    end

    test "with no active statuses, to_combatant/1 is unchanged from the un-buffed values" do
      state = register(build_mob_state())

      combatant = MobState.to_combatant(state)
      unbuffed = MobState.to_combatant(%{state | instance_id: 99})

      assert combatant.combat_stats == unbuffed.combat_stats
      assert combatant.combat_stats.def == 25
      assert combatant.base_stats.str == 40
      assert combatant.beast_bane_level == 0
    end
  end

  describe "get_stats/1 status modifiers" do
    test "with no active statuses, get_stats/1 is unchanged from the un-buffed values" do
      state = build_mob_state()

      stats = MobState.get_stats(state)

      assert stats.atk == 50
      assert stats.def == 25
      assert stats.str == 40
    end
  end

  describe "sc_elementalchange defense element override" do
    test "to_combatant/1 uses the base element with no override present" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      combatant = MobState.to_combatant(state)

      assert combatant.element == {:neutral, 1}
    end

    test "get_element/1 returns the base element with no override present" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      assert MobState.get_element(state) == {:neutral, 1}
    end

    test "to_combatant/1 folds an active override into the element field" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 2, val2: 3)

      combatant = MobState.to_combatant(state)

      assert combatant.element == {:fire, 2}
    end

    test "get_element/1 folds an active override" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 2, val2: 3)

      assert MobState.get_element(state) == {:fire, 2}
    end

    test "the override never changes the mob's own attack element" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 2, val2: 3)

      combatant = MobState.to_combatant(state)

      assert combatant.weapon.element == :neutral
      assert combatant.weapon.element == elem(state.mob_data.element, 0)
    end

    test "re-applying the status replaces the override instead of stacking" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 1, val2: 3)
      StatusStorage.apply_status(:mob, state.instance_id, :sc_elementalchange, val1: 1, val2: 6)

      combatant = MobState.to_combatant(state)

      assert combatant.element == {:holy, 1}
    end

    test "a mob with an active status but no override on the mob keeps the base element" do
      state = build_mob_state()
      Registry.register_module(TestAtkBuff)
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      StatusStorage.apply_status(:mob, state.instance_id, :sc_test_mob_atk_buff, val1: 30)

      assert MobState.get_element(state) == {:neutral, 1}
      assert MobState.to_combatant(state).element == {:neutral, 1}
    end
  end

  describe "hp floor" do
    test "new/6 floors a zero-HP definition to 1 across hp, max_hp and base_max_hp" do
      mob_data = %{build_mob_state().mob_data | hp: 0}

      spawn_ref = %MobSpawn{
        mob: 1001,
        amount: 1,
        respawn_time: 5000,
        spawn_area: %SpawnArea{x: 100, y: 100}
      }

      state = MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)

      assert state.hp == 1
      assert state.max_hp == 1
      assert state.base_max_hp == 1
      assert MobState.living?(state)
    end
  end

  describe "configure_summon/2 stat_bonus" do
    test "absent stat_bonus leaves def/mdef unchanged" do
      state = build_mob_state()
      combatant = state |> MobState.configure_summon([]) |> MobState.to_combatant()

      assert combatant.combat_stats.def == 25
      assert combatant.combat_stats.mdef == 10
    end

    test "stat_bonus raises def and mdef by the given flat amount" do
      state = build_mob_state()

      combatant =
        state
        |> MobState.configure_summon(stat_bonus: %{def: 34, mdef: 34})
        |> MobState.to_combatant()

      assert combatant.combat_stats.def == 25 + 34
      assert combatant.combat_stats.mdef == 10 + 34
    end

    test "hp_override still wins over the zero-HP floor" do
      mob_data = %{build_mob_state().mob_data | hp: 0}

      spawn_ref = %MobSpawn{
        mob: 1001,
        amount: 1,
        respawn_time: 5000,
        spawn_area: %SpawnArea{x: 100, y: 100}
      }

      state = MobState.new(1, mob_data, spawn_ref, "prontera", 100, 100)
      configured = MobState.configure_summon(state, hp_override: 500)

      assert configured.hp == 500
      assert configured.max_hp == 500
      assert configured.base_max_hp == 500
    end
  end

  describe "configure_summon/2 guild_id" do
    test "absent guild_id option leaves guild_id at 0" do
      state = build_mob_state()
      configured = MobState.configure_summon(state, [])

      assert configured.guild_id == 0
    end

    test "guild_id option sets the guild_id" do
      state = build_mob_state()
      configured = MobState.configure_summon(state, guild_id: 7)

      assert configured.guild_id == 7
    end

    test "guild_id is exposed on the combatant" do
      state = build_mob_state()
      combatant = state |> MobState.configure_summon(guild_id: 7) |> MobState.to_combatant()

      assert combatant.guild_id == 7
    end

    test "absent guild_id option leaves combatant guild_id at 0" do
      state = build_mob_state()
      combatant = state |> MobState.configure_summon([]) |> MobState.to_combatant()

      assert combatant.guild_id == 0
    end
  end

  describe "to_combatant/1 with atk stat bonus" do
    test "stat_bonus atk raises status ATK and both bounds by the exact amount" do
      base = build_mob_state() |> MobState.configure_summon([]) |> MobState.to_combatant()

      bonus =
        build_mob_state()
        |> MobState.configure_summon(stat_bonus: %{atk: 10})
        |> MobState.to_combatant()

      assert bonus.combat_stats.atk == base.combat_stats.atk + 10
      assert bonus.combat_stats.atk_min == base.combat_stats.atk_min + 10
      assert bonus.combat_stats.atk_max == base.combat_stats.atk_max + 10
    end
  end

  describe "to_combatant/1 attack delay with aspd_rate" do
    test "get_attack_delay returns the mob's base attack_delay with no bonus" do
      state = build_mob_state()

      delay = MobState.get_attack_delay(state)

      assert delay == 1200
    end

    test "aspd_rate bonus reduces attack_delay" do
      state = %{build_mob_state() | stat_bonus: %{aspd_rate: 5}}

      delay = MobState.get_attack_delay(state)

      expected = div(1200 * (100 - 5), 100)
      assert delay == expected
      assert delay == 1140
    end

    test "aspd_rate is applied to attack_delay_ms on combatant" do
      state = build_mob_state()

      combatant =
        state
        |> MobState.configure_summon(stat_bonus: %{aspd_rate: 5})
        |> MobState.to_combatant()

      assert combatant.attack_delay_ms == 1140
    end

    test "absent aspd_rate leaves attack_delay_ms at base value" do
      state = build_mob_state()
      combatant = state |> MobState.configure_summon([]) |> MobState.to_combatant()

      assert combatant.attack_delay_ms == 1200
    end
  end

  describe "recalculate_max_hp/1" do
    test "a freshly built mob records its base_max_hp" do
      state = build_mob_state()

      assert state.base_max_hp == 1000
      assert state.max_hp == 1000
    end

    test "with no :max_hp_rate status the ceiling stays at the base" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())

      updated = MobState.recalculate_max_hp(state)

      assert updated.max_hp == 1000
      assert updated.hp == state.hp
    end

    @tag game_mode: :renewal
    test "SC_DELUGE raises the ceiling by its tabulated percent without healing" do
      state = build_mob_state()
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
      StatusStorage.apply_status(:mob, state.instance_id, :sc_deluge, val1: 5)

      updated = MobState.recalculate_max_hp(state)

      # level 5 -> deluge_eff index rem(4, 5) == 4 -> +15%
      assert updated.max_hp == 1150
      assert updated.hp == state.hp
    end

    test "removing the buff caps overflow HP back down to the base ceiling" do
      buffed = %MobState{build_mob_state() | max_hp: 1150, hp: 1150}
      UnitRegistry.register_unit(:mob, buffed.instance_id, MobState, buffed, self())

      updated = MobState.recalculate_max_hp(buffed)

      assert updated.max_hp == 1000
      assert updated.hp == 1000
    end

    @tag game_mode: :renewal
    test "scales from base_max_hp so a re-apply never compounds" do
      # A stale effective ceiling must not be used as the recalc base.
      state = %MobState{build_mob_state() | max_hp: 1150}
      UnitRegistry.register_unit(:mob, state.instance_id, MobState, state, self())
      StatusStorage.apply_status(:mob, state.instance_id, :sc_deluge, val1: 5)

      updated = MobState.recalculate_max_hp(state)

      assert updated.max_hp == 1150
    end
  end
end
