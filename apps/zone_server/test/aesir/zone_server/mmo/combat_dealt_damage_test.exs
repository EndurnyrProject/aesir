defmodule Aesir.ZoneServer.Mmo.CombatDealtDamageTest do
  @moduledoc """
  The attacker-side `on_dealt_damage` seam in the combat path.

  `Combat.execute_attack/3` runs inside the attacker's own `PlayerSession`, so
  these tests call it straight from the test process: the hook's `self()` and
  the `{:auto_cast, ...}` cast target are then the test process itself, which is
  what the ordering assertions read.
  """
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @moduletag :capture_log

  @attacker_id 1001
  @mob_id 2001
  @map_name "prontera"

  # MG_FIREBOLT, a real catalogued skill.
  @bolt_id 19

  defmodule ProcStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_proc,
      properties: [:buff]

    @impl true
    def on_dealt_damage(target, instance, hit_info, _context) do
      send(self(), {:hook_ran, self(), target, hit_info})
      {:ok, instance, [{:auto_cast, :mg_firebolt, 3, hit_info.target}]}
    end
  end

  defmodule UnknownSkillStatus do
    @moduledoc false
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_unknown_skill,
      properties: [:buff]

    @impl true
    def on_dealt_damage(_target, instance, hit_info, _context) do
      {:ok, instance, [{:auto_cast, :sa_not_a_real_skill, 1, hit_info.target}]}
    end
  end

  defmodule FakeUnit do
    @moduledoc false
    defstruct [:combatant, :stats, :x, :y]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

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
      weapon: %{type: :fist, element: :fire, size: :medium},
      attack_range: 5,
      attack_delay_ms: 500,
      position: {150, 150},
      map_name: @map_name
    })
  end

  defp stub_unit_info do
    stub(UnitRegistry, :get_unit_info, fn unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: unit_type,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 1000,
           max_sp: 100,
           hp: 1000,
           sp: 100,
           level: 50,
           base_level: 50,
           str: 1,
           agi: 1,
           vit: 1,
           int: 1,
           dex: 1,
           luk: 1,
           mdef: 0
         }
       }}
    end)
  end

  setup do
    attacker = combatant(@attacker_id, :player)
    target_state = %FakeUnit{combatant: combatant(@mob_id, :mob), x: 150, y: 150}

    stub(UnitRegistry, :get_unit, fn :mob, @mob_id -> {:ok, {FakeUnit, target_state, self()}} end)
    stub(SpatialIndex, :get_unit_position, fn :mob, @mob_id -> {:ok, {150, 150, @map_name}} end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Passives, :attack_procs, fn _player -> %{} end)
    stub(EquipBreak, :resolve, fn _attacker, _target -> [] end)

    stub(DamageCalculator, :calculate_damage, fn _a, _d ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(DamageCalculator, :calculate_damage, fn _a, _d, _opts ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(MagicDamageCalculator, :calculate_magic_damage, fn _a, _d, _opts ->
      {:ok, %{damage: 50, is_critical: false}}
    end)

    stub(MobSession, :apply_damage, fn _pid, damage, _attacker_id ->
      send(self(), {:damage_applied, damage})
      :ok
    end)

    stub_unit_info()

    %{player_state: %FakeUnit{combatant: attacker, x: 150, y: 150}, stats: attacker}
  end

  defp arm_proc_status do
    Registry.register_module(ProcStatus)
    :ok = Interpreter.apply_status(:player, @attacker_id, :sc_test_proc)
  end

  defp mailbox do
    {:messages, messages} = Process.info(self(), :messages)
    messages
  end

  describe "on_dealt_damage on a basic attack" do
    test "runs the hook in the attacker's process with the landed hit's info", ctx do
      arm_proc_status()

      assert :ok = Combat.execute_attack(ctx.stats, ctx.player_state, @mob_id)

      attacker_pid = self()
      assert_received {:hook_ran, ^attacker_pid, {:player, @attacker_id}, hit_info}
      assert hit_info == %{target: {:mob, @mob_id}, damage: 50, element: :fire}
    end

    test "drains the auto-cast to the attacker's session only after the hit commits", ctx do
      arm_proc_status()

      assert :ok = Combat.execute_attack(ctx.stats, ctx.player_state, @mob_id)

      assert [
               {:damage_applied, 50},
               {:hook_ran, _pid, _target, _hit_info},
               {:"$gen_cast", {:auto_cast, @bolt_id, 3, {:mob, @mob_id}}}
             ] = mailbox()
    end

    # Mirrors the break roll: a Double Attack swing is one attack, not two.
    test "fires once per swing, not once per hit of a multi-hit proc", ctx do
      arm_proc_status()
      stub(Passives, :attack_procs, fn _player -> %{multi_hit: 2} end)

      assert :ok = Combat.execute_attack(ctx.stats, ctx.player_state, @mob_id)

      assert [
               {:damage_applied, 50},
               {:damage_applied, 50},
               {:hook_ran, _pid, _target, _hit_info},
               {:"$gen_cast", {:auto_cast, @bolt_id, 3, {:mob, @mob_id}}}
             ] = mailbox()
    end

    test "does not fire for an attacker holding no implementing status", ctx do
      assert :ok = Combat.execute_attack(ctx.stats, ctx.player_state, @mob_id)

      assert_received {:damage_applied, 50}
      refute_received {:"$gen_cast", {:auto_cast, _, _, _}}
    end

    test "an auto-cast naming an uncatalogued skill fails hard rather than skipping", ctx do
      Registry.register_module(UnknownSkillStatus)
      :ok = Interpreter.apply_status(:player, @attacker_id, :sc_test_unknown_skill)

      assert_raise RuntimeError, ~r/sa_not_a_real_skill/, fn ->
        Combat.execute_attack(ctx.stats, ctx.player_state, @mob_id)
      end
    end
  end

  describe "on_dealt_damage is weapon-attack only" do
    test "a magic attack never fires the hook", ctx do
      arm_proc_status()

      assert :ok =
               Combat.execute_magic_attack(ctx.player_state, @mob_id,
                 skill_id: @bolt_id,
                 skill_level: 1,
                 skill_ratio: 100,
                 element: :fire
               )

      assert_received {:damage_applied, 50}
      refute_received {:hook_ran, _, _, _}
      refute_received {:"$gen_cast", {:auto_cast, _, _, _}}
    end

    test "a physical skill attack never fires the hook", ctx do
      arm_proc_status()

      assert :ok =
               Combat.execute_skill_attack(ctx.player_state, @mob_id,
                 skill_id: 7,
                 skill_level: 1,
                 skill_ratio: 100
               )

      assert_received {:damage_applied, 50}
      refute_received {:hook_ran, _, _, _}
      refute_received {:"$gen_cast", {:auto_cast, _, _, _}}
    end
  end
end
