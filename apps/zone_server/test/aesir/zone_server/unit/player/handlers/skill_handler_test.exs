defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  defp state(sp) do
    %{
      connection_pid: self(),
      game_state: %{
        character_id: 1000,
        map_name: "prontera",
        x: 150,
        y: 150,
        stats: %{
          current_state: %{sp: sp, hp: 100},
          derived_stats: %{max_sp: 200, max_hp: 100},
          progression: %{learned_skills: %{29 => 1}}
        }
      }
    }
  end

  test "self-cast applies the effect, recalculates stats, persists, syncs and broadcasts" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
    stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
    expect(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
    expect(CharacterPersistence, :update_character, fn 1000, %{sp: 12}, _opts -> {:ok, %{}} end)

    assert {:noreply, new_state} = SkillHandler.handle_use_skill(state(30), 29, 1, 1000)
    assert new_state.game_state.stats.current_state.sp == 12
  end

  test "failed cast leaves state unchanged and does not persist" do
    reject(&CharacterPersistence.update_character/3)
    reject(&StatusInterpreter.apply_status/4)

    s = state(1)
    assert {:noreply, ^s} = SkillHandler.handle_use_skill(s, 29, 1, 1000)
  end
end
