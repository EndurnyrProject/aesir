defmodule Aesir.ZoneServer.Unit.Player.Handlers.LifePotionRegenHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @small {:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}}
  @medium {:percent_hp_regen_bonus, {:sc_l_lifepotion, 4_000}}

  setup :set_mimic_private

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    stub(UnitRegistry, :update_unit_state, fn _, _, _ -> :ok end)
    stub(CharacterPersistence, :update_stats, fn _, _, _ -> {:ok, %Character{}} end)
    :ok
  end

  test "status percentage recovery shares the cadence with equipment and clamps at maximum HP" do
    state = session(%{@small => 5, @medium => 7}, %{{:hp_regen_bonus, 5_000} => 3})

    assert {:noreply, state} = EquipRegenHandler.handle_tick(state, 4_000)
    assert state.game_state.stats.current_state.hp == 113
    assert {:noreply, state} = EquipRegenHandler.handle_tick(state, 1_000)
    assert state.game_state.stats.current_state.hp == 125
    assert {:noreply, state} = EquipRegenHandler.handle_tick(state, 40_000)
    assert state.game_state.stats.current_state.hp == 199
  end

  test "death discards healing without pausing the percentage interval" do
    state = session(%{@small => 5}, %{})
    stats = state.game_state.stats

    game_state = %{
      state.game_state
      | action_state: :dead,
        stats: %{stats | current_state: %{stats.current_state | hp: 0}}
    }

    state = %{state | game_state: game_state}

    assert {:noreply, state} = EquipRegenHandler.handle_tick(state, 6_000)
    assert state.game_state.stats.current_state.hp == 0
    assert state.game_state.equip_regen_accumulators[@small] == 1_000
  end

  test "full stat recalculation restarts a potion's interval instead of carrying old progress" do
    state = session(%{@small => 5}, %{})
    assert {:noreply, state} = EquipRegenHandler.handle_tick(state, 4_500)
    stats = %{state.game_state.stats | generation: 1}
    state = %{state | game_state: %{state.game_state | stats: stats}}

    assert {:noreply, state} = EquipRegenHandler.handle_tick(state, 500)
    assert state.game_state.stats.current_state.hp == 100
    assert state.game_state.equip_regen_accumulators[@small] == 500
  end

  test "negative HP recovery alone is ignored, but positive SP recovery permits passive HP damage" do
    state = session(%{@small => -5}, %{})
    assert {:noreply, unchanged} = EquipRegenHandler.handle_tick(state, 5_000)
    assert unchanged.game_state.stats.current_state.hp == 100

    state = session(%{@small => -5}, %{{:sp_regen_bonus, 5_000} => 3})
    assert {:noreply, damaged} = EquipRegenHandler.handle_tick(state, 5_000)
    assert damaged.game_state.stats.current_state.hp == 91
    assert damaged.game_state.stats.current_state.sp == 103
  end

  defp session(status_modifiers, equipment) do
    game_state =
      PlayerStateFixture.build(%{
        character_id: 88_102,
        stats: %{
          current_state: %{hp: 100, sp: 100},
          derived_stats: %{max_hp: 199, max_sp: 200},
          modifiers: %{equipment: equipment, status_effects: status_modifiers},
          generation: 0
        }
      })

    %SessionState{game_state: game_state, connection_pid: self(), equip_regen_generation: 0}
  end
end
