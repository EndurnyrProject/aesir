defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RaidTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Raid
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager

  setup :setup_ets_tables

  test "applies for ten seconds and amplifies all incoming damage" do
    assert %{icon: :raid} = Raid.metadata()
    %{unit_id: target_id} = start_mob_session()

    assert :ok =
             Interpreter.apply_status(:mob, target_id, :sc_raid,
               caster_id: target_id,
               source_type: :mob,
               bypass_resistance: true
             )

    assert %StatusEntry{started_at: started_at, expires_at: expires_at} =
             StatusStorage.get_status(:mob, target_id, :sc_raid)

    assert expires_at - started_at == 10_000
    assert 130 = Interpreter.absorb_damage(:mob, target_id, 100, %{dmg_type: :physical})
    assert 130 = Interpreter.absorb_damage(:mob, target_id, 100, %{dmg_type: :magic})
    assert 130 = Interpreter.absorb_damage(:mob, target_id, 100, %{dmg_type: :misc})

    :ok =
      StatusStorage.update_status(:mob, target_id, :sc_raid, fn status ->
        %{status | expires_at: System.monotonic_time(:millisecond) - 1}
      end)

    assert {:noreply, state} = StatusTickManager.handle_info(:tick, %StatusTickManager.State{})
    Process.cancel_timer(state.tick_timer)

    refute StatusStorage.has_status?(:mob, target_id, :sc_raid)
    assert 100 = Interpreter.absorb_damage(:mob, target_id, 100, %{dmg_type: :physical})
  end

  test "amplifies incoming damage by fifteen percent on bosses" do
    %{unit_id: boss_id} = start_mob_session(modes: [:boss])

    assert :ok =
             Interpreter.apply_status(:mob, boss_id, :sc_raid,
               caster_id: boss_id,
               source_type: :mob,
               bypass_resistance: true
             )

    assert 115 = Interpreter.absorb_damage(:mob, boss_id, 100, %{dmg_type: :physical})
  end
end
