defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandlerTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    :ok
  end

  test "no-recover blocks equipment regen but preserves equipment loss" do
    char_id = 88_003

    equipment = %{
      {:hp_regen_bonus, 500} => 10,
      {:hp_loss_bonus, 500} => 5,
      {:sp_regen_bonus, 500} => 10,
      {:sp_loss_bonus, 500} => 4
    }

    game_state =
      PlayerStateFixture.build(%{
        character_id: char_id,
        equip_regen_accumulators: %{},
        stats: %{
          current_state: %{hp: 100, sp: 100},
          derived_stats: %{max_hp: 200, max_sp: 200},
          modifiers: %{equipment: equipment}
        }
      })

    state = %SessionState{game_state: game_state, connection_pid: self()}
    :ok = StatusStorage.apply_status(:player, char_id, :sc_norecover_state)
    on_exit(fn -> StatusStorage.remove_status(:player, char_id, :sc_norecover_state) end)

    assert {:noreply, updated} = EquipRegenHandler.handle_tick(state, 500)
    assert updated.game_state.stats.current_state.hp == 95
    assert updated.game_state.stats.current_state.sp == 96
  end
end
