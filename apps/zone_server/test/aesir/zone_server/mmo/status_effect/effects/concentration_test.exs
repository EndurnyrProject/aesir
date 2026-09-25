defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ConcentrationTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Concentration
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @tag game_mode: :renewal
  test "renewal level five gains 15 percent ATK, loses 15 percent DEF, and gains 50 HIT" do
    instance = %StatusEntry{type: :sc_concentration, val1: 5}

    assert Concentration.modifiers(instance, %{}) ==
             %{atk_rate: 15, def_rate: -15, def2_rate: -15, hit: 50}
  end

  @tag game_mode: :pre_renewal
  test "classic level five gains 25 percent ATK, loses 25 percent DEF, and gains 50 HIT" do
    instance = %StatusEntry{type: :sc_concentration, val1: 5}

    assert Concentration.modifiers(instance, %{}) ==
             %{atk_rate: 25, def_rate: -25, def2_rate: -25, hit: 50}
  end

  test "applying Concentration grants Endure; expiry clears only finite Endure" do
    player =
      PlayerState.new(%Character{
        id: 4_001,
        account_id: 4_002,
        name: "LK",
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 90,
        job_level: 50,
        class: 7
      })

    :ok = UnitRegistry.register_player(player, self())

    assert :ok =
             Interpreter.apply_status(:player, 4_001, :sc_concentration,
               caster_id: 4_001,
               val1: 2,
               duration: 30_000
             )

    assert %StatusEntry{val1: 1} = StatusStorage.get_status(:player, 4_001, :sc_endure)
    assert :ok = Interpreter.remove_status(:player, 4_001, :sc_concentration)
    refute StatusStorage.has_status?(:player, 4_001, :sc_endure)

    assert :ok =
             Interpreter.apply_status(:player, 4_001, :sc_concentration,
               caster_id: 4_001,
               val1: 2,
               duration: 30_000
             )

    :ok = StatusStorage.apply_status(:player, 4_001, :sc_endure, val1: 1, val4: 1)
    assert :ok = Interpreter.remove_status(:player, 4_001, :sc_concentration)
    assert %StatusEntry{val4: 1} = StatusStorage.get_status(:player, 4_001, :sc_endure)

    assert :ok =
             Interpreter.apply_status(:player, 4_001, :sc_concentration,
               caster_id: 4_001,
               val1: 2,
               duration: 30_000
             )

    assert %StatusEntry{val4: 1} = StatusStorage.get_status(:player, 4_001, :sc_endure)
  end
end
