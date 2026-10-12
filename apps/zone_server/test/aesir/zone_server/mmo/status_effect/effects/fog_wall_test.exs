defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWallTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.FogWall
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @instance %{}

  test "spoils normal ranged aim against the holder" do
    assert FogWall.modifiers(@instance, %{}) == %{normal_ranged_hit_taken_flat: 50}
  end

  test "cuts skill hits by a quarter and normal ranged weapon hits to a quarter" do
    skill = %{damage: 101, skill_id: 14, dmg_type: :magic}
    ranged = %{damage: 101, dmg_type: :physical, is_short: false}
    melee = %{damage: 101, dmg_type: :physical, is_short: true}

    assert FogWall.absorb_damage({:mob, 1}, @instance, skill, %{}) == {:ok, 101 - 25, @instance}
    assert FogWall.absorb_damage({:mob, 1}, @instance, ranged, %{}) == {:ok, 25, @instance}
    assert FogWall.absorb_damage({:mob, 1}, @instance, melee, %{}) == {:ok, 101, @instance}
  end

  test "Blind does not run out while the holder stays in the fog" do
    :ok = StatusStorage.apply_status(:mob, 7, :sc_blind, duration: 500)

    assert {:ok, @instance} = FogWall.on_tick({:mob, 7}, @instance, %{})

    remaining =
      StatusStorage.get_status(:mob, 7, :sc_blind).expires_at -
        System.monotonic_time(:millisecond)

    assert remaining > 4_000
  end

  test "leaving ends a player's Blind and leaves a monster blinded for 30 s" do
    player =
      PlayerState.new(%Character{
        id: 7,
        account_id: 7,
        name: "Fogged",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        sex: "M",
        base_level: 1,
        job_level: 1,
        class: 0
      })

    :ok = UnitRegistry.register_unit(:player, 7, PlayerState, player, self())
    :ok = StatusStorage.apply_status(:player, 7, :sc_blind, duration: 500)
    :ok = StatusStorage.apply_status(:mob, 8, :sc_blind, duration: 60_000)
    Process.put({StatusTickManager, :server}, self())

    FogWall.on_expire({:player, 7}, @instance, %{})
    FogWall.on_expire({:mob, 8}, @instance, %{})

    refute StatusStorage.has_status?(:player, 7, :sc_blind)

    blind = StatusStorage.get_status(:mob, 8, :sc_blind)
    remaining = blind.expires_at - System.monotonic_time(:millisecond)

    assert_in_delta remaining, 30_000, 1_000
    assert_receive {:"$gen_cast", {:arm, :mob, 8, ^blind}}
  end
end
