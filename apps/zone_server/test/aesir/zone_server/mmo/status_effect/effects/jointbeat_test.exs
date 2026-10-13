defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.JointbeatTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Jointbeat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    :ok =
      UnitRegistry.register_player(
        PlayerStateFixture.build(%{character_id: 5_140, stats: %{combat_stats: %CombatStats{}}}),
        self()
      )

    :ok
  end

  test "a neck wound also applies Bleeding at the wound level" do
    :rand.seed(:exsss, {2, 3, 4})

    assert :ok =
             Interpreter.apply_status(:player, 5_140, :sc_jointbeat,
               val1: 7,
               val2: Jointbeat.flag(:neck),
               duration: 30_000,
               caster_id: 5_140,
               bypass_resistance: true
             )

    assert %{val1: 7} = StatusStorage.get_status(:player, 5_140, :sc_bleeding)
  end

  test "an ankle wound does not start Bleeding" do
    assert :ok =
             Interpreter.apply_status(:player, 5_140, :sc_jointbeat,
               val1: 7,
               val2: Jointbeat.flag(:ankle),
               duration: 30_000,
               caster_id: 5_140,
               bypass_resistance: true
             )

    refute StatusStorage.has_status?(:player, 5_140, :sc_bleeding)
  end

  test "the six break types have their own movement, ASPD, DEF and ATK penalties" do
    assert Jointbeat.breaks() == [1, 2, 4, 8, 16, 32]

    expected = %{
      ankle: %{movement_speed: 50},
      wrist: %{aspd_rate: -25},
      knee: %{movement_speed: 30, aspd_rate: -10},
      shoulder: %{def2_rate: -50},
      waist: %{def2_rate: -25, atk_rate: -25},
      neck: %{}
    }

    for {break, modifiers} <- expected do
      assert Jointbeat.modifiers(%StatusEntry{val2: Jointbeat.flag(break)}, %{}) == modifiers
    end
  end
end
