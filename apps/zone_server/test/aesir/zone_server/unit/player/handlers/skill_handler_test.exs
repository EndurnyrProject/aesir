defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Packets.ZcSkillPostdelay
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
        skill_cooldowns: %{},
        stats: %{
          base_stats: %{dex: 1, int: 1},
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

  test "sends ZC_SKILL_POSTDELAY to the caster when the skill has a cooldown" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
    stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
    stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
    stub(Catalog, :by_id, fn 29 -> {:ok, definition(cooldown: [5_000])} end)

    assert {:noreply, _} = SkillHandler.handle_use_skill(state(30), 29, 1, 1000)
    assert_received {:send_packet, %ZcSkillPostdelay{skill_id: 29, tick: 5_000}}
  end

  test "sends no ZC_SKILL_POSTDELAY when the skill has no cooldown" do
    stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, _ -> :ok end)
    stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(Broadcast, :to_in_range, fn "prontera", 150, 150, _range, _packet -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
    stub(CharacterPersistence, :update_character, fn 1000, _attrs, _opts -> {:ok, %{}} end)
    stub(Catalog, :by_id, fn 29 -> {:ok, definition(cooldown: [])} end)

    assert {:noreply, _} = SkillHandler.handle_use_skill(state(30), 29, 1, 1000)
    refute_received {:send_packet, %ZcSkillPostdelay{}}
  end

  test "ground cast recalculates stats, persists, syncs and broadcasts no ZcUseSkill" do
    expect(Interpreter, :cast, fn gs, 89, 1, {:ground, 12, 12} ->
      {:ok, %{gs | stats: %{gs.stats | current_state: %{gs.stats.current_state | sp: 12}}}}
    end)

    stub(PlayerStats, :calculate_stats, fn stats, 1000 -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(Catalog, :by_id, fn 89 -> {:ok, definition(id: 89, cooldown: [])} end)
    reject(&Broadcast.to_in_range/5)
    expect(StatusSync, :send_stat_updates, fn _conn, _stats -> :ok end)
    expect(CharacterPersistence, :update_character, fn 1000, %{sp: 12}, _opts -> {:ok, %{}} end)

    assert {:noreply, new_state} = SkillHandler.handle_use_skill_ground(state(30), 89, 1, 12, 12)
    assert new_state.game_state.stats.current_state.sp == 12
  end

  test "failed ground cast leaves state unchanged and does not persist" do
    stub(Interpreter, :cast, fn _gs, _id, _lvl, _target -> {:error, :out_of_range} end)
    reject(&CharacterPersistence.update_character/3)

    s = state(30)
    assert {:noreply, ^s} = SkillHandler.handle_use_skill_ground(s, 89, 1, 12, 12)
  end

  defp definition(fields) do
    struct!(
      %Definition{
        id: 29,
        name: :al_incagi,
        display_name: "Increase AGI",
        max_level: 10,
        sp_cost: [18]
      },
      fields
    )
  end
end
