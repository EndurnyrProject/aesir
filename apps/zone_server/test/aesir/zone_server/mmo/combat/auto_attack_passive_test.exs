defmodule Aesir.ZoneServer.Mmo.Combat.AutoAttackPassiveTest do
  @moduledoc """
  Coverage for the confirmed-normal-hit passive seam: `Passives.after_normal_hit/2`
  must fire exactly once after a successful primary ordinary player hit, with the
  immutable target identity and pre-hit position, and never for misses, perfect
  dodge, attack replacements, skill attacks, skill-unit attacks, or secondary
  splash hits.
  """
  use ExUnit.Case, async: true
  use Mimic
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(EquipBreak, :resolve, fn _attacker, _target -> [] end)
    :ok
  end

  defmodule FakeUnit do
    @moduledoc false
    defstruct [:combatant, :stats, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  defmodule FakeSkillUnit do
    @moduledoc false
    defstruct [:combatant, :hp]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  defp combatant(unit_id, type, opts \\ []) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: type,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 0,
        def: 0,
        hit: Keyword.get(opts, :hit, 200),
        flee: Keyword.get(opts, :flee, 0),
        perfect_dodge: Keyword.get(opts, :perfect_dodge, 0)
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: Keyword.get(opts, :attack_range, 5),
      attack_delay_ms: Keyword.get(opts, :attack_delay_ms, 500),
      position: Keyword.get(opts, :position, {150, 150}),
      map_name: Keyword.get(opts, :map_name, "prontera")
    })
  end

  defp living_mob_state(combatant, x, y) do
    Mimic.copy(MobState)

    state = mob_state(combatant, x, y)
    stub(MobState, :to_combatant, fn ^state -> combatant end)
    state
  end

  defp mob_state(combatant, x, y) do
    struct(MobState, %{
      instance_id: combatant.unit_id,
      hp: 100,
      max_hp: 100,
      is_dead: false,
      x: x,
      y: y,
      map_name: combatant.map_name
    })
  end

  # Same-cell target keeps the projectile line-of-sight check trivial, matching
  # the existing combat test setup.
  defp setup_mob_hit(_context) do
    attacker = combatant(1001, :player)
    target = combatant(2001, :mob)

    player_state =
      PlayerStateFixture.build(%{
        character_id: 1001,
        x: 150,
        y: 150,
        map_name: "prontera",
        stats: %{
          combat_stats: Map.merge(attacker.combat_stats, %{critical: 0, passive_atk: 0}),
          derived_stats: %{aspd: 150}
        }
      })

    target_state = living_mob_state(target, 150, 150)

    stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, 2001 -> {:ok, {150, 150, "prontera"}} end)

    stub(DamageCalculator, :calculate_damage, fn _a, _d ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Passives, :attack_procs, fn _player -> %{} end)
    stub(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

    %{attacker: player_state.stats, player_state: player_state}
  end

  describe "execute_attack/3 confirmed ordinary hits" do
    setup :setup_mob_hit

    test "dispatches after_normal_hit exactly once with target identity and pre-hit position",
         %{attacker: attacker, player_state: player_state} do
      test_pid = self()

      expect(Passives, :after_normal_hit, fn player, hit ->
        send(test_pid, {:after_normal_hit, player, hit})
        :ok
      end)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, 2001)
      end)

      assert_received {:after_normal_hit, %PlayerState{},
                       %{target_type: :mob, target_id: 2001, position: {150, 150}}}

      refute_received {:after_normal_hit, _, _}
    end

    test "a multi-hit swing still dispatches exactly once",
         %{attacker: attacker, player_state: player_state} do
      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)
      expect(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)
      expect(Passives, :after_normal_hit, fn _player, _hit -> :ok end)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, 2001)
      end)
    end

    test "a miss never dispatches", %{attacker: attacker, player_state: player_state} do
      target = combatant(2001, :mob, flee: 10_000)
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      reject(&Passives.after_normal_hit/2)
      reject(&MobSession.apply_damage/3)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, 2001)
      end)
    end

    test "a perfect dodge never dispatches", %{attacker: attacker, player_state: player_state} do
      target = combatant(2001, :mob, perfect_dodge: 1000)
      target_state = living_mob_state(target, 150, 150)

      stub(UnitRegistry, :get_unit, fn :mob, 2001 -> {:ok, {FakeUnit, target_state, self()}} end)
      reject(&Passives.after_normal_hit/2)
      reject(&MobSession.apply_damage/3)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, 2001)
      end)
    end

    test "an attack replacement never dispatches",
         %{attacker: attacker, player_state: player_state} do
      stub(Passives, :attack_replacement, fn _player ->
        {:skill_attack,
         [skill_id: 263, skill_level: 5, skill_ratio: 200, display_hit_count: 3, skip_crit: true],
         :quadruple}
      end)

      stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
        {:ok, %{damage: 75, is_critical: false}}
      end)

      expect(MobSession, :apply_damage, fn _pid, 75, _attacker_id -> :ok end)
      reject(&Passives.after_normal_hit/2)

      assert {:ok, {:combo, :quadruple, {:mob, 2001}, 1_000}} =
               Combat.execute_attack(attacker, player_state, 2001)
    end

    test "a skill attack never dispatches",
         %{player_state: player_state} do
      reject(&Passives.after_normal_hit/2)

      stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
        {:ok, %{damage: 50, is_critical: false}}
      end)

      expect(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

      assert :ok =
               Combat.execute_skill_attack(player_state, 2001,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100
               )
    end

    # Same-cell target keeps the projectile line-of-sight check trivial. The
    # skill-unit resolve path is stubbed at the CombatTarget boundary, so no
    # real skill-unit manager is involved.
    test "a confirmed hit on a skill unit never dispatches",
         %{attacker: attacker, player_state: player_state} do
      target = combatant(9_000_001, :skill_unit)
      cell_state = %FakeSkillUnit{combatant: target, hp: 3}

      Mimic.copy(CombatTarget)
      Mimic.copy(DamageApplication)
      stub(CombatTarget, :target?, fn 9_000_001 -> true end)
      stub(CombatTarget, :resolve, fn 9_000_001 -> {:ok, self(), cell_state, :skill_unit} end)
      stub(DamageApplication, :damage_skill_unit, fn _pid, _id, _damage, _source -> :ok end)
      reject(&Passives.after_normal_hit/2)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, 9_000_001)
      end)
    end

    test "secondary splash hits never dispatch while the primary hit dispatches once" do
      attacker =
        1001
        |> combatant(:player)
        |> Map.put(:equip_modifiers, %{splash_range: 1})

      player_state = %FakeUnit{combatant: attacker, x: 150, y: 150}

      primary = combatant(2001, :mob)
      secondary = combatant(2002, :mob, position: {151, 150})

      Mimic.copy(MobState)
      primary_state = mob_state(primary, 150, 150)
      secondary_state = mob_state(secondary, 151, 150)

      stub(MobState, :to_combatant, fn
        ^primary_state -> primary
        ^secondary_state -> secondary
      end)

      stub(UnitRegistry, :get_unit, fn
        :mob, 2001 -> {:ok, {FakeUnit, primary_state, self()}}
        :mob, 2002 -> {:ok, {FakeUnit, secondary_state, self()}}
      end)

      stub(SpatialIndex, :get_unit_position, fn
        :mob, 2001 -> {:ok, {150, 150, "prontera"}}
        :mob, 2002 -> {:ok, {151, 150, "prontera"}}
      end)

      stub(SpatialIndex, :get_all_units_in_range, fn "prontera", 150, 150, _range ->
        [{:mob, 2001}, {:mob, 2002}]
      end)

      expect(MobSession, :apply_damage, 2, fn _pid, _damage, _attacker_id -> :ok end)

      test_pid = self()

      expect(Passives, :after_normal_hit, fn _player, hit ->
        send(test_pid, {:after_normal_hit, hit})
        :ok
      end)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, 2001)
      end)

      assert_received {:after_normal_hit, %{target_type: :mob, target_id: 2001}}
      refute_received {:after_normal_hit, _}
    end
  end
end
