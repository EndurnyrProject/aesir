defmodule Aesir.ZoneServer.Integration.ExperienceIntegrationTest do
  @moduledoc """
  Integration test for the kill -> experience loop.

  Drives the real path: a mob dies crediting a player, broadcasts the kill on
  the player's event topic, and the player's session awards experience. This
  locks the PubSub topic contract between `MobSession` and `PlayerSession`.
  """

  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.Packets.ZcLongparChange
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
      assert_receive {:packet_sent, %ZcLongparChange{var_id: ^base_exp_id, value: 10}, _}, 1_000

      progression = get_player_state(player.pid).stats.progression
      assert progression.base_exp == 10
      assert progression.job_exp == 5
      # 10 base exp is far below the level-2 threshold, so no level is gained.
      assert progression.base_level == 1
    end
  end
end
