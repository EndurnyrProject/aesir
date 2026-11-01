defmodule Aesir.ZoneServer.Mmo.StatusEffect.ZeroDurationTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule ZeroStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_zero_duration,
      target_types: [:player],
      no_dispel: false,
      no_clear_buff: false
  end

  setup :setup_ets_tables

  setup do
    player =
      PlayerStateFixture.build(%{
        character_id: 7_704,
        account_id: 7_704,
        stats: %{combat_stats: %CombatStats{}}
      })

    :ok = UnitRegistry.register_player(player, self())
    :ok = Registry.register_module(ZeroStatus)
    %{id: player.character_id}
  end

  test "ordinary zero duration becomes one millisecond without changing infinity or loads" do
    roll = fn _rate -> true end

    assert {:ok, 1} = Resistance.roll_chance(5_000, 0, roll)
    assert {:ok, 30_000} = Resistance.roll_chance(5_000, 30_000, roll)
    assert {:ok, nil} = Resistance.roll_chance(5_000, nil, roll)
    assert :resisted = Resistance.roll_chance(0, 0, roll)
    assert :resisted = Resistance.roll_chance(5_000, 0, fn _rate -> false end)
  end

  test "successful ordinary zero-duration starts get an exact one millisecond deadline", %{id: id} do
    for source <- [[], [caster_id: 1_000_000, source_type: :player]] do
      before = System.monotonic_time(:millisecond)

      assert :ok =
               Interpreter.apply_status(
                 :player,
                 id,
                 :sc_test_zero_duration,
                 Keyword.merge([duration: 0], source)
               )

      after_start = System.monotonic_time(:millisecond)
      entry = StatusStorage.get_status(:player, id, :sc_test_zero_duration)
      assert entry.started_at in before..after_start
      assert entry.expires_at == entry.started_at + 1
    end
  end

  test "loaded and explicit avoidance-bypass durations are not normalized", %{id: id} do
    assert :ok =
             Interpreter.apply_status(:player, id, :sc_test_zero_duration,
               duration: 30_000,
               loaded: true
             )

    entry = StatusStorage.get_status(:player, id, :sc_test_zero_duration)
    assert entry.expires_at == entry.started_at + 30_000

    assert {:error, :invalid_duration} =
             Interpreter.apply_status(:player, id, :sc_test_zero_duration,
               duration: 0,
               loaded: true
             )

    assert :ok =
             Interpreter.apply_status(:player, id, :sc_test_zero_duration,
               duration: 30_000,
               success_rate: 0,
               no_avoid: true
             )

    entry = StatusStorage.get_status(:player, id, :sc_test_zero_duration)
    assert entry.expires_at == entry.started_at + 30_000
  end
end
