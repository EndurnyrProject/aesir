defmodule Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler do
  @moduledoc """
  Handles player HP changes from combat: damage application, death, and respawn.

  When a player takes damage their own HP bar is updated via a `ParamChange`
  (SP_HP), matching rAthena's `clif_updatestatus(sd, SP_HP)`. `UnitHp` is
  reserved for monster HP bars and is not used here.

  On death the player is marked `:dead` and nearby players receive a
  `UnitDespawn` with the died reason, while the corpse remains spatially present
  for observer delivery and corpse-targeted skills. Respawn revives the player
  and warps them to their save point; if that warp fails (e.g. the save map is
  unknown) it falls back to resurrecting in place and standing the sprite back
  up via a `Resurrect`.
  """

  require Logger

  alias Aesir.Commons.StatusParams
  alias Aesir.Net.Resurrect
  alias Aesir.Net.UnitDespawn
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionAdapter
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.Session.Vitals
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

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
  @spec apply_damage(integer(), integer() | nil, SessionState.t()) :: {:noreply, SessionState.t()}
  def apply_damage(_damage, _attacker_id, %{game_state: %{action_state: :dead}} = state) do
    {:noreply, state}
  end

  def apply_damage(damage, attacker_id, state) when is_integer(damage) and damage > 0 do
    stats = state.game_state.stats
    new_hp = damaged_hp(stats.current_state.hp, damage)
    max_hp = stats.derived_stats.max_hp
    char_id = state.game_state.character_id

    updated_stats = %{stats | current_state: %{stats.current_state | hp: new_hp}}
    game_state = %{state.game_state | stats: updated_stats}
    state = StatsManager.update_game_state(state, game_state)

    StatusSync.send_param(state.connection_pid, StatusParams.hp(), new_hp)
    CharacterPersistence.update_stats(char_id, %{hp: new_hp}, async: true)

    StatusInterpreter.on_damage(:player, char_id, %{
      damage: damage,
      element: :neutral,
      hp_after: new_hp,
      max_hp: max_hp
    })

    if new_hp == 0 do
      handle_death(attacker_id, state)
    else
      {:noreply, SkillHandler.interrupt_cast_on_damage(state)}
    end
  end

  def apply_damage(_damage, _attacker_id, state), do: {:noreply, state}

  @doc """
  Applies a heal to the player.

  Raises HP by `amount`, clamped at `max_hp`. No-op when the player is dead
  or `amount` is non-positive. Does not trigger death or cast-interrupt logic.
  """
  @spec apply_heal(non_neg_integer(), integer() | nil, SessionState.t()) ::
          {:noreply, SessionState.t()}
  def apply_heal(_amount, _source_id, %{game_state: %{action_state: :dead}} = state) do
    {:noreply, state}
  end

  def apply_heal(amount, _source_id, state) when amount > 0 do
    stats = state.game_state.stats
    max_hp = stats.derived_stats.max_hp
    char_id = state.game_state.character_id
    scaled = scale_received_heal(amount, char_id)
    new_hp = min(stats.current_state.hp + scaled, max_hp)

    updated_stats = %{stats | current_state: %{stats.current_state | hp: new_hp}}
    game_state = %{state.game_state | stats: updated_stats}
    state = StatsManager.update_game_state(state, game_state)

    StatusSync.send_param(state.connection_pid, StatusParams.hp(), new_hp)
    CharacterPersistence.update_stats(char_id, %{hp: new_hp}, async: true)

    {:noreply, state}
  end

  def apply_heal(_amount, _source_id, state), do: {:noreply, state}

  # Scales a heal by the target's `received_heal_rate` (SC_INCHEALRATE) percent
  # delta before it is applied (rAthena `skill.cpp:671-675`). Natural regen is
  # not routed here, so it never double-dips this bonus.
  defp scale_received_heal(amount, char_id) do
    rate =
      :player
      |> ModifierCalculator.get_all_modifiers(char_id)
      |> Map.get(:received_heal_rate, 0)

    div(amount * (100 + rate), 100)
  end

  @doc """
  Drains SP from the player, clamping at zero, then syncs and persists it.

  Routes through `Unit.Session.Vitals`, which owns the clamp and pushes only the
  SP `ParamChange` + persists only `sp`. Used by SP-costing statuses.
  """
  @spec consume_sp(non_neg_integer(), SessionState.t()) :: {:noreply, SessionState.t()}
  def consume_sp(amount, state) do
    {:noreply, Vitals.drain_sp(state, amount, SessionAdapter, commit: true)}
  end

  @doc """
  Attempts to deduct SP without allowing the value to underflow.

  Unlike `consume_sp/2`, this synchronous operation leaves state unchanged when
  the player cannot pay the entire amount; on success it drains through the same
  `Unit.Session.Vitals` path.
  """
  @spec try_consume_sp(non_neg_integer(), SessionState.t()) ::
          {:reply, :ok | {:error, :insufficient_sp}, SessionState.t()}
  def try_consume_sp(amount, state) when is_integer(amount) and amount > 0 do
    if Vitals.can_pay_sp?(state, SessionAdapter, amount) do
      {:reply, :ok, Vitals.drain_sp(state, amount, SessionAdapter, commit: true)}
    else
      {:reply, {:error, :insufficient_sp}, state}
    end
  end

  def try_consume_sp(_amount, state), do: {:reply, {:error, :insufficient_sp}, state}

  @doc """
  Validates the resurrection source, then revives the corpse on success.

  The single entry point for a `{:unit, {:resurrect, source_id, hp_percent}}` call:
  confirms the source is still alive and co-located with the target before
  delegating to `resurrect/3`, replying with the validation error and leaving
  `state` untouched when the source has moved on or gone away.
  """
  @spec handle_resurrect(integer(), pos_integer(), SessionState.t()) ::
          {:reply, :ok | {:error, :stale_target | :invalid_hp_percent | :source_unavailable},
           SessionState.t()}
  def handle_resurrect(source_id, hp_percent, state) do
    case validate_resurrection_source(source_id, state) do
      :ok -> resurrect(source_id, hp_percent, state)
      {:error, _reason} = error -> {:reply, error, state}
    end
  end

  @doc """
  Revives a corpse in place at `hp_percent` of maximum HP.

  The session revalidates the corpse immediately before committing the state
  transition so a cast that completed after another resurrection cannot mutate
  a living target.
  """
  @spec resurrect(integer(), pos_integer(), SessionState.t()) ::
          {:reply, :ok | {:error, :stale_target | :invalid_hp_percent}, SessionState.t()}
  def resurrect(_source_id, hp_percent, state)
      when is_integer(hp_percent) and hp_percent > 0 and hp_percent <= 100 do
    if TargetState.corpse?(state.game_state) do
      stats = state.game_state.stats
      hp = max(1, div(stats.derived_stats.max_hp * hp_percent, 100))
      updated_stats = %{stats | current_state: %{stats.current_state | hp: hp}}

      {:ok, game_state} =
        state.game_state
        |> Map.put(:stats, updated_stats)
        |> PlayerState.transition_to(:idle)

      state = StatsManager.update_game_state(state, game_state)
      StatusSync.send_param(state.connection_pid, StatusParams.hp(), hp)
      CharacterPersistence.update_stats(game_state.character_id, %{hp: hp}, async: true)

      resurrection = %Resurrect{gid: game_state.character_id, type: 0}
      MessageRouter.send_to(state.connection_pid, resurrection)
      Broadcast.to_visible_players(game_state, resurrection)

      {:reply, :ok, state}
    else
      {:reply, {:error, :stale_target}, state}
    end
  end

  def resurrect(_source_id, _hp_percent, state),
    do: {:reply, {:error, :invalid_hp_percent}, state}

  defp validate_resurrection_source(source_id, %{game_state: target_state}) do
    with {:ok, source_map} <- source_map(source_id, target_state.character_id),
         {:ok, target_map} <- target_map(target_state) do
      if source_map == target_map, do: :ok, else: {:error, :stale_target}
    end
  end

  defp source_map(source_id, target_id) when source_id == target_id,
    do: {:error, :source_unavailable}

  defp source_map(source_id, _target_id) do
    with {:ok, {_module, source_state, source_pid}} <- UnitRegistry.get_unit(:player, source_id),
         true <- is_pid(source_pid) and Process.alive?(source_pid),
         {:ok, {_x, _y, source_map}} <- SpatialIndex.get_unit_position(:player, source_id),
         true <- source_state.map_name == source_map do
      {:ok, source_map}
    else
      _ -> {:error, :source_unavailable}
    end
  end

  defp target_map(target_state) do
    case SpatialIndex.get_unit_position(:player, target_state.character_id) do
      {:ok, {_x, _y, map_name}} when map_name == target_state.map_name -> {:ok, map_name}
      _ -> {:error, :stale_target}
    end
  end

  @doc """
  Restores SP to the player, clamped at `max_sp`.

  The mirror of `consume_sp/2` through `Unit.Session.Vitals`; no-op for a
  non-positive amount.
  """
  @spec restore_sp(integer(), SessionState.t()) :: {:noreply, SessionState.t()}
  def restore_sp(amount, state) do
    {:noreply, Vitals.restore_sp(state, amount, SessionAdapter, commit: true)}
  end

  @doc """
  Handles a CZ_RESTART request.

  Type 0 respawns a dead player; type 1 (return to character select) disconnects
  the session.
  """
  @spec handle_restart(non_neg_integer(), SessionState.t()) ::
          {:noreply, SessionState.t()} | {:stop, :normal, SessionState.t()}
  def handle_restart(0, %{game_state: %{action_state: :dead}} = state), do: respawn(state)
  def handle_restart(0, state), do: {:noreply, state}

  # char-select returns to the char server; we have no such flow yet,
  # so just drop the session. Add the char-server handoff when it exists.
  def handle_restart(1, state), do: {:stop, :normal, state}
  def handle_restart(_type, state), do: {:noreply, state}

  defp handle_death(attacker_id, %{game_state: game_state} = state) do
    Logger.info("Player #{game_state.character_id} died (killed by #{inspect(attacker_id)})")

    inactive_state =
      game_state
      |> cancel_cast_timer()
      |> PlayerState.stop_walking()
      |> PlayerState.clear_combat_intent()
      |> PlayerState.clear_skill_intent()
      |> PlayerState.clear_pickup_intent()

    {:ok, dead_state} = PlayerState.transition_to(inactive_state, :dead)
    state = StatsManager.update_game_state(state, dead_state)

    vanish = %UnitDespawn{gid: game_state.character_id, reason: DespawnReason.died()}
    Broadcast.to_visible_players(dead_state, vanish)
    Lifecycle.publish_death(:player, game_state.character_id, game_state.map_name)

    {:noreply, state |> SkillMenuHandler.clear() |> apply_death_penalty()}
  end

  defp cancel_cast_timer(%PlayerState{casting: %{timer_ref: timer_ref}} = game_state)
       when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
    game_state
  end

  defp cancel_cast_timer(game_state), do: game_state

  # Renewal death EXP penalty (rAthena exp.conf death_penalty_base/job). Skipped
  # when both config rates are 0 or the dying player carries `no_death_penalty`
  # (SC_LIFEINSURANCE). The penalty never de-levels — see `Leveling.death_penalty/3`.
  defp apply_death_penalty(%{game_state: game_state} = state) do
    base_pct = Config.death_penalty_base()
    job_pct = Config.death_penalty_job()

    cond do
      base_pct == 0 and job_pct == 0 ->
        state

      ModifierCalculator.get_all_modifiers(:player, game_state.character_id)
      |> Map.get(:no_death_penalty, 0) > 0 ->
        state

      true ->
        subtract_death_exp(state, base_pct, job_pct)
    end
  end

  defp subtract_death_exp(%{game_state: game_state} = state, base_pct, job_pct) do
    progression = game_state.stats.progression
    {base_loss, job_loss} = Leveling.death_penalty(progression, base_pct, job_pct)

    if base_loss == 0 and job_loss == 0 do
      state
    else
      progression = %{
        progression
        | base_exp: progression.base_exp - base_loss,
          job_exp: progression.job_exp - job_loss
      }

      stats = %{game_state.stats | progression: progression}
      game_state = %{game_state | stats: stats}
      state = StatsManager.update_game_state(state, game_state)

      StatusSync.send_params(state.connection_pid, %{
        StatusParams.base_exp() => progression.base_exp,
        StatusParams.job_exp() => progression.job_exp
      })

      CharacterPersistence.update_character(
        game_state.character_id,
        %{base_exp: progression.base_exp, job_exp: progression.job_exp},
        async: true
      )

      state
    end
  end

  defp respawn(%{game_state: game_state} = state) do
    stats = game_state.stats
    max_hp = stats.derived_stats.max_hp
    max_sp = stats.derived_stats.max_sp

    revived_stats = %{stats | current_state: %{stats.current_state | hp: max_hp, sp: max_sp}}

    {:ok, idle_state} = PlayerState.transition_to(game_state, :idle)
    idle_state = %{idle_state | stats: revived_stats}
    state = StatsManager.update_game_state(state, idle_state)

    StatusSync.send_params(state.connection_pid, [
      {StatusParams.max_hp(), max_hp},
      {StatusParams.hp(), max_hp},
      {StatusParams.max_sp(), max_sp},
      {StatusParams.sp(), max_sp}
    ])

    CharacterPersistence.update_stats(game_state.character_id, %{hp: max_hp, sp: max_sp},
      async: true
    )

    warp_to_save_point(state, idle_state)
  end

  # Warp the revived player to their save point. On failure (unknown save map)
  # fall back to resurrecting in place — rAthena's own behaviour when the
  # save-point warp fails (clif_resurrection).
  defp warp_to_save_point(state, idle_state) do
    case WarpHandler.warp(state, idle_state.save_map, idle_state.save_x, idle_state.save_y) do
      {:ok, warped_state} ->
        {:noreply, warped_state}

      {:error, reason} ->
        Logger.warning(
          "Save-point warp failed for player #{idle_state.character_id} (#{inspect(reason)}); resurrecting in place"
        )

        resurrect_in_place(state, idle_state)
    end
  end

  defp resurrect_in_place(state, idle_state) do
    SpatialIndex.add_player(
      idle_state.character_id,
      idle_state.x,
      idle_state.y,
      idle_state.map_name
    )

    visible_state = MovementHandler.handle_visibility_update(idle_state)
    state = StatsManager.update_game_state(state, visible_state)

    resurrection = %Resurrect{gid: idle_state.character_id, type: 0}
    MessageRouter.send_to(state.connection_pid, resurrection)
    Broadcast.to_visible_players(visible_state, resurrection)

    {:noreply, state}
  end
end
