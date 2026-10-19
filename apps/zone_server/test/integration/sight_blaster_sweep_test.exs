defmodule Aesir.ZoneServer.Integration.SightBlasterSweepTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  test "one real tick strikes two monsters and pushes the caster's own trap" do
    player = start_player_session(position: {100, 100}, int: 30)
    caster = PlayerSession.get_state(player.pid).game_state
    assert {:ok, group} = Unit.place(caster, :ht_landmine, 1, {101, 100})
    [trap] = Storage.get_cells_by_group(group.group_id)
    first = start_mob_session(position: {100, 101}, max_hp: 5_000)
    second = start_mob_session(position: {99, 100}, max_hp: 5_000)

    on_exit(fn ->
      end_mob_session(first)
      end_mob_session(second)
      end_player_session(player)
    end)

    assert :ok =
             Interpreter.apply_status(:player, caster.character_id, :sc_sightblaster,
               caster_id: caster.character_id,
               val1: 1
             )

    assert_eventually(fn ->
      MobSession.get_state(first.pid).hp < 5_000 and
        MobSession.get_state(second.pid).hp < 5_000 and
        not StatusStorage.has_status?(:player, caster.character_id, :sc_sightblaster)
    end)

    assert_eventually(fn ->
      match?(%{x: 104, y: 100}, Storage.get_cell(trap.cell_id))
    end)
  end
end
