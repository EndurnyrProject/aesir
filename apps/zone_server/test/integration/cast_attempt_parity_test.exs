defmodule Aesir.ZoneServer.Integration.CastAttemptParityTest do
  @moduledoc "Real player-session cast attempts and their timing status reactions."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.GameMode
  alias Aesir.Net.ItemSkillReady
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  @memorize :sc_memorize
  @suffragium :sc_suffragium

  test "a preflight is inert, a failed attempt respects mode stage, and instant/timed attempts consume once" do
    player =
      start_player_session(
        name: "CastParity",
        sp: 100,
        max_sp: 100,
        learned_skills: %{"14" => 1, "28" => 1, "29" => 1}
      )

    char_id = player.character.id
    :ok = StatusInterpreter.apply_status(:player, char_id, @memorize, caster_id: char_id)

    :ok =
      StatusInterpreter.apply_status(:player, char_id, @suffragium,
        caster_id: char_id,
        val1: 3,
        duration: 10_000
      )

    {:error, _reason} =
      SkillInterpreter.preflight_cast(get_player_state(player.pid), 14, 1, {:unit, 99_999})

    assert charges(char_id) == 5
    simulate_incoming_message(player.pid, %SkillCast{skill_id: 14, level: 1, target_id: 99_999})

    expected = if GameMode.mode() == :pre_renewal, do: 4, else: 5
    assert eventually(fn -> charges(char_id) == expected end)
    assert StatusStorage.has_status?(:player, char_id, @suffragium)

    simulate_incoming_message(player.pid, %SkillCast{skill_id: 28, level: 1, target_id: char_id})
    assert eventually(fn -> charges(char_id) == expected - 1 end)

    if GameMode.mode() == :pre_renewal do
      refute StatusStorage.has_status?(:player, char_id, @suffragium)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, @suffragium,
          caster_id: char_id,
          val1: 3,
          duration: 10_000
        )
    else
      assert StatusStorage.has_status?(:player, char_id, @suffragium)
    end

    assert eventually(fn ->
             get_player_state(player.pid).act_delay_until <= System.monotonic_time(:millisecond)
           end)

    simulate_incoming_message(player.pid, %SkillCast{skill_id: 29, level: 1, target_id: char_id})
    assert %SkillCasting{skill_id: 29} = assert_packet_sent(SkillCasting)
    assert eventually(fn -> charges(char_id) == expected - 2 end)
    assert eventually(fn -> get_player_state(player.pid).casting == nil end)
    assert charges(char_id) == expected - 2

    assert StatusStorage.has_status?(:player, char_id, @suffragium) ==
             (GameMode.mode() == :renewal)
  end

  test "an item stages one client-selected cast without learned or SP requirements" do
    player = start_player_session(name: "ItemCast", sp: 100, max_sp: 100)
    mob = start_mob_session(position: {151, 150}, awake: false)

    assert {:ok, _state} = PlayerSession.script_apply(player.pid, {:stage_item_skill, 19, 1})

    assert %ItemSkillReady{skill_id: 19, level: 1, target_kind: :UNIT} =
             assert_packet_sent(ItemSkillReady)

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: 19,
      level: 1,
      target_id: mob.unit_id
    })

    assert %SkillCasting{skill_id: 19} = assert_packet_sent(SkillCasting)
    assert eventually(fn -> get_mob_state(mob.pid).hp < 100 end)
    assert get_player_state(player.pid).stats.current_state.sp == 100
  end

  defp charges(char_id) do
    case StatusStorage.get_status(:player, char_id, @memorize) do
      %{state: %{charges: n}} -> n
      _ -> 0
    end
  end
end
