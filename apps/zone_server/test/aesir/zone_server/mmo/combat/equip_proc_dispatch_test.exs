defmodule Aesir.ZoneServer.Mmo.Combat.EquipProcDispatchTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private

  @cold_bolt 14
  @heal 28
  @grand_cross 254
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

  defp on_skill_candidates(wearer),
    do: EquipAutocast.on_skill(wearer.equip_modifiers, @heal, {:unit, 2001})
end
