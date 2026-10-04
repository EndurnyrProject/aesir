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
  @foresight 403

  defp register(dex) do
    state = %PlayerState{
      character_id: @id,
      stats: %{
        base_stats: %{dex: dex},
        progression: %{learned_skills: %{@cold_bolt => 10, @foresight => 1}}
      }
    }

    :ok = UnitRegistry.register_unit(:player, @id, PlayerState, state, self())
  end

  defp applied do
    {:ok, instance} =
      Memorize.on_apply(@target, %StatusEntry{type: :sc_memorize, val1: 1, state: %{}}, %{})

    instance
  end

  defp cast(instance, skill_id),
    do: Memorize.on_committed_action(@target, instance, {:skill, skill_id}, %{})

  test "halves variable cast time for five charges" do
    assert %{cast_time_reduction: 50, charges: 5} = applied().state
  end

  test "each learned cast start spends a charge and the fifth ends it" do
    register(50)

    final =
      Enum.reduce(1..4, applied(), fn _cast, instance -> elem(cast(instance, @cold_bolt), 1) end)

    assert final.state.charges == 1
    assert cast(final, @cold_bolt) == :remove
  end

  test "unlearned skills and normal attacks keep every charge" do
    register(50)
    instance = applied()

    assert cast(instance, @heal) == {:ok, instance}
    assert Memorize.on_committed_action(@target, instance, :normal_attack, %{}) == {:ok, instance}
  end

  @tag game_mode: :renewal
  test "renewal: Foresight itself ignores status cast effects and spends nothing" do
    register(50)
    assert cast(applied(), @foresight) == {:ok, applied()}
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal: Foresight itself spends a charge" do
    register(50)
    assert {:ok, %{state: %{charges: 4}}} = cast(applied(), @foresight)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal: a DEX-instant cast never reaches Foresight" do
    register(150)
    assert cast(applied(), @cold_bolt) == {:ok, applied()}
  end
end
