defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.StopTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stop
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    player_id = :rand.uniform(100_000)
    :ok = UnitRegistry.register_player(player_state(player_id), self())

    %{player_id: player_id}
  end

  test "temporarily blocks movement without blocking attacks or skills", %{player_id: player_id} do
    assert :ok = Interpreter.apply_status(:player, player_id, :sc_stop, duration: 3_000)

    assert %{expires_at: expires_at} = StatusStorage.get_status(:player, player_id, :sc_stop)
    assert is_integer(expires_at)
    refute Interpreter.can_move?(:player, player_id)
    assert Interpreter.can_attack?(:player, player_id)
    assert Interpreter.can_use_skill?(:player, player_id)
    assert Interpreter.can_use_skill?(:player, player_id, 28)
  end

  test "declares the canonical Stop icon" do
    assert Stop.metadata().icon == :stop
  end

  test "is transient and cleared on map change", %{player_id: player_id} do
    assert Stop.metadata().no_save
    assert Stop.metadata().remove_on_map_change
    assert :ok = Interpreter.apply_status(:player, player_id, :sc_stop, duration: 3_000)

    assert :ok = Interpreter.remove_on_map_change(:player, player_id)
    refute StatusStorage.has_status?(:player, player_id, :sc_stop)
  end

  defp player_state(player_id) do
    %Character{
      id: player_id,
      account_id: player_id,
      name: "StopTest",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
    |> PlayerState.new()
  end
end
