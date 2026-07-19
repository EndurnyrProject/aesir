defmodule Aesir.ZoneServer.Integration.ExperienceIntegrationTest do
  @moduledoc """
  Integration test for the kill -> experience loop.

  Drives the real path: a mob dies crediting a player, broadcasts the kill on
  the player's event topic, and the player's session awards experience. This
  locks the PubSub topic contract between `MobSession` and `PlayerSession`.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.ParamChange
  alias Aesir.ZoneServer.Unit.Mob.MobSession

  describe "killing a mob" do
    test "awards the mob's experience to the killer" do
      player =
        start_player_session(
          id: 7001,
          name: "Slayer",
          base_level: 1,
          job_level: 1,
          map_name: "prontera",
          position: {150, 150}
        )

      # Default test mob grants 10 base / 5 job experience.
      mob = start_mob_session(unit_id: 7002, map_name: "prontera", position: {151, 150})

      Process.sleep(50)
      flush_packets()

      # Lethal blow credited to the player drives the full death -> broadcast
      # -> player-session experience path.
      MobSession.apply_damage(mob.pid, 9_999, player.character.id)

      base_exp_id = StatusParams.base_exp()
      assert_receive {:packet_sent, %ParamChange{var_id: ^base_exp_id, value: 10}, _}, 1_000

      progression = get_player_state(player.pid).stats.progression
      assert progression.base_exp == 10
      assert progression.job_exp == 5
      # 10 base exp is far below the level-2 threshold, so no level is gained.
      assert progression.base_level == 1
    end

    test "the killer's bExpAddRace equipment boosts the reward for a matching race" do
      player = start_killer(7011)
      wear(player, %{{:exp_add_race, :formless} => 50})

      kill(start_mob_session(unit_id: 7012, race: :formless, position: {151, 150}), player)

      progression = get_player_state(player.pid).stats.progression
      assert progression.base_exp == 15
      assert progression.job_exp == 7
    end

    test "a bExpAddRace bonus for another race leaves the reward alone" do
      player = start_killer(7021)
      wear(player, %{{:exp_add_race, :brute} => 100})

      kill(start_mob_session(unit_id: 7022, race: :formless, position: {151, 150}), player)

      progression = get_player_state(player.pid).stats.progression
      assert progression.base_exp == 10
      assert progression.job_exp == 5
    end
  end

  defp start_killer(id) do
    start_player_session(
      id: id,
      name: "Slayer#{id}",
      base_level: 1,
      job_level: 1,
      map_name: "prontera",
      position: {150, 150}
    )
  end

  # The equipment bonus map is normally rebuilt from worn items on every stat
  # recompute; this writes it straight into the session's own state, the single
  # place the EXP handler reads it from.
  defp wear(player, equipment) do
    :sys.replace_state(player.pid, fn %{game_state: game_state} = state ->
      modifiers = %{game_state.stats.modifiers | equipment: equipment}
      stats = %{game_state.stats | modifiers: modifiers}

      %{state | game_state: %{game_state | stats: stats}}
    end)
  end

  defp kill(mob, player) do
    Process.sleep(50)
    flush_packets()

    MobSession.apply_damage(mob.pid, 9_999, player.character.id)

    base_exp_id = StatusParams.base_exp()
    assert_receive {:packet_sent, %ParamChange{var_id: ^base_exp_id, value: _}, _}, 1_000
  end
end
