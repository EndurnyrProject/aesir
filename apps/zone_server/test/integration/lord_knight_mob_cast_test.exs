defmodule Aesir.ZoneServer.Integration.LordKnightMobCastTest do
  @moduledoc """
  Exercises the mob skill executor's real Spiral Pierce path against a live
  player. Mob casts bypass player-only weapon requirements in both game modes.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @map "prontera"

  test "a mob's Spiral Pierce damages and roots its player target" do
    Mimic.copy(HitCalculations)
    Mimic.stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    target =
      start_player_session(character: target_character(), position: {151, 150})

    on_exit(fn -> if Process.alive?(target.pid), do: end_player_session(target) end)

    mob = start_mob_session(map_name: @map, position: {150, 150})
    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)

    initial_hp = get_player_state(target.pid).stats.current_state.hp
    caster = %{get_mob_state(mob.pid) | target_ref: {:player, target.character.id}}
    row = %{skill: "LK_SPIRALPIERCE", skill_id: 397, target: :target, level: 5}

    assert :ok = Executor.execute(caster, row)
    assert eventually(fn -> get_player_state(target.pid).stats.current_state.hp < initial_hp end)

    assert %{expires_at: expiry, started_at: started} =
             StatusStorage.get_status(:player, target.character.id, :sc_stop)

    assert expiry - started == 1_000
  end

  defp target_character do
    id = System.unique_integer([:positive])

    %Character{
      id: id,
      account_id: id,
      name: "SpiralTarget#{id}",
      char_num: 0,
      class: 0,
      base_level: 40,
      job_level: 1,
      str: 20,
      agi: 20,
      vit: 20,
      int: 10,
      dex: 20,
      luk: 10,
      hp: 5_000,
      max_hp: 5_000,
      sp: 50,
      max_sp: 50,
      last_map: @map,
      last_x: 151,
      last_y: 150,
      save_map: @map,
      save_x: 150,
      save_y: 150,
      hair: 1,
      hair_color: 1,
      clothes_color: 0,
      online: true
    }
  end
end
