defmodule Aesir.ZoneServer.Integration.DispelIntegrationTest do
  @moduledoc """
  End-to-end coverage that dispelling a real, live `PlayerSession` strips its
  statuses without disturbing a cast in progress.

  rAthena's Dispell (`src/map/skills/mage/dispell.cpp:36-72`) touches statuses
  and nothing else - it never interrupts the target's cast. The cast descriptor
  moved into its own `casting` field during this epic, so this drives the real
  session: a real skill cast is started through the real packet path, the
  target is dispelled mid-cast, and the cast is then required to still be
  pending and to still complete.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.SkillCast
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage

  # AL_INCAGI (id 29): a real self-castable ally buff with an 800ms cast time -
  # long enough to dispel the caster while the cast is still pending.
  @al_incagi 29

  setup :set_mimic_private
  setup :verify_on_exit!

  test "dispelling a mid-cast player strips statuses without interrupting the cast" do
    player =
      start_player_session(
        id: 9_701,
        name: "Casting",
        base_level: 50,
        max_sp: 200,
        sp: 200,
        learned_skills: %{@al_incagi => 1}
      )

    char_id = player.character.id

    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, char_id) end)

    :ok =
      StatusInterpreter.apply_status(:player, char_id, :sc_blessing,
        val1: 10,
        duration: 1_800_000
      )

    :ok = StatusInterpreter.apply_status(:player, char_id, :sc_hiding, duration: 1_800_000)

    flush_packets()

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: @al_incagi,
      level: 1,
      target_id: char_id
    })

    casting = get_player_state(player.pid).casting
    assert casting != nil, "the test needs the session to actually be mid-cast"

    Dispel.dispel({:player, char_id})

    assert get_player_state(player.pid).casting == casting,
           "Dispell must not disturb a cast in progress (dispell.cpp touches statuses only)"

    refute StatusStorage.has_status?(:player, char_id, :sc_blessing)
    assert StatusStorage.has_status?(:player, char_id, :sc_hiding)

    # The cast still resolves: AL_INCAGI lands its own buff on completion.
    assert eventually(fn -> StatusStorage.has_status?(:player, char_id, :sc_increaseagi) end),
           "the dispelled cast must still complete"
  end
end
