defmodule Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler do
  @moduledoc """
  Handles player HP changes from combat: damage application, death, and respawn.

  When a player takes damage their own HP bar is updated via `ZC_PAR_CHANGE`
  (SP_HP), matching rAthena's `clif_updatestatus(sd, SP_HP)`. `ZC_HP_INFO` is
  reserved for monster HP bars and is not used here.

  On death the player is marked `:dead`, vanishes for nearby players
  (`ZC_NOTIFY_VANISH` with the died type) and is pulled out of the spatial index
  so mobs drop aggro. Respawn revives the player in place and stands the sprite
  back up via `ZC_RESURRECTION`.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Packets.ZcNotifyVanish
  alias Aesir.ZoneServer.Packets.ZcResurrection
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @doc """
  Computes the HP after taking `damage`, clamped at 0.
  """
  @spec damaged_hp(non_neg_integer(), integer()) :: non_neg_integer()
  def damaged_hp(current_hp, damage), do: max(0, current_hp - damage)

  @doc """
  Applies combat damage to the player session state.

  Updates current HP, pushes an SP_HP update to the client, persists the new
  HP and triggers death handling when HP reaches 0. Damage on an already-dead
  player (or non-positive damage) is ignored.
  """
  @spec apply_damage(integer(), integer() | nil, map()) :: {:noreply, map()}
  def apply_damage(_damage, _attacker_id, %{game_state: %{action_state: :dead}} = state) do
    {:noreply, state}
  end

  def apply_damage(damage, attacker_id, state) when is_integer(damage) and damage > 0 do
    stats = state.game_state.stats
    new_hp = damaged_hp(stats.current_state.hp, damage)

    updated_stats = %{stats | current_state: %{stats.current_state | hp: new_hp}}
    game_state = %{state.game_state | stats: updated_stats}
    state = StatsManager.update_game_state(state, game_state)

    StatusSync.send_param(state.connection_pid, StatusParams.hp(), new_hp)
    CharacterPersistence.update_stats(state.game_state.character_id, %{hp: new_hp}, async: true)

    if new_hp == 0 do
      handle_death(attacker_id, state)
    else
      {:noreply, state}
    end
  end

  def apply_damage(_damage, _attacker_id, state), do: {:noreply, state}

  @doc """
  Handles a CZ_RESTART request.

  Type 0 respawns a dead player; type 1 (return to character select) disconnects
  the session.
  """
  @spec handle_restart(non_neg_integer(), map()) :: {:noreply, map()} | {:stop, :normal, map()}
  def handle_restart(0, %{game_state: %{action_state: :dead}} = state), do: respawn(state)
  def handle_restart(0, state), do: {:noreply, state}

  # char-select returns to the char server; we have no such flow yet,
  # so just drop the session. Add the char-server handoff when it exists.
  def handle_restart(1, state), do: {:stop, :normal, state}
  def handle_restart(_type, state), do: {:noreply, state}

  defp handle_death(attacker_id, %{game_state: game_state} = state) do
    Logger.info("Player #{game_state.character_id} died (killed by #{inspect(attacker_id)})")

    {:ok, dead_state} = PlayerState.transition_to(game_state, :dead)
    state = StatsManager.update_game_state(state, dead_state)

    vanish = %ZcNotifyVanish{gid: game_state.account_id, type: ZcNotifyVanish.died()}
    Broadcast.to_visible_players(dead_state, vanish)

    SpatialIndex.remove_player(game_state.character_id)
    SpatialIndex.clear_visibility(game_state.character_id)

    {:noreply, state}
  end

  defp respawn(%{game_state: game_state} = state) do
    stats = game_state.stats
    max_hp = stats.derived_stats.max_hp
    max_sp = stats.derived_stats.max_sp

    revived_stats = %{stats | current_state: %{stats.current_state | hp: max_hp, sp: max_sp}}

    # respawn in place. rAthena warps to the save point, but there is
    # no cross-map player warp yet; clif_resurrection is rAthena's own fallback
    # when that warp fails. Wire save-point warping once it exists.
    {:ok, idle_state} = PlayerState.transition_to(game_state, :idle)
    idle_state = %{idle_state | stats: revived_stats}
    state = StatsManager.update_game_state(state, idle_state)

    SpatialIndex.add_player(
      idle_state.character_id,
      idle_state.x,
      idle_state.y,
      idle_state.map_name
    )

    visible_state = MovementHandler.handle_visibility_update(idle_state)
    state = StatsManager.update_game_state(state, visible_state)

    StatusSync.send_params(state.connection_pid, [
      {StatusParams.max_hp(), max_hp},
      {StatusParams.hp(), max_hp},
      {StatusParams.max_sp(), max_sp},
      {StatusParams.sp(), max_sp}
    ])

    resurrection = %ZcResurrection{gid: game_state.account_id, type: 0}
    send_self(state, resurrection)
    Broadcast.to_visible_players(visible_state, resurrection)

    CharacterPersistence.update_stats(game_state.character_id, %{hp: max_hp, sp: max_sp},
      async: true
    )

    {:noreply, state}
  end

  defp send_self(%{connection_pid: connection_pid}, packet) do
    send(connection_pid, {:send_packet, packet})
  end
end
