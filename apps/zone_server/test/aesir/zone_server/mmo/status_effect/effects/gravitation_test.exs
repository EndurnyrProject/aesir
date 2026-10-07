defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GravitationTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gravitation
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Manager)
    :ok
  end

  @target {:player, 9_001}

  defp instance(self?), do: %{val1: 3, state: %{self?: self?, group_id: 77}}

  test "slows attack speed by 5% per level" do
    assert Gravitation.modifiers(instance(false), %{}) == %{aspd_rate: -15}
  end

  test "the caster's own instance collapses on damage and tears its field down" do
    assert Gravitation.on_damage(@target, instance(true), %{damage: 10}, %{}) == :remove

    expect(Manager, :destroy_async, fn 77 -> :ok end)
    assert Gravitation.on_expire(@target, instance(true), %{}) == :ok
  end

  test "a field occupant's instance survives damage and leaves the field alone" do
    reject(&Manager.destroy_async/1)

    assert Gravitation.on_damage(@target, instance(false), %{damage: 10}, %{}) ==
             {:ok, instance(false)}

    assert Gravitation.on_expire(@target, %{instance(false) | state: %{}}, %{}) == :ok
  end

  test "only the caster's own instance blocks item use" do
    :ok =
      StatusStorage.apply_status(:player, 9_001, :sc_gravitation, val1: 1, state: %{self?: false})

    assert Interpreter.can_use_item?(:player, 9_001)

    :ok = StatusStorage.remove_status(:player, 9_001, :sc_gravitation)

    :ok =
      StatusStorage.apply_status(:player, 9_001, :sc_gravitation, val1: 1, state: %{self?: true})

    refute Interpreter.can_use_item?(:player, 9_001)
  end

  test "only the caster's own instance keeps the holder from sitting" do
    :ok =
      StatusStorage.apply_status(:player, 9_001, :sc_gravitation, val1: 1, state: %{self?: false})

    assert Interpreter.can_sit?(9_001)

    :ok = StatusStorage.remove_status(:player, 9_001, :sc_gravitation)

    :ok =
      StatusStorage.apply_status(:player, 9_001, :sc_gravitation, val1: 1, state: %{self?: true})

    refute Interpreter.can_sit?(9_001)
  end

  describe "can_deal_skill_damage?/4" do
    @cold_bolt 14
    @gravitation 484

    defp hold(self?) do
      :ok =
        StatusStorage.apply_status(:player, 9_001, :sc_gravitation,
          val1: 1,
          state: %{self?: self?}
        )
    end

    @tag game_mode: :pre_renewal
    test "classic: only the channelling caster's other skills are gated" do
      hold(false)
      assert Interpreter.can_deal_skill_damage?(:player, 9_001, @cold_bolt, false)

      :ok = StatusStorage.remove_status(:player, 9_001, :sc_gravitation)
      hold(true)
      refute Interpreter.can_deal_skill_damage?(:player, 9_001, @cold_bolt, false)
      assert Interpreter.can_deal_skill_damage?(:player, 9_001, @gravitation, false)
      assert Interpreter.can_deal_skill_damage?(:player, 9_001, @cold_bolt, true)
      assert Interpreter.can_deal_skill_damage?(:player, 9_002, @cold_bolt, false)
      assert Interpreter.can_deal_skill_damage?(:mob, 9_001, @cold_bolt, false)
    end

    @tag game_mode: :renewal
    test "renewal never gates" do
      hold(true)
      assert Interpreter.can_deal_skill_damage?(:player, 9_001, @cold_bolt, false)
    end
  end

  test "only the caster's own instance roots the holder" do
    :ok =
      StatusStorage.apply_status(:player, 9_001, :sc_gravitation, val1: 1, state: %{self?: false})

    assert Interpreter.can_move?(:player, 9_001)

    :ok = StatusStorage.remove_status(:player, 9_001, :sc_gravitation)

    :ok =
      StatusStorage.apply_status(:player, 9_001, :sc_gravitation, val1: 1, state: %{self?: true})

    refute Interpreter.can_move?(:player, 9_001)
  end
end
