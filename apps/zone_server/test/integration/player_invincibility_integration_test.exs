defmodule Aesir.ZoneServer.Integration.PlayerInvincibilityIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveRequest
  alias Aesir.ZoneServer.Unit.Player.Invincibility

  setup {Aesir.MimicMode, :global}

  # Long enough that only the walk or a deliberate deadline can end it.
  setup do
    stub(Invincibility, :default_time, fn -> 60_000 end)
    :ok
  end

  test "a map load hides the player from an aggressive mob until a walk request ends it" do
    player = start_player_session(id: 8_653, position: {150, 150}, map_name: "prontera")
    player_ref = {:player, player.character.id}

    simulate_incoming_message(player.pid, %MapLoaded{})
    assert_eventually(fn -> Invincibility.active?(player_ref) end)

    mob =
      start_mob_session(
        map_name: "prontera",
        position: {152, 150},
        modes: [:aggressive],
        awake: true
      )

    on_exit(fn -> end_mob_session(mob) end)

    assert ai_tick(mob).target_ref == nil

    simulate_incoming_message(player.pid, %MoveRequest{dest_x: 151, dest_y: 150})
    assert_eventually(fn -> not Invincibility.active?(player_ref) end)

    assert_eventually(fn -> ai_tick(mob).target_ref == player_ref end)
  end

  test "the deadline ends it and the mob then acquires the player" do
    player = start_player_session(id: 8_654, position: {150, 150}, map_name: "prontera")
    player_ref = {:player, player.character.id}

    simulate_incoming_message(player.pid, %MapLoaded{})
    assert_eventually(fn -> Invincibility.active?(player_ref) end)

    mob =
      start_mob_session(
        map_name: "prontera",
        position: {152, 150},
        modes: [:aggressive],
        awake: true
      )

    on_exit(fn -> end_mob_session(mob) end)
    assert ai_tick(mob).target_ref == nil

    generation = get_player_state(player.pid).invincible_generation
    send(player.pid, {:invincibility, {:expire, generation}})

    assert_eventually(fn -> ai_tick(mob).target_ref == player_ref end)
  end

  defp ai_tick(mob) do
    send(mob.pid, {:ai, :tick})
    get_mob_state(mob.pid)
  end
end
