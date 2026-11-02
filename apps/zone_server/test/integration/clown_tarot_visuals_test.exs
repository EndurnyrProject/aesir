defmodule Aesir.ZoneServer.Integration.ClownTarotVisualsTest do
  @moduledoc "Authoritative Tarot card visuals through player and mob casting in both modes."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SpecialEffect
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skills.Clown.TarotDeck
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TestSupport.ClownSessions

  @map "prontera"

  setup do
    ClownSessions.blank_map(@map)
    :ok
  end

  test "a player broadcasts the selected card on its target after applying damage" do
    clown = start_clown()
    mob = start_mob({155, 150})
    mob_id = mob.unit_id
    pin_card(clown, :tower)

    ClownSessions.cast(clown, 489, 5, mob_id)

    assert_receive {:packet_sent, %SkillDamage{skill_id: 489, target_id: ^mob_id, damage: 4444},
                    _channel},
                   3_000

    assert_receive {:packet_sent, %SpecialEffect{source_id: ^mob_id, effect_id: 534}, _channel},
                   1_000

    assert eventually(fn -> get_mob_state(mob.pid).hp == 100_000 - 4444 end)
    refute_card_visual()
  end

  test "Lovers displays on the caster rather than the teleported target" do
    clown = start_clown()
    caster_id = clown.character.id
    mob = start_mob({155, 150})
    pin_card(clown, :lovers)

    ClownSessions.cast(clown, 489, 5, mob.unit_id)

    assert_receive {:packet_sent, %SpecialEffect{source_id: ^caster_id, effect_id: 528},
                    _channel},
                   3_000

    refute_card_visual()
  end

  test "Wheel applies both extra draws but displays only its own card" do
    clown = start_clown()
    mob = start_mob({155, 150})
    mob_id = mob.unit_id
    stub(TarotDeck, :roll, fn 100 -> 1 end)
    expect(TarotDeck, :draw, fn -> :wheel_of_fortune end)
    expect(TarotDeck, :draw, fn -> :magician end)
    expect(TarotDeck, :draw, fn -> :strength end)
    Mimic.allow(TarotDeck, self(), clown.pid)

    ClownSessions.cast(clown, 489, 5, mob_id)

    assert_receive {:packet_sent, %SpecialEffect{source_id: ^mob_id, effect_id: 529}, _channel},
                   3_000

    assert %{val1: -50} = StatusStorage.get_status(:mob, mob_id, :sc_incmatkrate)
    assert %{val1: -50} = StatusStorage.get_status(:mob, mob_id, :sc_incatkrate)
    refute_card_visual()
  end

  test "a failed cast sends no selected-card visual" do
    clown = start_clown()
    mob = start_mob({155, 150})
    test_pid = self()

    stub(TarotDeck, :roll, fn 100 ->
      send(test_pid, :rolled)
      100
    end)

    reject(&TarotDeck.draw/0)
    Mimic.allow(TarotDeck, self(), clown.pid)

    ClownSessions.cast(clown, 489, 5, mob.unit_id)

    assert_receive :rolled, 3_000
    get_player_state(clown.pid)
    refute_card_visual()
  end

  test "a mob cast broadcasts its actual card on the player target" do
    player =
      :novice
      |> ClownSessions.character(@map, {155, 150}, %{}, %{class: 7})
      |> ClownSessions.start_session()

    mob = start_mob({150, 150})
    player_id = player.character.id
    stub(TarotDeck, :roll, fn 100 -> 1 end)
    stub(TarotDeck, :draw, fn -> :tower end)
    MobSession.set_target(mob.pid, {:player, player_id})

    assert eventually(fn ->
             get_mob_state(mob.pid).target_ref == {:player, player_id}
           end)

    row = %{skill: "CG_TAROTCARD", skill_id: 489, level: 5, target: :target}
    assert :ok = Executor.execute(get_mob_state(mob.pid), row)

    assert_receive {:packet_sent, %SpecialEffect{source_id: ^player_id, effect_id: 534},
                    _channel},
                   1_000

    refute_card_visual()
  end

  defp pin_card(session, card) do
    stub(TarotDeck, :roll, fn 100 -> 1 end)
    stub(TarotDeck, :draw, fn -> card end)
    Mimic.allow(TarotDeck, self(), session.pid)
  end

  defp refute_card_visual do
    refute_receive(
      {:packet_sent, %SpecialEffect{effect_id: id}, _channel} when id >= 523 and id <= 536,
      100,
      "Unexpected Tarot card visual"
    )
  end

  defp start_clown do
    :clown
    |> ClownSessions.character(@map, {150, 150}, %{489 => 5})
    |> ClownSessions.start_session()
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
end
