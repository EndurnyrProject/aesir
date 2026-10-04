defmodule Aesir.ZoneServer.Integration.ClownTarotTest do
  @moduledoc "Real-session Tarot Card of Fate and Clown mob rows in renewal and pre-renewal."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeck
  alias Aesir.ZoneServer.TestSupport.ClownSessions

  @map "prontera"

  setup do
    ClownSessions.blank_map(@map)
    :ok
  end

  test "a played Tower card deals 4444 and spends 40 SP" do
    clown = start_clown()
    mob = start_mob({155, 150})
    mob_id = mob.unit_id
    stub(TarotDeck, :roll, fn 100 -> 1 end)
    stub(TarotDeck, :draw, fn -> :tower end)
    Mimic.allow(TarotDeck, self(), clown.pid)
    sp = current_sp(clown)

    ClownSessions.cast(clown, 489, 5, mob_id)

    assert_receive {:packet_sent, %SkillDamage{skill_id: 489, target_id: ^mob_id, damage: 4444},
                    _channel},
                   3_000

    assert eventually(fn -> current_sp(clown) == sp - 40 end)
    assert eventually(fn -> get_mob_state(mob.pid).hp == 100_000 - 4444 end)
  end

  test "a failed roll spends no SP and draws no card" do
    clown = start_clown()
    mob = start_mob({155, 150})
    test_pid = self()

    stub(TarotDeck, :roll, fn 100 ->
      send(test_pid, :rolled)
      100
    end)

    reject(&TarotDeck.draw/0)
    Mimic.allow(TarotDeck, self(), clown.pid)
    sp = current_sp(clown)

    ClownSessions.cast(clown, 489, 5, mob.unit_id)

    assert_receive :rolled, 3_000
    assert current_sp(clown) == sp
    assert get_mob_state(mob.pid).hp == 100_000
  end

  test "a mob Arrow Vulcan row strikes its player target shown as nine hits" do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)
    {player, mob} = start_duel()
    player_id = player.character.id
    row = %{skill: "CG_ARROWVULCAN", skill_id: 394, level: 5, target: :target}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert_receive {:packet_sent,
                    %SkillDamage{skill_id: 394, target_id: ^player_id, damage: damage, div: 9},
                    _channel},
                   1_000

    assert damage > 0
  end

  test "a mob Tarot row plays its card on the player target" do
    {player, mob} = start_duel()
    player_id = player.character.id
    stub(TarotDeck, :roll, fn 100 -> 1 end)
    stub(TarotDeck, :draw, fn -> :tower end)
    row = %{skill: "CG_TAROTCARD", skill_id: 489, level: 5, target: :target}

    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert_receive {:packet_sent,
                    %SkillDamage{skill_id: 489, target_id: ^player_id, damage: 4444}, _channel},
                   1_000

    assert eventually(fn ->
             get_player_state(player.pid).stats.current_state.hp == 10_000 - 4444
           end)
  end

  defp start_clown do
    :clown
    |> ClownSessions.character(@map, {150, 150}, %{489 => 5})
    |> ClownSessions.start_session()
  end

  defp start_duel do
    player =
      :novice
      |> ClownSessions.character(@map, {155, 150}, %{})
      |> ClownSessions.start_session()

    mob = start_mob({150, 150})
    MobSession.set_target(mob.pid, {:player, player.character.id})

    assert eventually(fn ->
             get_mob_state(mob.pid).target_ref == {:player, player.character.id}
           end)

    {player, mob}
  end

  defp start_mob(position) do
    mob =
      start_mob_session(
        map_name: @map,
        position: position,
        hp: 100_000,
        max_hp: 100_000,
        vit: 0,
        luk: 0
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  defp current_sp(session), do: get_player_state(session.pid).stats.current_state.sp
end
