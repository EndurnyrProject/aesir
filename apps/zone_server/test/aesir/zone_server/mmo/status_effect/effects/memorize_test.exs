defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MemorizeTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Memorize
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @id 7_001
  @target {:player, @id}
  @cold_bolt 14
  @heal 28

  setup do
    state = %PlayerState{
      character_id: @id,
      stats: %{progression: %{learned_skills: %{@cold_bolt => 10, 403 => 1}}}
    }

    :ok = UnitRegistry.register_unit(:player, @id, PlayerState, state, self())
    :ok
  end

  defp applied do
    {:ok, instance} =
      Memorize.on_apply(@target, %StatusEntry{type: :sc_memorize, val1: 1, state: %{}}, %{})

    instance
  end

  test "halves variable cast time for five charges in both modes" do
    assert %{cast_time_reduction: 50, charges: 5} = applied().state
  end

  test "five resolved learned casts spend it" do
    final =
      Enum.reduce(1..4, applied(), fn _cast, instance ->
        {:ok, next} =
          Memorize.on_committed_action(@target, instance, {:skill_resolved, @cold_bolt}, %{})

        next
      end)

    assert final.state.charges == 1

    assert Memorize.on_committed_action(@target, final, {:skill_resolved, @cold_bolt}, %{}) ==
             :remove
  end

  test "Foresight's own resolution does not spend a charge" do
    instance = applied()

    assert Memorize.on_committed_action(@target, instance, {:skill_resolved, 403}, %{}) ==
             {:ok, instance}
  end

  test "unlearned skills, cast starts and normal attacks keep every charge" do
    instance = applied()

    for action <- [{:skill_resolved, @heal}, {:skill, @cold_bolt}, :normal_attack] do
      assert Memorize.on_committed_action(@target, instance, action, %{}) == {:ok, instance}
    end
  end
end
