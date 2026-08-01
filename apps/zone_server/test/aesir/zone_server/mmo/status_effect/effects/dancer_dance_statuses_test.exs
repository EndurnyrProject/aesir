defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DancerDanceStatusesTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DontForgetMe
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.FortuneKiss
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Humming
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ServiceForYou
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @dances [:sc_humming, :sc_dontforgetme, :sc_fortunekiss, :sc_serviceforyou]
  @modules [Humming, DontForgetMe, FortuneKiss, ServiceForYou]
  @bard_songs [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun]
  @slow_grace_strips [
    :sc_increaseagi,
    :sc_adrenaline,
    :sc_adrenaline2,
    :sc_spearquicken,
    :sc_twohandquicken,
    :sc_onehand,
    :sc_acceleration,
    :sc_merc_quicken
  ]
  @player_id 82_001

  setup :setup_ets_tables

  setup do
    state = PlayerState.new(character(@player_id))
    UnitRegistry.register_unit(:player, @player_id, PlayerState, state, self())
    :ok
  end

  test "focus ballet grants HIT from skill level" do
    level_one = entry(:sc_humming, 1)
    level_ten = entry(:sc_humming, 10)

    assert Humming.modifiers(level_one, %{}) == %{hit: 4}
    assert Humming.modifiers(level_ten, %{}) == %{hit: 40}
  end

  test "lady luck grants flat critical and critical damage rate from skill level" do
    level_one = entry(:sc_fortunekiss, 1)
    level_ten = entry(:sc_fortunekiss, 10)

    assert FortuneKiss.modifiers(level_one, %{}) == %{critical: 1, critical_rate: 2}
    assert FortuneKiss.modifiers(level_ten, %{}) == %{critical: 10, critical_rate: 20}
  end

  test "gypsy's kiss uses the level-ten MaxSP branch and reduces SP costs" do
    level_one = entry(:sc_serviceforyou, 1)
    level_nine = entry(:sc_serviceforyou, 9)
    level_ten = entry(:sc_serviceforyou, 10)

    assert ServiceForYou.modifiers(level_one, %{}) == %{max_sp_rate: 10, sp_cost_rate: -6}
    assert ServiceForYou.modifiers(level_nine, %{}) == %{max_sp_rate: 18, sp_cost_rate: -14}
    assert ServiceForYou.modifiers(level_ten, %{}) == %{max_sp_rate: 20, sp_cost_rate: -15}
  end

  test "slow grace applies converted ASPD-rate and movement penalties" do
    level_one = entry(:sc_dontforgetme, 1)
    level_ten = entry(:sc_dontforgetme, 10)

    assert DontForgetMe.modifiers(level_one, %{}) == %{aspd_rate: -3, movement_speed: 7}
    assert DontForgetMe.modifiers(level_ten, %{}) == %{aspd_rate: -30, movement_speed: 25}
  end

  test "dance definitions survive cleanup and form a dancer-only exclusion group" do
    for module <- @modules do
      metadata = module.metadata()
      assert metadata.no_save == false
      assert metadata.no_dispel == true
      assert metadata.remove_on_death == false
      assert metadata.remove_on_map_change == false
      assert Enum.sort(metadata.end_on_start -- @slow_grace_strips) == Enum.sort(@dances)
    end

    assert Humming.metadata().duration == 180_000
    assert FortuneKiss.metadata().duration == 180_000
    assert ServiceForYou.metadata().duration == 180_000
    assert DontForgetMe.metadata().duration == 60_000

    assert Enum.sort(DontForgetMe.metadata().end_on_start -- @dances) ==
             Enum.sort(@slow_grace_strips)
  end

  test "dancer dances survive death, map changes, and Dispel" do
    for dance <- @dances do
      assert :ok = apply_status(dance)
      assert :ok = Interpreter.remove_on_death(:player, @player_id)
      assert :ok = Interpreter.remove_on_map_change(:player, @player_id)
      assert :ok = Dispel.dispel({:player, @player_id})
      assert StatusStorage.has_status?(:player, @player_id, dance)
      Interpreter.remove_all_statuses(:player, @player_id)
    end
  end

  test "dancer dances replace each other in both directions" do
    for first <- @dances, second <- @dances, first != second do
      assert :ok = apply_status(first)
      assert :ok = apply_status(second)

      refute StatusStorage.has_status?(:player, @player_id, first)
      assert StatusStorage.has_status?(:player, @player_id, second)
      Interpreter.remove_all_statuses(:player, @player_id)
    end
  end

  test "dancer dances leave every bard song active" do
    for bard_song <- @bard_songs, dance <- @dances do
      assert :ok = apply_status(bard_song)
      assert :ok = apply_status(dance)

      assert StatusStorage.has_status?(:player, @player_id, bard_song)
      assert StatusStorage.has_status?(:player, @player_id, dance)
      Interpreter.remove_all_statuses(:player, @player_id)
    end
  end

  test "slow grace strips registered speed buffs and skips unimplemented entries" do
    unimplemented = [
      :sc_onehand,
      :sc_acceleration,
      :sc_merc_quicken
    ]

    for status <- unimplemented do
      assert Registry.get_definition(status) == nil
    end

    for status <- [
          :sc_increaseagi,
          :sc_spearquicken,
          :sc_twohandquicken,
          :sc_adrenaline,
          :sc_adrenaline2
        ] do
      assert :ok = apply_status(status)
    end

    assert :ok = apply_status(:sc_dontforgetme)

    for status <- @slow_grace_strips do
      refute StatusStorage.has_status?(:player, @player_id, status)
    end
  end

  test "slow grace fails against speed up" do
    assert :ok = apply_status(:sc_speedup1)
    assert {:error, :conflict} = apply_status(:sc_dontforgetme)
    refute StatusStorage.has_status?(:player, @player_id, :sc_dontforgetme)
  end

  defp entry(type, level), do: %StatusEntry{type: type, val1: level, state: %{}}

  defp apply_status(status_id) do
    Interpreter.apply_status(:player, @player_id, status_id,
      val1: 1,
      caster_id: @player_id,
      bypass_resistance: true
    )
  end

  defp character(id) do
    %Character{
      id: id,
      account_id: id,
      name: "DanceTarget",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 20,
      base_level: 100,
      job_level: 50,
      sex: "F",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end
end
