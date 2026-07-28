defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BardSongStatusesTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AppleIdun
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AssassinCross
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoemBragi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Whistle
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @statuses [:sc_whistle, :sc_assncross, :sc_poembragi, :sc_appleidun]
  @modules [Whistle, AssassinCross, PoemBragi, AppleIdun]
  @player_id 81_001

  setup :setup_ets_tables

  setup do
    state = PlayerState.new(character(@player_id))
    UnitRegistry.register_unit(:player, @player_id, PlayerState, state, self())
    :ok
  end

  test "definitions are finite, persistent through lifecycle boundaries, and mutually replacing" do
    for module <- @modules do
      metadata = module.metadata()
      assert metadata.duration == 180_000
      assert metadata.permanent == false
      assert metadata.no_save == false
      assert metadata.no_dispel == true
      assert metadata.remove_on_death == false
      assert metadata.remove_on_map_change == false
      assert Enum.sort(metadata.end_on_start) == Enum.sort(@statuses)
    end
  end

  test "definitions read only their pinned status parameters" do
    whistle = %StatusEntry{type: :sc_whistle, val1: 10, val2: 38, val3: 50, state: %{}}
    sunset = %StatusEntry{type: :sc_assncross, val1: 10, val2: 20, state: %{}}
    idun = %StatusEntry{type: :sc_appleidun, val1: 10, val2: 20, val3: 999, state: %{}}
    bragi = %StatusEntry{type: :sc_poembragi, val1: 10, val2: 20, val3: 30, state: %{}}

    assert Whistle.modifiers(whistle, %{}) == %{flee: 38, perfect_dodge: 50}
    assert AssassinCross.modifiers(sunset, %{}) == %{aspd: 20}
    assert AppleIdun.modifiers(idun, %{}) == %{max_hp_rate: 20}

    assert {:ok, %StatusEntry{state: %{cast_time_reduction: 20, delay_reduction: 30}}} =
             PoemBragi.on_apply({:player, @player_id}, bragi, %{})
  end

  test "different songs replace in both orders" do
    for {first, second} <- [
          {:sc_whistle, :sc_assncross},
          {:sc_assncross, :sc_whistle}
        ] do
      assert :ok = apply_song(first, val2: 10)
      assert :ok = apply_song(second, val2: 20)

      refute StatusStorage.has_status?(:player, @player_id, first)

      assert %StatusEntry{val2: 20, expires_at: expires_at} =
               StatusStorage.get_status(:player, @player_id, second)

      assert is_integer(expires_at)
      assert expires_at > System.monotonic_time(:millisecond)
      Interpreter.remove_all_statuses(:player, @player_id)
    end
  end

  test "a same song always replaces its prior value" do
    assert :ok = apply_song(:sc_whistle, val2: 99)
    first = StatusStorage.get_status(:player, @player_id, :sc_whistle)

    assert :ok = apply_song(:sc_whistle, val2: 1)
    second = StatusStorage.get_status(:player, @player_id, :sc_whistle)

    assert second.val2 == 1
    assert second.generation > first.generation
  end

  test "death and map-change cleanup preserve a finite song" do
    assert :ok = apply_song(:sc_appleidun, val2: 10)

    assert :ok = Interpreter.remove_on_death(:player, @player_id)
    assert StatusStorage.has_status?(:player, @player_id, :sc_appleidun)

    assert :ok = Interpreter.remove_on_map_change(:player, @player_id)

    assert %StatusEntry{expires_at: expires_at} =
             StatusStorage.get_status(:player, @player_id, :sc_appleidun)

    assert is_integer(expires_at)
  end

  defp apply_song(status_id, params) do
    Interpreter.apply_status(
      :player,
      @player_id,
      status_id,
      Keyword.merge(params, caster_id: @player_id)
    )
  end

  defp character(id) do
    %Character{
      id: id,
      account_id: id,
      name: "SongTarget",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 19,
      base_level: 100,
      job_level: 50,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10
    }
  end
end
