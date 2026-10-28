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

  defp session(char_id, equipment, opts \\ []) do
    game_state =
      PlayerStateFixture.build(%{
        character_id: char_id,
        action_state: Keyword.get(opts, :action, :idle),
        equip_regen_accumulators: Keyword.get(opts, :accumulators, %{}),
        stats: %{
          current_state: %{hp: Keyword.get(opts, :hp, 100), sp: 100},
          derived_stats: %{max_hp: 200, max_sp: 200},
          modifiers: %{equipment: equipment},
          generation: Keyword.get(opts, :generation, 0)
        }
      })

    %SessionState{
      game_state: game_state,
      connection_pid: self(),
      equip_regen_generation: Keyword.get(opts, :seen_generation, 0)
    }
  end

  test "No-Recover does not stop equipment regen or loss" do
    char_id = 88_003

    equipment = %{
      {:hp_regen_bonus, 500} => 10,
      {:hp_loss_bonus, 500} => 5,
      {:sp_regen_bonus, 500} => 10,
      {:sp_loss_bonus, 500} => 4
    }

    :ok = StatusStorage.apply_status(:player, char_id, :sc_norecover_state)
    on_exit(fn -> StatusStorage.remove_status(:player, char_id, :sc_norecover_state) end)

    assert {:noreply, updated} = EquipRegenHandler.handle_tick(session(char_id, equipment), 500)
    assert updated.game_state.stats.current_state.hp == 105
    assert updated.game_state.stats.current_state.sp == 106
  end

  test "Berserk zeroes the HP gain but not the SP gain, and HP loss still applies" do
    char_id = 88_004

    equipment = %{
      {:hp_regen_bonus, 500} => 10,
      {:hp_loss_bonus, 500} => 5,
      {:sp_regen_bonus, 500} => 10
    }

    :ok = StatusStorage.apply_status(:player, char_id, :sc_berserk)
    on_exit(fn -> StatusStorage.remove_status(:player, char_id, :sc_berserk) end)

    assert {:noreply, updated} = EquipRegenHandler.handle_tick(session(char_id, equipment), 500)
    assert updated.game_state.stats.current_state.hp == 95
    assert updated.game_state.stats.current_state.sp == 110
  end

  describe "stat recalculation" do
    @equipment %{{:hp_regen_bonus, 10_000} => 10}
    @progress %{{:hp_regen_bonus, 10_000} => 9_500}

    test "keeps the interval progress under the same generation" do
      state =
        session(88_005, @equipment, accumulators: @progress, generation: 1, seen_generation: 1)

      assert {:noreply, updated} = EquipRegenHandler.handle_tick(state, 500)
      assert updated.game_state.stats.current_state.hp == 110
    end

    test "a new generation restarts the intervals" do
      state =
        session(88_005, @equipment, accumulators: @progress, generation: 2, seen_generation: 1)

      assert {:noreply, updated} = EquipRegenHandler.handle_tick(state, 500)
      assert updated.game_state.stats.current_state.hp == 100
      assert updated.game_state.equip_regen_accumulators == %{{:hp_regen_bonus, 10_000} => 500}
      assert updated.equip_regen_generation == 2
    end

    test "a generation change with no periodic gear records the generation without committing" do
      reject(UnitRegistry, :update_unit_state, 3)
      state = session(88_006, %{}, generation: 3, seen_generation: 2)

      assert {:noreply, updated} = EquipRegenHandler.handle_tick(state, 500)
      assert updated.game_state === state.game_state
      assert updated.equip_regen_generation == 3
    end
  end

  test "while dead the regen intervals run with no heal and the loss intervals hold" do
    reject(CharacterPersistence, :update_stats, 3)
    equipment = %{{:hp_regen_bonus, 10_000} => 10, {:hp_loss_bonus, 10_000} => 5}
    progress = %{{:hp_regen_bonus, 10_000} => 9_500, {:hp_loss_bonus, 10_000} => 9_500}
    state = session(88_007, equipment, action: :dead, hp: 0, accumulators: progress)

    assert {:noreply, updated} = EquipRegenHandler.handle_tick(state, 500)
    assert updated.game_state.stats.current_state.hp == 0

    assert updated.game_state.equip_regen_accumulators == %{
             {:hp_regen_bonus, 10_000} => 0,
             {:hp_loss_bonus, 10_000} => 9_500
           }

    refute_received {:send, _channel, _payload}
  end

  test "a dead wearer of loss gear alone commits nothing" do
    reject(UnitRegistry, :update_unit_state, 3)
    progress = %{{:hp_loss_bonus, 10_000} => 9_500}

    state =
      session(88_008, %{{:hp_loss_bonus, 10_000} => 5},
        action: :dead,
        hp: 0,
        accumulators: progress
      )

    assert {:noreply, updated} = EquipRegenHandler.handle_tick(state, 500)
    assert updated.game_state === state.game_state
  end
end
