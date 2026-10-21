defmodule Aesir.ZoneServer.Mmo.Combat.EquipProcDispatchTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.PolymorphPool
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.UnitRegistry

  import Aesir.TestEtsSetup

  setup :set_mimic_private
  setup :setup_ets_tables

  @cold_bolt 14
  @heal 28
  @grand_cross 254
  @demonstration 229
  @gravitation 484
  @auto_counter 61
  @poison_react 139
  @sight_blaster 1006
  @triple_attack 263
  @target_force 1

  setup do
    test_pid = self()
    stub(UnitRegistry, :get_player_pid, fn _id -> {:ok, test_pid} end)
    :ok
  end

  defp melee, do: BattleFlags.build(:weapon, :short, false)
  defp magic_skill, do: BattleFlags.build(:magic, :long, true)

  defp autocast(trigger, flag),
    do: %{
      trigger: trigger,
      skill_id: @cold_bolt,
      level: 3,
      rate: 1_000,
      flag: flag,
      force: @target_force
    }

  defp on_skill_autocast(trigger_skill, skill_id, force) do
    %{
      trigger: :on_skill,
      trigger_skill: trigger_skill,
      skill_id: skill_id,
      level: 1,
      rate: 1_000,
      flag: 0,
      force: force
    }
  end

  defp autobonus(trigger, flag),
    do: %{
      trigger: trigger,
      battle_flag: flag,
      rate: 1_001,
      source_order: {0, 0},
      source_identity: {:host, 1}
    }

  defp player(id, mods, autobonuses \\ %{}) do
    %{
      CombatTestHelper.create_player_combatant(unit_id: id)
      | equip_modifiers: Enum.reduce(mods, %{}, &EquipAutocast.register(&2, &1, 0)),
        equip_autobonuses: autobonuses
    }
  end

  defp mob, do: CombatTestHelper.create_mob_combatant(unit_id: 2001)

  defp hit(overrides \\ []) do
    Map.merge(
      %{
        attack_flag: melee(),
        divisions: 1,
        hit_class: :hit,
        damage: 50,
        attack_effects?: true,
        counter_effects?: true,
        arrow_attack?: false,
        skill_id: nil
      },
      Map.new(overrides)
    )
  end

  describe "event/4" do
    test "a delayed connected hit runs both stages" do
      assert %{hit_class: :hit, counter_effects?: true, attack_effects?: true, damage: 40} =
               EquipProcDispatch.event(melee(), 40, %{})
    end

    test "a hit that connected for a total below 1 is a miss with no counter stage" do
      assert %{hit_class: :miss, counter_effects?: false} =
               EquipProcDispatch.event(melee(), 0, %{})

      assert %{hit_class: :miss, counter_effects?: false} =
               EquipProcDispatch.event(
                 melee(),
                 0,
                 %{devotion_rerouted?: true, devotion_damage: 0},
                 immediate?: true
               )
    end

    test "an immediate hit gates the counter stage on positive damage" do
      assert %{counter_effects?: false} =
               EquipProcDispatch.event(melee(), 0, %{}, immediate?: true)

      assert %{counter_effects?: true} =
               EquipProcDispatch.event(melee(), 1, %{}, immediate?: true)
    end

    test "a blocked hit is a block and a Magic Rod interception a miss" do
      assert %{hit_class: :block, counter_effects?: false} =
               EquipProcDispatch.event(melee(), 0, %{blocked?: true})

      assert %{hit_class: :miss, counter_effects?: false} =
               EquipProcDispatch.event(magic_skill(), 0, %{magic_rod_miss?: true})
    end

    test "a forwarded delayed hit is a block; a forwarded immediate one keeps the devotee's damage" do
      forwarded = %{devotion_rerouted?: true, devotion_damage: 70}

      assert %{hit_class: :block, counter_effects?: false} =
               EquipProcDispatch.event(melee(), 0, forwarded)

      assert %{hit_class: :hit, counter_effects?: true, damage: 70} =
               EquipProcDispatch.event(melee(), 0, forwarded, immediate?: true)
    end
  end

  describe "hit_event/2" do
    defp proc_spec(target_hp),
      do: %{target: %{unit_type: :mob}, target_hp: target_hp, attack_flag: melee()}

    # battle_damage runs skill_additional_effect only when the target is still
    # alive after status_fix_damage (battle.cpp:337): a killing blow skips it.
    test "a killing blow skips the additional-effect stage; a surviving or coma'd target keeps it" do
      assert %{hit_class: :hit, attack_effects?: false} =
               EquipProcDispatch.hit_event(%{proc: proc_spec(40)}, 40)

      assert %{hit_class: :hit, attack_effects?: true} =
               EquipProcDispatch.hit_event(%{proc: proc_spec(41)}, 40)

      assert %{attack_effects?: true} =
               EquipProcDispatch.hit_event(%{proc: proc_spec(40), coma?: true}, 40)
    end
  end

  describe "dispatch/3" do
    test "a connected hit on a surviving target sends the attack autocast to its wearer" do
      attacker = player(1001, [autocast(:attack, BattleFlags.fill_autospell(0))])

      assert :ok = EquipProcDispatch.dispatch(attacker, mob(), hit())

      assert_received {:"$gen_cast",
                       {:skill,
                        {:equip_proc,
                         %{branch: :attack, skill_id: @cold_bolt, target: {:unit, 2001}}}}}
    end

    test "no attack autocast when the target died or the hit was blocked" do
      attacker = player(1001, [autocast(:attack, BattleFlags.fill_autospell(0))])

      EquipProcDispatch.dispatch(attacker, mob(), hit(attack_effects?: false))
      EquipProcDispatch.dispatch(attacker, mob(), hit(hit_class: :block, counter_effects?: false))

      refute_received {:"$gen_cast", {:skill, {:equip_proc, _}}}
    end

    test "default weapon autocasts do not fire from magic or misc hits" do
      attacker = player(1001, [autocast(:attack, BattleFlags.fill_autospell(0))])

      EquipProcDispatch.dispatch(attacker, mob(), hit(attack_flag: magic_skill(), skill_id: 19))

      EquipProcDispatch.dispatch(
        attacker,
        mob(),
        hit(attack_flag: BattleFlags.build(:misc, :short, true))
      )

      refute_received {:"$gen_cast", {:skill, {:equip_proc, %{branch: :attack}}}}
    end

    test "the selection resets the wearer's autocast flag in the dispatching process" do
      attacker = player(1001, [autocast(:attack, BattleFlags.fill_autospell(0))])
      Origin.set_autocast_flag({:player, 1001}, true)

      EquipProcDispatch.dispatch(attacker, mob(), hit())

      refute Origin.autocast?({:player, 1001})
    end

    test "attack autobonuses follow the counter stage, not survival" do
      attacker = player(1001, [], %{{10, 0} => autobonus(:attack, melee())})

      EquipProcDispatch.dispatch(attacker, mob(), hit(attack_effects?: false))
      assert_received {:"$gen_cast", {:equipment, {:autobonus_activate, {10, 0}, {:host, 1}}}}

      EquipProcDispatch.dispatch(attacker, mob(), hit(counter_effects?: false))
      refute_received {:"$gen_cast", {:equipment, {:autobonus_activate, _, _}}}
    end

    test "a damaging skill hit arms the caster's on-skill procs at the struck target" do
      on_skill = on_skill_autocast(@cold_bolt, @heal, 0)
      attacker = player(1001, [on_skill])

      EquipProcDispatch.dispatch(
        attacker,
        mob(),
        hit(skill_id: @cold_bolt, attack_flag: magic_skill())
      )

      assert_received {:"$gen_cast",
                       {:skill,
                        {:equip_proc, %{branch: :skill, skill_id: @heal, target: {:unit, 2001}}}}}

      EquipProcDispatch.dispatch(attacker, mob(), hit(skill_id: @cold_bolt, damage: 0))
      refute_received {:"$gen_cast", {:skill, {:equip_proc, _}}}
    end

    test "Grand Cross striking its own caster matches the caster's attack autobonuses as a weapon hit" do
      weapon_only = BattleFlags.fill_battle(BattleFlags.type_bit(:weapon))
      caster = player(1001, [], %{{10, 0} => autobonus(:attack, weapon_only)})

      grand_cross =
        hit(skill_id: @grand_cross, attack_flag: BattleFlags.build(:magic, :short, true))

      EquipProcDispatch.dispatch(caster, caster, grand_cross)
      assert_received {:"$gen_cast", {:equipment, {:autobonus_activate, {10, 0}, _}}}

      EquipProcDispatch.dispatch(caster, mob(), grand_cross)
      refute_received {:"$gen_cast", {:equipment, {:autobonus_activate, _, _}}}
    end

    test "a monster attacker dispatches nothing" do
      assert :ok = EquipProcDispatch.dispatch(mob(), player(1001, []), hit())
      refute_received {:"$gen_cast", _}
    end
  end

  describe "when_hit/3" do
    test "a living recipient's when-hit autocast targets the attacker" do
      wearer = player(1001, [autocast(:when_hit, BattleFlags.fill_battle(0))])

      EquipProcDispatch.when_hit(wearer, {:mob, 2001}, hit())

      assert_received {:"$gen_cast",
                       {:skill, {:equip_proc, %{branch: :counter, target: {:unit, 2001}}}}}
    end

    test "nothing when the counter stage does not run or the skill deals no damage" do
      wearer =
        player(1001, [autocast(:when_hit, BattleFlags.fill_battle(0))], %{
          {10, 0} => autobonus(:when_hit, BattleFlags.fill_battle(0))
        })

      EquipProcDispatch.when_hit(wearer, {:mob, 2001}, hit(counter_effects?: false))
      EquipProcDispatch.when_hit(wearer, {:player, 7}, hit(skill_id: @heal))

      refute_received {:"$gen_cast", _}
    end

    test "Demonstration, and classic Gravitation Field, deal no-damage hits" do
      wearer = player(1001, [autocast(:when_hit, BattleFlags.fill_battle(0))])

      EquipProcDispatch.when_hit(wearer, {:player, 7}, hit(skill_id: @demonstration))
      refute_received {:"$gen_cast", _}

      EquipProcDispatch.when_hit(wearer, {:player, 7}, hit(skill_id: @gravitation))

      if GameMode.mode() == :renewal,
        do: assert_received({:"$gen_cast", {:skill, {:equip_proc, _}}}),
        else: refute_received({:"$gen_cast", _})
    end

    test "counters, Sight Blaster's strike and Triple Attack are damage hits" do
      wearer = player(1001, [autocast(:when_hit, BattleFlags.fill_battle(0))])

      for skill_id <- [@auto_counter, @poison_react, @sight_blaster, @triple_attack] do
        EquipProcDispatch.when_hit(wearer, {:mob, 2001}, hit(skill_id: skill_id))
        assert_received {:"$gen_cast", {:skill, {:equip_proc, %{branch: :counter}}}}
      end
    end

    test "when-hit autobonuses activate on the recipient" do
      wearer = player(1001, [], %{{10, 0} => autobonus(:when_hit, BattleFlags.fill_battle(0))})

      EquipProcDispatch.when_hit(wearer, {:mob, 2001}, hit())

      assert_received {:"$gen_cast", {:equipment, {:autobonus_activate, {10, 0}, _}}}
    end

    test "Grand Cross striking its own caster counts as a weapon hit" do
      weapon_only = BattleFlags.fill_battle(BattleFlags.type_bit(:weapon))
      wearer = player(1001, [autocast(:when_hit, weapon_only)])

      grand_cross =
        hit(skill_id: @grand_cross, attack_flag: BattleFlags.build(:magic, :short, true))

      EquipProcDispatch.when_hit(wearer, {:player, 1001}, grand_cross)
      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{branch: :counter}}}}

      EquipProcDispatch.when_hit(wearer, {:player, 7}, grand_cross)
      refute_received {:"$gen_cast", {:skill, {:equip_proc, _}}}
    end
  end

  describe "castend_target/2" do
    alias Aesir.ZoneServer.Mmo.Skill.Catalog

    defp definition!(name) do
      {:ok, definition} = Catalog.by_name(name)
      definition
    end

    test "a damage skill arms on-skill procs per damaging hit, not at its castend" do
      assert :none = EquipProcDispatch.castend_target(definition!(:mg_coldbolt), {:unit, 2001})
    end

    test "a no-damage skill arms them at its target, a self skill at its caster" do
      assert {:ok, {:unit, 2001}} =
               EquipProcDispatch.castend_target(definition!(:al_incagi), {:unit, {:player, 2001}})

      assert {:ok, :self} = EquipProcDispatch.castend_target(definition!(:sm_magnum), :self)
    end

    test "a ground skill, or a self skill placed as a unit, arms them without a target" do
      assert {:ok, nil} =
               EquipProcDispatch.castend_target(definition!(:wz_meteor), {:ground, 5, 5})

      assert {:ok, nil} = EquipProcDispatch.castend_target(definition!(:cr_grandcross), :self)
    end

    @tag game_mode: :pre_renewal
    test "classic songs are placed as units" do
      assert {:ok, nil} = EquipProcDispatch.castend_target(definition!(:ba_whistle), :self)
    end

    @tag game_mode: :renewal
    test "renewal songs are ordinary self skills" do
      assert {:ok, :self} = EquipProcDispatch.castend_target(definition!(:ba_whistle), :self)
    end
  end

  describe "on_skill/3" do
    test "a locked entry does not re-trigger itself while its proc executes" do
      wearer =
        player(1001, [
          on_skill_autocast(@heal, @heal, AutospellForceFlag.id(:target)),
          on_skill_autocast(@heal, @cold_bolt, 0)
        ])

      [%{entry: entry}, %{entry: other}] = on_skill_candidates(wearer)

      EquipProcDispatch.with_on_skill_lock(1001, entry, fn ->
        EquipProcDispatch.on_skill(wearer, @heal, {:unit, 2001})
      end)

      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^other}}}}
      refute_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^entry}}}}

      EquipProcDispatch.on_skill(wearer, @heal, {:unit, 2001})
      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^entry}}}}
    end

    test "two identical entries each dispatch, and locking one leaves the other" do
      proc = on_skill_autocast(@heal, @cold_bolt, 0)
      wearer = player(1001, [proc, proc])

      [%{entry: first}, %{entry: second}] = on_skill_candidates(wearer)
      assert first != second

      EquipProcDispatch.on_skill(wearer, @heal, {:unit, 2001})
      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^first}}}}
      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^second}}}}

      EquipProcDispatch.with_on_skill_lock(1001, first, fn ->
        EquipProcDispatch.on_skill(wearer, @heal, {:unit, 2001})
      end)

      assert_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^second}}}}
      refute_received {:"$gen_cast", {:skill, {:equip_proc, %{entry: ^first}}}}
    end
  end

  # The reference rolls polymorph at the tail of skill_additional_effect: a
  # weapon hit that left a living, non-status-immune monster can change its form
  # to a random entry of the shared pool (skill.cpp:1578-1584, mob.cpp:3803).
  describe "polymorph" do
    @polymorph_target 3001

    setup do
      test_pid = self()
      {:ok, data} = MobManagement.get_mob_by_id(1002)
      spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5_000, spawn_area: nil}

      stub(MobSession, :polymorph, fn pid, replacement_id ->
        send(test_pid, {:polymorph, pid, replacement_id})
        :ok
      end)

      stub(UnitRegistry, :get_unit, fn :mob, @polymorph_target ->
        {:ok,
         {MobState, MobState.new(@polymorph_target, data, spawn, "prontera", 1, 1), test_pid}}
      end)

      :ok
    end

    # A rate of 10_000 out of 10_000 always passes the roll, as in the source.
    defp wearer_with_class_change(rate),
      do: %{player(1001, []) | equip_modifiers: %{class_change: rate}}

    defp polymorph_target, do: CombatTestHelper.create_mob_combatant(unit_id: @polymorph_target)

    test "a weapon hit rolls the wearer's class change and polymorphs the monster" do
      stub(PolymorphPool, :pick, fn -> 1001 end)

      assert :ok =
               EquipProcDispatch.dispatch(
                 wearer_with_class_change(10_000),
                 polymorph_target(),
                 hit()
               )

      assert_received {:polymorph, _pid, 1001}
    end

    test "a zero class change never rolls the pool" do
      reject(PolymorphPool, :pick, 0)

      assert :ok =
               EquipProcDispatch.dispatch(wearer_with_class_change(0), polymorph_target(), hit())

      refute_received {:polymorph, _, _}
    end

    test "a missed, non-weapon or non-surviving hit never rolls the pool" do
      reject(PolymorphPool, :pick, 0)

      EquipProcDispatch.dispatch(
        wearer_with_class_change(10_000),
        polymorph_target(),
        hit(hit_class: :miss)
      )

      EquipProcDispatch.dispatch(
        wearer_with_class_change(10_000),
        polymorph_target(),
        hit(attack_flag: magic_skill())
      )

      EquipProcDispatch.dispatch(
        wearer_with_class_change(10_000),
        polymorph_target(),
        hit(attack_effects?: false)
      )

      refute_received {:polymorph, _, _}
    end

    test "a status-immune monster keeps its form" do
      reject(PolymorphPool, :pick, 0)
      immune = %{polymorph_target() | status_immune: true}

      assert :ok = EquipProcDispatch.dispatch(wearer_with_class_change(10_000), immune, hit())

      refute_received {:polymorph, _, _}
    end

    test "a summoned monster lends its master's class change to its own hits" do
      master = wearer_with_class_change(10_000)
      summon = %{mob() | proc_owner_id: 1001}

      stub(TargetResolver, :resolve_combatant, fn {:player, 1001} -> {:ok, master} end)
      stub(PolymorphPool, :pick, fn -> 1001 end)

      assert :ok = EquipProcDispatch.dispatch(summon, polymorph_target(), hit())

      assert_received {:polymorph, _pid, 1001}
    end

    test "an ordinary monster attacker wears nothing" do
      reject(PolymorphPool, :pick, 0)

      assert :ok = EquipProcDispatch.dispatch(mob(), polymorph_target(), hit())

      refute_received {:polymorph, _, _}
    end

    # The reference inherits only the additional-effect stage through a summon:
    # the counter-stage autobonuses and the on-skill procs read the attacker.
    test "a summoned monster does not run its master's counter or on-skill procs" do
      master =
        player(1001, [on_skill_autocast(@heal, @cold_bolt, @target_force)], %{
          {10, 0} => autobonus(:attack, melee())
        })

      stub(TargetResolver, :resolve_combatant, fn {:player, 1001} -> {:ok, master} end)
      summon = %{mob() | proc_owner_id: 1001}

      assert :ok = EquipProcDispatch.dispatch(summon, polymorph_target(), hit(skill_id: @heal))

      refute_received {:"$gen_cast", {:equipment, {:autobonus_activate, _, _}}}
      refute_received {:"$gen_cast", {:skill, {:equip_proc, _}}}
    end
  end

  describe "dispatch_breaks/5" do
    setup do
      stub(Config, :natural_break_rate, fn -> 0 end)
      :ok
    end

    defp break_wearer(mods, weapon_type \\ :one_handed_sword) do
      %{
        player(1001, [])
        | equip_modifiers: mods,
          weapon: %{type: weapon_type, element: :neutral, size: :medium}
      }
    end

    defp victim_stats do
      %Stats{
        equipment: %Equipment{right_hand: 1101},
        modifiers: %Modifiers{equipment: %{}}
      }
    end

    defp player_target(id \\ 2001),
      do: %{type: :player, id: id, pid: self(), state: %{stats: victim_stats()}}

    defp summon(owner), do: %{mob() | proc_owner_id: owner}

    defp stub_master(master) do
      stub(TargetResolver, :resolve_combatant, fn {:player, 1001} -> {:ok, master} end)
    end

    test "a weapon hit rolls the wearer's target rates against a player victim" do
      wearer = break_wearer(%{break_weapon_rate: 10_000, break_armor_rate: 0})

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 wearer,
                 player_target(),
                 hit(skill_id: @triple_attack),
                 melee(),
                 @triple_attack
               )

      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
    end

    test "non-weapon, unconnected and non-surviving hits never roll" do
      reject(&EquipBreak.resolve/2)
      wearer = break_wearer(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})
      target = player_target()

      EquipProcDispatch.dispatch_breaks(
        wearer,
        target,
        hit(attack_flag: magic_skill()),
        magic_skill(),
        @cold_bolt
      )

      misc_flag = BattleFlags.build(:misc, :long, true)

      EquipProcDispatch.dispatch_breaks(
        wearer,
        target,
        hit(attack_flag: misc_flag),
        misc_flag,
        @cold_bolt
      )

      EquipProcDispatch.dispatch_breaks(wearer, target, hit(hit_class: :miss), melee(), nil)
      EquipProcDispatch.dispatch_breaks(wearer, target, hit(hit_class: :block), melee(), nil)
      EquipProcDispatch.dispatch_breaks(wearer, target, hit(attack_effects?: false), melee(), nil)

      EquipProcDispatch.dispatch_breaks(
        wearer,
        %{type: :skill_unit, id: 900, pid: nil},
        hit(),
        melee(),
        nil
      )

      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    test "Cart Termination and Tomahawk never roll the natural breaks" do
      reject(&EquipBreak.resolve/2)
      wearer = break_wearer(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})

      for skill_id <- [337, 485] do
        assert :ok =
                 EquipProcDispatch.dispatch_breaks(
                   wearer,
                   player_target(),
                   hit(skill_id: skill_id),
                   melee(),
                   skill_id
                 )
      end

      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    test "an ordinary monster and a masterless summon roll nothing" do
      reject(&EquipBreak.resolve/2)

      EquipProcDispatch.dispatch_breaks(mob(), player_target(), hit(), melee(), nil)

      refute_received {:"$gen_cast", {:inventory, {:break_equip, _}}}
    end

    test "a player-owned summon rolls its master's target rates" do
      stub_master(break_wearer(%{break_weapon_rate: 10_000, break_armor_rate: 0}))

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 summon(1001),
                 player_target(),
                 hit(),
                 melee(),
                 nil
               )

      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
    end

    test "the natural self break aims at the wearer and honors the configured rate" do
      stub(Config, :natural_break_rate, fn -> 10_000 end)

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 break_wearer(%{}),
                 player_target(),
                 hit(),
                 melee(),
                 nil
               )

      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
    end

    test "the pinned default natural break rate never breaks the wearer" do
      reject(&PlayerSession.break_equip/2)

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 break_wearer(%{}),
                 player_target(),
                 hit(),
                 melee(),
                 nil
               )
    end

    test "a summon's self break aims at its master's session" do
      stub(Config, :natural_break_rate, fn -> 10_000 end)
      stub_master(break_wearer(%{}))

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 summon(1001),
                 player_target(),
                 hit(),
                 melee(),
                 nil
               )

      assert_received {:"$gen_cast", {:inventory, {:break_equip, :right_hand}}}
    end

    test "a monster victim takes no break" do
      reject(&PlayerSession.break_equip/2)
      wearer = break_wearer(%{break_weapon_rate: 10_000, break_armor_rate: 10_000})

      assert :ok =
               EquipProcDispatch.dispatch_breaks(
                 wearer,
                 %{type: :mob, id: 3001, pid: nil},
                 hit(),
                 melee(),
                 nil
               )
    end
  end

  defp on_skill_candidates(wearer),
    do: EquipAutocast.on_skill(wearer.equip_modifiers, @heal, {:unit, 2001})
end
