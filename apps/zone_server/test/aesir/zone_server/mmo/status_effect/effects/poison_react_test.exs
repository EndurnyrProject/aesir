defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoisonReactTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoisonReact
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  test "real application initializes level, charges, chance, and block mode" do
    holder = register_holder(1_001)

    assert :ok = arm(holder, 7)

    assert %{val1: 7, state: %{level: 7, charges: 3, chance: 50, mode: :block}} =
             StatusStorage.get_status(:player, holder.character_id, :sc_poisonreact)
  end

  test "a Poison swing from either source kind atomically arms boost and sends one intent" do
    for attacker <- [{:player, 2_001}, {:mob, 3_001}] do
      holder_id = 1_000 + elem(attacker, 1)
      holder = register_holder(holder_id)
      assert :ok = arm(holder, 6)

      assert {:intercept, :poison_react} =
               Interpreter.before_weapon_hit(:player, holder_id, attack_info(attacker, :poison))

      assert_receive {:attack_intent, ^attacker}
      refute_receive {:attack_intent, ^attacker}

      assert %{state: %{mode: :boost}} =
               StatusStorage.get_status(:player, holder_id, :sc_poisonreact)

      assert :continue =
               Interpreter.before_weapon_hit(:player, holder_id, attack_info(attacker, :poison))

      refute_receive {:attack_intent, ^attacker}
    end
  end

  test "a non-Poison delivered basic hit consumes one charge after a successful roll even when Envenom rejects" do
    holder = register_holder(1_002)
    assert :ok = arm(holder, 6)
    set_chance(holder.character_id, 100)

    expect(Combat, :execute_skill_attack, fn ^holder, {:mob, 3_002}, opts ->
      assert opts[:skill_id] == 52
      assert opts[:skill_level] == 5
      {:error, :out_of_range}
    end)

    assert 0 =
             Interpreter.after_damage_taken(
               :player,
               holder.character_id,
               delivered_hit({:mob, 3_002})
             )

    assert %{state: %{charges: 2, mode: :block}} =
             StatusStorage.get_status(:player, holder.character_id, :sc_poisonreact)
  end

  test "a failed roll consumes no charge and attempts no Envenom" do
    holder = register_holder(1_003)
    assert :ok = arm(holder, 6)
    set_chance(holder.character_id, 0)
    reject(&Combat.execute_skill_attack/3)

    assert 0 =
             Interpreter.after_damage_taken(
               :player,
               holder.character_id,
               delivered_hit({:player, 2_003})
             )

    assert %{state: %{charges: 3}} =
             StatusStorage.get_status(:player, holder.character_id, :sc_poisonreact)
  end

  test "the final successful counter roll removes the status" do
    holder = register_holder(1_004)
    assert :ok = arm(holder, 2)
    set_chance(holder.character_id, 100)

    expect(Combat, :execute_skill_attack, fn ^holder, {:mob, 3_004}, _opts ->
      {:ok, %{hit?: false}}
    end)

    assert 0 =
             Interpreter.after_damage_taken(
               :player,
               holder.character_id,
               delivered_hit({:mob, 3_004})
             )

    refute StatusStorage.has_status?(:player, holder.character_id, :sc_poisonreact)
  end

  test "non-basic or non-physical delivered damage does not roll or consume" do
    holder = register_holder(1_005)
    assert :ok = arm(holder, 6)
    set_chance(holder.character_id, 100)
    reject(&Combat.execute_skill_attack/3)

    hit = delivered_hit({:mob, 3_005})

    assert 0 =
             Interpreter.after_damage_taken(:player, holder.character_id, %{
               hit
               | basic_attack?: false
             })

    assert 0 =
             Interpreter.after_damage_taken(:player, holder.character_id, %{
               hit
               | dmg_type: :magic
             })

    assert %{state: %{charges: 3}} =
             StatusStorage.get_status(:player, holder.character_id, :sc_poisonreact)
  end

  test "the next ordinary swing claims boost once and removes the status" do
    holder = register_holder(1_006)
    assert :ok = arm(holder, 8)

    assert {:intercept, :poison_react} =
             Interpreter.before_weapon_hit(
               :player,
               holder.character_id,
               attack_info({:mob, 3_006}, :poison)
             )

    assert_receive {:attack_intent, {:mob, 3_006}}

    attack_info = %{target: {:mob, 3_006}, element: :neutral}

    assert Interpreter.before_normal_attack(:player, holder.character_id, attack_info) == %{
             damage_rate: 240,
             poison: %{chance: 50, level: 8, duration: 60_000}
           }

    assert Interpreter.before_normal_attack(:player, holder.character_id, attack_info) == nil
    refute StatusStorage.has_status?(:player, holder.character_id, :sc_poisonreact)
  end

  test "a stale block row cannot overwrite a newer application" do
    holder = register_holder(1_007)
    assert :ok = arm(holder, 4)
    stale = StatusStorage.get_status(:player, holder.character_id, :sc_poisonreact)
    assert :ok = arm(holder, 10)

    assert :continue =
             PoisonReact.before_weapon_hit(
               {:player, holder.character_id},
               stale,
               attack_info({:mob, 3_007}, :poison),
               %{}
             )

    refute_receive {:attack_intent, _}

    assert %{val1: 10, state: %{mode: :block}} =
             StatusStorage.get_status(:player, holder.character_id, :sc_poisonreact)
  end

  defp register_holder(id) do
    holder =
      PlayerStateFixture.build(%{
        character_id: id,
        x: 100,
        y: 100,
        map_name: "poison_react_test",
        stats: %{combat_stats: %CombatStats{}}
      })

    :ok = UnitRegistry.register_unit(:player, id, PlayerState, holder, self())
    holder
  end

  defp arm(holder, level) do
    Interpreter.apply_status(:player, holder.character_id, :sc_poisonreact,
      val1: level,
      duration: 60_000,
      caster_id: holder.character_id,
      source_type: :player
    )
  end

  defp set_chance(holder_id, chance) do
    StatusStorage.update_status(:player, holder_id, :sc_poisonreact, fn entry ->
      put_in(entry.state.chance, chance)
    end)
  end

  defp attack_info(attacker, element) do
    %{
      attacker: attacker,
      target: {:player, 1_001},
      basic_attack?: true,
      element: element
    }
  end

  defp delivered_hit(attacker) do
    %{
      attacker: attacker,
      damage: 10,
      dmg_type: :physical,
      is_short: false,
      element: :neutral,
      basic_attack?: true
    }
  end
end
