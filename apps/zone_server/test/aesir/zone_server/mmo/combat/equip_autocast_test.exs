defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutocastTest do
  @moduledoc """
  Tests for equipment-granted autocast selection and the wearer-side resolution
  order of each proc branch.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast

  @cold_bolt 14

  defp with_mods(combatant, mods), do: %{combatant | equip_modifiers: mods}

  # The default arming of `bonus3 bAutoSpell`: a weapon proc, either range,
  # normal swings only.
  defp default_flag, do: BattleFlags.fill_autospell(0)

  defp entry(opts) do
    %{
      trigger: Keyword.get(opts, :trigger, :attack),
      skill_id: Keyword.get(opts, :skill_id, @cold_bolt),
      level: Keyword.get(opts, :level, 3),
      rate: Keyword.get(opts, :rate, 1_000),
      flag: Keyword.get(opts, :flag, default_flag()),
      force: Keyword.get(opts, :force, AutospellForceFlag.id(:target))
    }
  end

  # Registers each `{registration, card_id}` (or bare registration, armed by an
  # item's own script) in order, as the equipment fold does.
  defp registered(registrations) do
    Enum.reduce(registrations, %{}, fn
      {registration, card_id}, mods -> EquipAutocast.register(mods, registration, card_id)
      registration, mods -> EquipAutocast.register(mods, registration, 0)
    end)
  end

  defp melee_swing, do: BattleFlags.build(:weapon, :short, false)

  defp attacker_with(entries) do
    CombatTestHelper.create_player_combatant(unit_id: 1001) |> with_mods(registered(entries))
  end

  defp defender, do: CombatTestHelper.create_mob_combatant(unit_id: 2001)

  describe "register/3" do
    defp attack_list(mods), do: Enum.map(mods[{:auto_cast, :attack}], &{&1.rate, &1.card_id})

    test "an identical proc from the same source keeps its first chance" do
      assert attack_list(registered([entry(rate: 300), entry(rate: 500)])) == [{300, 0}]

      assert attack_list(registered([{entry(rate: 300), 4_001}, {entry(rate: 500), 4_001}])) ==
               [{300, 4_001}]
    end

    test "different cards keep separate entries, each its own candidate" do
      mods = registered([{entry(rate: 300), 4_001}, {entry(rate: 500), 4_002}])

      attacker = CombatTestHelper.create_player_combatant(unit_id: 1001) |> with_mods(mods)

      assert attack_list(mods) == [{300, 4_001}, {500, 4_002}]

      assert [%{rate: 300, entry: {:attack, 0, _}}, %{rate: 500, entry: {:attack, 1, _}}] =
               EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)
    end

    test "a negative chance merges across cards, capped above at 1000 with no floor" do
      assert attack_list(registered([{entry(rate: 600), 4_001}, {entry(rate: -200), 4_002}])) ==
               [{400, 4_001}]

      assert attack_list(registered([{entry(rate: -100), 4_001}, {entry(rate: 5_000), 4_002}])) ==
               [{1_000, 4_001}]

      assert attack_list(registered([{entry(rate: -800), 4_001}, {entry(rate: -800), 4_002}])) ==
               [{-1_600, 4_001}]

      assert attack_list(
               registered([{entry(rate: -1_000), 4_001}, {entry(rate: -32_000), 4_002}])
             ) == [{1_000, 4_001}]
    end

    test "a new entry's chance is narrowed to 16 bits, then capped to -1000..1000" do
      assert attack_list(registered([entry(rate: 4_000)])) == [{1_000, 0}]
      assert attack_list(registered([entry(rate: -4_000)])) == [{-1_000, 0}]
      assert attack_list(registered([entry(rate: 65_636)])) == [{100, 0}]
    end

    test "a zero chance registers nothing" do
      assert registered([entry(rate: 0)]) == %{}
      assert registered([entry(rate: 65_536)]) == %{}
    end

    test "a full list drops a registration before any merge" do
      full = registered(for level <- 1..50, do: entry(level: level, rate: 100))

      mods = EquipAutocast.register(full, entry(level: 1, rate: -50), 0)

      assert mods == full
      assert length(mods[{:auto_cast, :attack}]) == 50
      assert hd(mods[{:auto_cast, :attack}]).rate == 100
    end

    test "an on-skill registration never merges, so each entry is its own candidate" do
      proc = on_skill_entry(rate: 300)
      mods = registered([proc, proc, {%{proc | rate: -200}, 0}])

      assert Enum.map(mods[{:auto_cast, :on_skill}], & &1.rate) == [300, 300, -200]

      assert [
               %{entry: {:on_skill, 0, _}},
               %{entry: {:on_skill, 1, _}},
               %{entry: {:on_skill, 2, _}}
             ] =
               EquipAutocast.on_skill(mods, 42, {:unit, 2001})
    end

    test "current_identity follows an entry that moved and keeps one that did not" do
      [first, second] = for rate <- [300, 400], do: on_skill_entry(rate: rate)
      mods = registered([first, second])
      [a, b] = mods[{:auto_cast, :on_skill}]
      moved = %{mods | {:auto_cast, :on_skill} => [b]}

      assert EquipAutocast.current_identity(mods, {:on_skill, 1, b}) == {:on_skill, 1, b}
      assert EquipAutocast.current_identity(moved, {:on_skill, 1, b}) == {:on_skill, 0, b}
      assert EquipAutocast.current_identity(moved, {:on_skill, 0, a}) == {:on_skill, 0, a}
    end

    test "an entry armed at level 0 casts at level 1" do
      attacker = attacker_with([entry(level: 0)])

      assert [%{level: 1}] = EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)
    end
  end

  describe "on_attack/4" do
    test "a matching proc is a candidate cast at the target" do
      assert [
               %{
                 branch: :attack,
                 skill_id: @cold_bolt,
                 level: 3,
                 random_level?: false,
                 rate: 1_000,
                 target: {:unit, 2001}
               }
             ] =
               EquipAutocast.on_attack(
                 attacker_with([entry([])]),
                 defender(),
                 melee_swing(),
                 false
               )
    end

    test "without the target bit the proc casts on the wearer" do
      attacker = attacker_with([entry(force: AutospellForceFlag.id(:self))])

      assert [%{target: :self}] =
               EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)
    end

    test "the default arming fires on normal swings but not on weapon skills" do
      attacker = attacker_with([entry([])])

      assert [] =
               EquipAutocast.on_attack(
                 attacker,
                 defender(),
                 BattleFlags.build(:weapon, :short, true),
                 false
               )
    end

    test "a proc armed for magic never fires on a weapon swing" do
      attacker =
        attacker_with([entry(flag: BattleFlags.fill_autospell(BattleFlags.type_bit(:magic)))])

      assert [] = EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)

      assert [_proc] =
               EquipAutocast.on_attack(
                 attacker,
                 defender(),
                 BattleFlags.build(:magic, :long, true),
                 false
               )
    end

    test "the armed chance is capped and halved by an arrow attack" do
      attacker = attacker_with([entry(rate: 4_000)])

      assert [%{rate: 1_000}] =
               EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)

      assert [%{rate: 500}] = EquipAutocast.on_attack(attacker, defender(), melee_swing(), true)
    end

    test "a ranged weapon swing without the arrow-attack state keeps the full chance" do
      attacker = attacker_with([entry(rate: 600)])
      ranged = BattleFlags.build(:weapon, :long, false)

      assert [%{rate: 600}] = EquipAutocast.on_attack(attacker, defender(), ranged, false)
    end

    test "the random-level bit is carried for the wearer to roll" do
      force = Bitwise.bor(AutospellForceFlag.id(:target), AutospellForceFlag.id(:random_level))
      attacker = attacker_with([entry(level: 10, force: force)])

      assert [%{level: 10, random_level?: true}] =
               EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)
    end

    test "a mob attacker carries no equipment and procs nothing" do
      mob = CombatTestHelper.create_mob_combatant(unit_id: 3001)
      player = CombatTestHelper.create_player_combatant(unit_id: 1001)

      assert [] = EquipAutocast.on_attack(mob, player, melee_swing(), false)
    end

    test "when-hit entries never fire on the attack trigger" do
      attacker = attacker_with([entry(trigger: :when_hit)])

      assert [] = EquipAutocast.on_attack(attacker, defender(), melee_swing(), false)
    end
  end

  describe "on_skill/3" do
    defp on_skill_entry(opts) do
      opts
      |> Keyword.merge(trigger: :on_skill, flag: 0)
      |> Keyword.put_new(:force, 0)
      |> Keyword.put_new(:level, 2)
      |> entry()
      |> Map.put(:trigger_skill, Keyword.get(opts, :trigger_skill, 42))
    end

    defp on_skill_mods(opts), do: registered([on_skill_entry(opts)])

    test "a proc on its trigger skill is a candidate at the skill's target" do
      mods = on_skill_mods([])

      assert [
               %{
                 branch: :skill,
                 skill_id: @cold_bolt,
                 level: 2,
                 target: {:unit, 2001},
                 entry: {:on_skill, 0, _}
               }
             ] = EquipAutocast.on_skill(mods, 42, {:unit, 2001})
    end

    test "another skill fires nothing" do
      assert [] = EquipAutocast.on_skill(on_skill_mods([]), 99, {:unit, 2001})
    end

    # The target bit reads inverted here: it keeps the proc on the caster.
    test "the target bit keeps the proc on the caster" do
      mods = on_skill_mods(force: AutospellForceFlag.id(:target))

      assert [%{target: :self}] = EquipAutocast.on_skill(mods, 42, {:unit, 2001})
    end

    test "a cast with no unit target leaves an outgoing proc without a target" do
      assert [%{target: nil}] = EquipAutocast.on_skill(on_skill_mods([]), 42, nil)
    end

    test "attack-trigger entries are never selected here" do
      assert [] = EquipAutocast.on_skill(registered([entry(trigger: :attack)]), 42, {:unit, 2001})
    end
  end

  describe "when_hit/3" do
    test "the defender's proc targets the attacker" do
      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(registered([entry(trigger: :when_hit, flag: BattleFlags.fill_battle(0))]))

      assert [%{branch: :counter, skill_id: @cold_bolt, level: 3, target: {:unit, 1001}}] =
               EquipAutocast.when_hit(defender, 1001, melee_swing())
    end

    test "long-range weapon damage halves the chance" do
      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(
          registered([entry(trigger: :when_hit, rate: 600, flag: BattleFlags.fill_battle(0))])
        )

      assert [%{rate: 300}] =
               EquipAutocast.when_hit(defender, 1001, BattleFlags.build(:weapon, :long, false))

      assert [%{rate: 600}] = EquipAutocast.when_hit(defender, 1001, melee_swing())
    end

    test "attack entries never fire on the when-hit trigger" do
      defender =
        CombatTestHelper.create_player_combatant(unit_id: 2001)
        |> with_mods(registered([entry(trigger: :attack)]))

      assert [] = EquipAutocast.when_hit(defender, 1001, melee_swing())
    end
  end

  describe "resolve/3" do
    defp candidate(branch, overrides \\ []) do
      Map.merge(
        %{
          branch: branch,
          skill_id: @cold_bolt,
          level: 5,
          random_level?: true,
          rate: 300,
          target: {:unit, 2001},
          entry: :entry
        },
        Map.new(overrides)
      )
    end

    defp recorder do
      parent = self()

      [
        usable: fn skill_id ->
          send(parent, {:step, :usable, skill_id})
          :ok
        end,
        roll: fn rate ->
          send(parent, {:step, :roll, rate})
          true
        end,
        level_roll: fn level ->
          send(parent, {:step, :level, level})
          2
        end
      ]
    end

    defp steps do
      receive_steps([])
    end

    defp receive_steps(acc) do
      receive do
        {:step, step, _value} -> receive_steps([step | acc])
      after
        0 -> Enum.reverse(acc)
      end
    end

    test "an attack proc checks usability, then draws its level, then rolls" do
      assert {:cast, 2} = EquipAutocast.resolve(candidate(:attack), recorder())
      assert steps() == [:usable, :level, :roll]
    end

    test "a counter proc draws its level before the usability check" do
      assert {:cast, 2} = EquipAutocast.resolve(candidate(:counter), recorder())
      assert steps() == [:level, :usable, :roll]
    end

    test "an on-skill proc checks usability, rolls, then draws its level" do
      assert {:cast, 2} = EquipAutocast.resolve(candidate(:skill), recorder())
      assert steps() == [:usable, :roll, :level]
    end

    test "an unusable proc reports why and never rolls its chance" do
      opts = Keyword.put(recorder(), :usable, fn _skill_id -> {:error, :cooldown} end)

      assert {:unusable, :cooldown} = EquipAutocast.resolve(candidate(:attack), opts)
      assert steps() == []
    end

    test "an on-skill proc without a target stops after the usability check" do
      assert :skip = EquipAutocast.resolve(candidate(:skill, target: nil), recorder())
      assert steps() == [:usable]
    end

    test "a failed roll casts nothing and a fixed level is kept" do
      opts = Keyword.put(recorder(), :roll, fn _rate -> false end)

      assert :skip = EquipAutocast.resolve(candidate(:attack), opts)

      assert {:cast, 5} =
               EquipAutocast.resolve(candidate(:attack, random_level?: false), recorder())
    end

    test "the default roll never fires a non-positive chance" do
      opts = Keyword.delete(recorder(), :roll)

      assert :skip = EquipAutocast.resolve(candidate(:attack, rate: 0), opts)
      assert :skip = EquipAutocast.resolve(candidate(:attack, rate: -50), opts)
      assert {:cast, _level} = EquipAutocast.resolve(candidate(:attack, rate: 1_000), opts)
    end
  end
end
