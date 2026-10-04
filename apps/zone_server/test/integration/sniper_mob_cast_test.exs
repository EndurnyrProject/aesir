defmodule Aesir.ZoneServer.Integration.SniperMobCastTest do
  @moduledoc "Real mob Focused Arrow Strike dispatch in renewal and pre-renewal."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor

  test "a mob Sharpshooting row damages its player target through the real skill catalog" do
    stub(CriticalHits, :is_critical_hit?, fn _rate -> true end)

    player =
      start_player_session(
        id: 99_001,
        class: 4012,
        base_level: 99,
        hp: 10_000,
        max_hp: 10_000,
        vit: 0,
        luk: 0,
        position: {158, 150}
      )

    mob = start_mob_session(unit_id: 99_101, map_name: "prontera", position: {150, 150})

    on_exit(fn ->
      if Process.alive?(player.pid), do: end_player_session(player)
      if Process.alive?(mob.pid), do: end_mob_session(mob)
    end)

    MobSession.set_target(mob.pid, {:player, player.character.id})
    before_hp = get_player_state(player.pid).stats.current_state.hp
    row = %{skill: "SN_SHARPSHOOTING", skill_id: 382, level: 3, target: :target}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert eventually(fn -> get_player_state(player.pid).stats.current_state.hp < before_hp end)

    assert_receive {:packet_sent,
                    %SkillDamage{
                      skill_id: 382,
                      src_id: 99_101,
                      target_id: 99_001,
                      damage: damage
                    }, _channel}

    assert damage > 0
  end
end
