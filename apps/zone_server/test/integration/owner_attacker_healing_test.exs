defmodule Aesir.ZoneServer.Integration.OwnerAttackerHealingTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaotic
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  test "Benediction heals a selected player attacker through that player's session" do
    owner = start_player_session(position: {20, 20})
    attacker = start_player_session(position: {21, 20})

    on_exit(fn ->
      end_player_session(attacker)
      end_player_session(owner)
    end)

    :sys.replace_state(attacker.pid, fn session ->
      game_state = session.game_state
      stats = game_state.stats
      stats = put_in(stats.current_state.hp, 1)
      stats = put_in(stats.derived_stats.max_hp, 5_000)
      casting = %{target: {:unit, owner.character.id}}
      StateCommit.commit(session, %{game_state | stats: stats, casting: casting})
    end)

    :sys.replace_state(owner.pid, fn session ->
      homunculus = %HomunculusState{
        id: 1,
        owner_character_id: owner.character.id,
        class_id: 6_004,
        name: "Vanilmirth",
        world_gid: 1_500_001,
        map_name: owner.map_name,
        x: 20,
        y: 20,
        level: 50,
        int: 50
      }

      seed =
        Enum.find(1..100, fn n ->
          :rand.seed(:exsss, {n, n + 1, n + 2})
          :rand.uniform(100) > 50
        end)

      :rand.seed(:exsss, {seed, seed + 1, seed + 2})

      {:local_effects, _, [effect]} =
        HvanChaotic.cast(homunculus, :self, 1, HvanChaotic.definition())

      {:noreply, updated} = CommandHandler.local_effect(effect, session)
      updated
    end)

    # Level 50, INT 50 and zero MATK heal 60 in renewal, 144 in classic.
    expected_hp = if GameMode.mode() == :renewal, do: 61, else: 145

    assert_eventually(fn ->
      PlayerSession.get_state(attacker.pid).game_state.stats.current_state.hp == expected_hp
    end)
  end
end
