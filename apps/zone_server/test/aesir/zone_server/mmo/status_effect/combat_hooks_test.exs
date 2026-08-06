defmodule Aesir.ZoneServer.Mmo.StatusEffect.CombatHooksTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ReflectShield
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule NormalAttackClaim do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_normal_attack_claim,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def before_normal_attack(_target, _instance, attack_info, _context) do
      send(attack_info.test_pid, {:before_normal_attack, attack_info})

      {:claim, %{damage_rate: 150, poison: %{chance: 50, level: 5, duration: 18_000}}}
    end
  end

  defmodule InvalidNormalAttackClaim do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_invalid_normal_attack_claim,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def before_normal_attack(_target, _instance, _attack_info, _context) do
      {:claim, {:auto_cast, :tf_poison, 5, {:unit, 2}}}
    end
  end

  defmodule RemoveAfterDamage do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_remove_after_damage,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def after_damage_taken(_target, instance, hit_info, _context) do
      send(instance.state.test_pid, {:after_damage_taken, hit_info})
      :remove
    end
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  test "an empty capability index is a no-op" do
    assert Interpreter.before_normal_attack(:player, 1, %{}) == nil
    assert Interpreter.after_damage_taken(:player, 1, %{damage: 1}) == 0
  end

  test "before_normal_attack atomically claims bounded swing metadata" do
    stub_unit_info(1)
    Registry.register_module(NormalAttackClaim)
    assert :sc_test_normal_attack_claim in Registry.statuses_implementing(:before_normal_attack)
    :ok = Interpreter.apply_status(:player, 1, :sc_test_normal_attack_claim)

    attack_info = %{target: {:mob, 2}, element: :poison, test_pid: self()}

    assert Interpreter.before_normal_attack(:player, 1, attack_info) == %{
             damage_rate: 150,
             poison: %{chance: 50, level: 5, duration: 18_000}
           }

    assert_received {:before_normal_attack, ^attack_info}
    refute StatusStorage.has_status?(:player, 1, :sc_test_normal_attack_claim)
    assert Interpreter.before_normal_attack(:player, 1, attack_info) == nil
  end

  test "before_normal_attack rejects arbitrary cast results" do
    stub_unit_info(1)
    Registry.register_module(InvalidNormalAttackClaim)
    :ok = Interpreter.apply_status(:player, 1, :sc_test_invalid_normal_attack_claim)

    assert_raise RuntimeError, ~r/invalid before_normal_attack result/, fn ->
      Interpreter.before_normal_attack(:player, 1, %{})
    end
  end

  test "after_damage_taken receives typed attacker metadata and removes its current generation" do
    stub_unit_info(1)
    Registry.register_module(RemoveAfterDamage)

    :ok =
      Interpreter.apply_status(:player, 1, :sc_test_remove_after_damage,
        state: %{test_pid: self()}
      )

    hit_info = %{damage: 40, attacker: {:mob, 2}, dmg_type: :magic, is_short: false}

    assert Interpreter.after_damage_taken(:player, 1, hit_info) == 0
    assert_received {:after_damage_taken, ^hit_info}
    refute StatusStorage.has_status?(:player, 1, :sc_test_remove_after_damage)
  end

  test "Reflect Shield explicitly filters non-short physical and reflected hits" do
    entry = %StatusEntry{type: :sc_reflectshield, val1: 5}
    target = {:player, 1}

    assert {:reflect, 25} =
             ReflectShield.after_damage_taken(
               target,
               entry,
               %{damage: 100, dmg_type: :physical, is_short: true},
               %{}
             )

    assert :ok =
             ReflectShield.after_damage_taken(
               target,
               entry,
               %{damage: 100, dmg_type: :physical, is_short: false},
               %{}
             )

    assert :ok =
             ReflectShield.after_damage_taken(
               target,
               entry,
               %{damage: 100, dmg_type: :magic, is_short: true},
               %{}
             )

    assert :ok =
             ReflectShield.after_damage_taken(
               target,
               entry,
               %{damage: 100, dmg_type: :physical, is_short: true, reflected: true},
               %{}
             )
  end

  defp stub_unit_info(unit_id) do
    stub(UnitRegistry, :get_unit_info, fn :player, ^unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :formless,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{
           max_hp: 100,
           max_sp: 50,
           hp: 100,
           sp: 50,
           level: 1,
           base_level: 1,
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
end
