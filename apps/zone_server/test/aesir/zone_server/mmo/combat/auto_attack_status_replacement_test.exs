defmodule Aesir.ZoneServer.Mmo.Combat.AutoAttackStatusReplacementTest do
  @moduledoc """
  Coverage for the status-driven basic-attack replacement seam: a status
  implementing `attack_replacement/3` turns the holder's ordinary swing into a
  skill attack, wins over a learned passive replacement, returns a plain `:ok`
  (no combo stage), and may skip the hit/flee roll with `ignore_flee`.
  """
  use ExUnit.Case, async: false
  use Mimic
  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule TestReplacement do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_attack_replacement,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def attack_replacement(_target, %{val1: level}, _context) do
      {:skill_attack,
       [
         skill_id: 9_999,
         skill_level: level,
         skill_ratio: 300,
         ignore_flee: true,
         skip_crit: true
       ]}
    end
  end

  defmodule FakeUnit do
    @moduledoc false
    defstruct [:combatant, :stats, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  @attacker_id 41_001
  @target_id 42_001

  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(HitCalculations)
    Registry.register_module(TestReplacement)
    stub(EquipBreak, :resolve, fn _attacker, _target -> [] end)
    stub(Passives, :steal_proc, fn _player -> 0 end)
    stub(Passives, :attack_procs, fn _player -> %{} end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(MobSession, :apply_damage, fn _pid, _damage, _attacker_id -> :ok end)

    attacker = combatant(@attacker_id, :player)
    target = combatant(@target_id, :mob)

    player_state =
      PlayerStateFixture.build(%{
        character_id: @attacker_id,
        x: 150,
        y: 150,
        map_name: "prontera",
        stats: %{
          combat_stats: Map.merge(attacker.combat_stats, %{critical: 0, passive_atk: 0}),
          derived_stats: %{aspd: 150}
        }
      })

    target_state =
      struct(MobState, %{
        instance_id: @target_id,
        hp: 100,
        max_hp: 100,
        is_dead: false,
        x: 150,
        y: 150,
        map_name: "prontera"
      })

    Mimic.copy(MobState)
    stub(MobState, :to_combatant, fn ^target_state -> target end)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {FakeUnit, target_state, self()}}
    end)

    stub(UnitRegistry, :get_unit_info, fn :player, @attacker_id -> {:ok, %{stats: %{}}} end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id ->
      {:ok, {150, 150, "prontera"}}
    end)

    stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
      {:ok, %{damage: 75, is_critical: false}}
    end)

    %{attacker: player_state.stats, player_state: player_state}
  end

  describe "Interpreter.attack_replacement/2" do
    test "is :normal when the unit holds no implementing status" do
      assert StatusInterpreter.attack_replacement(:player, @attacker_id) == :normal
    end

    test "returns the first implementing status' replacement" do
      hold_replacement(3)

      assert {:skill_attack, opts} = StatusInterpreter.attack_replacement(:player, @attacker_id)
      assert opts[:skill_id] == 9_999
      assert opts[:skill_level] == 3
    end
  end

  describe "execute_attack/3 with a status replacement" do
    test "runs the skill attack and returns :ok without a combo stage",
         %{attacker: attacker, player_state: player_state} do
      hold_replacement(1)
      reject(&Passives.attack_replacement/1)
      expect(MobSession, :apply_damage, fn _pid, 75, _attacker_id -> :ok end)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, @target_id)
      end)
    end

    test "ignore_flee skips the hit roll", %{attacker: attacker, player_state: player_state} do
      hold_replacement(1)
      reject(&HitCalculations.calculate_hit_result/2)
      expect(MobSession, :apply_damage, fn _pid, 75, _attacker_id -> :ok end)

      capture_log(fn ->
        assert :ok = Combat.execute_attack(attacker, player_state, @target_id)
      end)
    end

    test "the passive replacement path is untouched without a status",
         %{attacker: attacker, player_state: player_state} do
      stub(Passives, :attack_replacement, fn _player ->
        {:skill_attack, [skill_id: 263, skill_level: 5, skill_ratio: 200, skip_crit: true],
         :quadruple}
      end)

      stub(HitCalculations, :calculate_hit_result, fn _a, _t -> :hit end)

      assert {:ok, {:combo, :quadruple, {:mob, @target_id}, _delay}} =
               Combat.execute_attack(attacker, player_state, @target_id)
    end
  end

  defp hold_replacement(level) do
    :ok =
      StatusStorage.apply_status(:player, @attacker_id, :sc_test_attack_replacement,
        val1: level,
        duration: 60_000
      )
  end

  defp combatant(unit_id, type) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: type,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{atk: 0, def: 0, hit: 200, flee: 0, perfect_dodge: 0},
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 5,
      attack_delay_ms: 500,
      position: {150, 150},
      map_name: "prontera"
    })
  end
end
