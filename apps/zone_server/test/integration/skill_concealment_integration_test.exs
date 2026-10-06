defmodule Aesir.ZoneServer.Integration.SkillConcealmentIntegrationTest do
  @moduledoc """
  Real-PlayerSession coverage for skill concealment at cast begin: a target
  hidden from the caster rejects the cast silently and spends nothing.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @bash 5

  test "a Bash at a hidden mob fails silently, and lands once the mob is revealed" do
    caster =
      start_player_session(
        class: 1,
        position: {150, 150},
        sp: 50,
        max_sp: 50,
        learned_skills: %{Integer.to_string(@bash) => 1}
      )

    mob = start_mob_session(unit_id: 93_180, position: {151, 150}, hp: 1_000, max_hp: 1_000)
    :ok = StatusStorage.apply_status(:mob, mob.unit_id, :sc_hiding)
    flush_packets()

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: @bash,
      level: 1,
      target_id: mob.unit_id
    })

    assert eventually(fn -> get_player_state(caster.pid).action_state == :idle end)
    refute_receive {:packet_sent, %SkillCastFailed{}, _}, 200
    assert get_player_state(caster.pid).stats.current_state.sp == 50

    :ok = StatusStorage.remove_status(:mob, mob.unit_id, :sc_hiding)

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: @bash,
      level: 1,
      target_id: mob.unit_id
    })

    assert eventually(fn -> get_player_state(caster.pid).stats.current_state.sp == 42 end)
  end
end
