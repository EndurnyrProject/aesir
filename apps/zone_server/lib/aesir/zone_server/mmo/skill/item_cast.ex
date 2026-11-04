defmodule Aesir.ZoneServer.Mmo.Skill.ItemCast do
  @moduledoc """
  The item-triggered cast: the restricted entry `itemskill` and a
  client-selected item skill use.

  Player-only, because item scripts execute against a player inventory. The
  item itself is the cost: the cast runs the player's use stages with the
  source's cast-begin item branch, which replaces the learned rank and, for a
  plain item cast, every requirement after it (SP, HP, zeny, catalysts, ammo,
  weight and the act-delay gate), charging none of them; `keep_requirement`
  keeps them. What stays is what makes the cast well-formed rather than
  affordable: the skill must exist, have a behavior module, and the target
  must be valid and in range; the behavior's own `validate/4` still runs. The
  skill's cooldown and aftercast delay are armed on success, so an item cast
  cannot be spammed past the skill's own pacing.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastConditions
  alias Aesir.ZoneServer.Mmo.Skill.CastContext
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.CastExecution
  alias Aesir.ZoneServer.Mmo.Skill.CastPacing
  alias Aesir.ZoneServer.Mmo.Skill.CastSettlement
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.CastValidation
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "A cast-begin outcome; see `Skill.Interpreter.cast_info/0` for the casting info."
  @type begin_outcome ::
          {:instant, PlayerState.t()}
          | {:instant, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:casting, PlayerState.t(), map()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
          | {:error, atom(), PlayerState.t(), :before_start | :after_start}

  @typedoc "A cast-end outcome."
  @type complete_outcome ::
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}

  @doc """
  Begins a client-selected item skill without learned or resource requirements.

  The cast runs the player's cast stages; its cast-begin conditions are the
  source's item branch, where the item itself is the cost. A delayed-consume
  item passes one owner-local consumption callback, run where the source claims
  it: after the chat-room refusal and before the weight limit. A timed cast
  retains its origin so completion keeps this restricted requirement contract.
  """
  @spec begin_item_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:instant, PlayerState.t()}
          | {:instant, PlayerState.t(), [Active.effect()]}
          | {:casting, PlayerState.t(), map()}
          | {:failed, PlayerState.t(), atom()}
          | {:error, atom()}
          | {:error, atom(), PlayerState.t()}
  def begin_item_cast(caster, skill_id, level, target) do
    case begin_item_cast(caster, skill_id, level, target, &{:ok, &1}) do
      {:error, reason, refreshed, _stage} when refreshed == caster -> {:error, reason}
      {:error, reason, refreshed, _stage} -> {:error, reason, refreshed}
      outcome -> outcome
    end
  end

  @doc "Begins a staged item cast; the callback claims the item inside the cast-begin conditions, before the rest of them and before the range check."
  @spec begin_item_cast(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          (PlayerState.t() -> {:ok, PlayerState.t()} | {:error, atom()})
        ) :: begin_outcome()
  def begin_item_cast(caster, skill_id, level, target, on_ready),
    do: begin_item_cast(caster, skill_id, level, target, on_ready, false)

  @doc "Begins an item cast with the source's optional requirement-retention recipe."
  @spec begin_item_cast(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          (PlayerState.t() -> {:ok, PlayerState.t()} | {:error, atom()}),
          boolean()
        ) :: begin_outcome()
  def begin_item_cast(%PlayerState{} = caster, skill_id, level, target, on_ready, keep?)
      when is_integer(level) and level > 0 and is_function(on_ready, 1) and is_boolean(keep?) do
    with {:ok, definition} <- fetch_item_definition(skill_id, level) do
      early = CastTime.early(definition, level, Caster.Player.cast_stats(caster, skill_id))
      caster = Caster.apply_cast_reactions(caster, early.reactions)
      begin_item_stages(caster, definition, level, target, early, on_ready, keep?)
    end
  end

  def begin_item_cast(_caster, _skill_id, _level, _target, _on_ready, _keep?),
    do: {:error, :invalid_level}

  # An item cast passes the player's use stages, then its own cast-begin
  # conditions: the source's item branch replaces the learned rank and, for a
  # plain item cast, every requirement after it. Its cast-end checks stay at the
  # cast end (`complete_item_cast/5`).
  defp begin_item_stages(caster, definition, level, target, early, on_ready, keep?) do
    opts = [
      item_skill: item_skill(definition.id, level, keep?),
      walk_action: false,
      learned?: false
    ]

    case CastValidation.check_player_use(caster, definition.id, level, target, :cast_begin, opts) do
      {:ok, context} ->
        case CastValidation.item_castbegin(context, on_ready, keep?) do
          {:ok, prepared} -> finish_item_stages(context, prepared, target, early, keep?, opts)
          {:error, reason, claimed} -> {:error, reason, claimed, :after_start}
          {:error, reason} -> item_begin_failure(reason, context.caster, caster)
        end

      {:error, reason} ->
        item_begin_failure(reason, caster, caster)
    end
  end

  # A refusal before the item branch leaves the item unclaimed.
  defp item_begin_failure(reason, refreshed, original) do
    if refreshed == original,
      do: {:error, reason},
      else: {:error, reason, refreshed, :before_start}
  end

  defp finish_item_stages(context, prepared, target, early, keep?, opts) do
    case CastValidation.check_player_after_begin(context.caster, prepared, :cast_begin, opts) do
      {:ok, ready} -> finish_item_attempt(ready, target, early, keep?)
      {:error, reason} -> {:error, reason, prepared.caster, :after_start}
    end
  end

  defp finish_item_attempt(%CastContext{} = context, target, early, keep?) do
    definition = context.definition
    skill_id = definition.id
    caster = CastExecution.stop_attack_at_cast_start(context.caster, false)

    %{timing: timing, reactions: reactions} =
      CastTime.late(
        definition,
        context.level,
        Caster.Player.cast_stats(caster, skill_id),
        early.time
      )

    refreshed = Caster.apply_cast_reactions(caster, reactions)
    CastExecution.notify_cast_targeted(refreshed, definition, target, timing.total > 0)

    if timing.total == 0 do
      started = CastExecution.cast_start(refreshed, Caster.Player, skill_id)

      started
      |> complete_item_cast(skill_id, context.level, target, keep?)
      |> item_attempt_outcome(started)
    else
      {:casting, refreshed,
       %{
         skill_id: skill_id,
         level: context.level,
         target: target,
         element: definition.element,
         fixed: timing.fixed,
         total: timing.total,
         origin: :item,
         keep_requirement?: keep?
       }}
    end
  end

  defp fetch_item_definition(skill_id, level) do
    with {:ok, definition} <- CastConditions.fetch_definition(skill_id) do
      cooldown = definition.cooldown
      extra_levels = max(level - length(cooldown), 0)

      padded =
        case List.last(cooldown) do
          nil -> cooldown
          duration -> cooldown ++ List.duplicate(duration, extra_levels)
        end

      {:ok, %{definition | cooldown: padded}}
    end
  end

  defp item_skill(skill_id, level, keep?),
    do: %{skill_id: skill_id, level: level, keep_requirement?: keep?}

  defp item_attempt_outcome({:ok, finished}, _started), do: {:instant, finished}

  defp item_attempt_outcome({:local_effects, finished, effects}, _started),
    do: {:instant, finished, effects}

  defp item_attempt_outcome({:deferred, finished, descriptor}, _started),
    do: {:deferred, finished, descriptor}

  defp item_attempt_outcome({:failed, _finished, _reason} = failed, _started), do: failed

  defp item_attempt_outcome({:failed, _finished, _reason, _variant} = failed, _started),
    do: failed

  defp item_attempt_outcome({:skipped, _finished, _reason} = skipped, _started), do: skipped
  defp item_attempt_outcome({:castend_failed, _finished, _reason} = failed, _started), do: failed

  defp item_attempt_outcome({:error, reason}, started),
    do: {:error, reason, started, :after_start}

  @doc """
  Completes an item skill against the current target without learned or resource checks.
  """
  @spec complete_item_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          complete_outcome()
  def complete_item_cast(caster, skill_id, level, target),
    do: complete_item_cast(caster, skill_id, level, target, false)

  @doc "Completes an item cast, charging the skill's own requirements when retained."
  @spec complete_item_cast(PlayerState.t(), integer(), pos_integer(), Active.target(), boolean()) ::
          complete_outcome()
  def complete_item_cast(%PlayerState{} = caster, skill_id, level, target, true) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_item_definition(skill_id, level),
         :ok <- CastConditions.check_placement(caster, definition, target),
         {:ok, module} <- validate_item_cast(caster, target, level, definition),
         :ok <- CastConditions.check_castend_target(caster, target, definition),
         {:ok, cost} <- Caster.Player.castend_cost(caster, module, target, definition, level) do
      CastSettlement.complete_resolved_cast(caster, module, target, level, definition, %{
        adapter: Caster.Player,
        prepared_cost: cost,
        skill_id: skill_id,
        level: level,
        apply_act_delay: Enum.at(definition.after_cast_delay, level - 1, 0) > 0,
        after_cast_delay: CastPacing.resolved_after_cast_delay(caster, definition, level),
        now: now,
        input: :without_input,
        origin: :item
      })
      |> retain_menu_requirements(true)
    end
  end

  def complete_item_cast(%PlayerState{} = caster, skill_id, level, target, false) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_item_definition(skill_id, level),
         :ok <- CastConditions.check_placement(caster, definition, target),
         {:ok, module} <- validate_item_cast(caster, target, level, definition),
         :ok <- CastConditions.check_castend_target(caster, target, definition) do
      cond do
        CastConditions.dead_target_skip?(definition, target) ->
          {:ok, pace_item_cast(caster, module, skill_id, definition, level, now)}
          |> retain_menu_requirements(false)

        CastConditions.walk_path_blocked?(definition, caster, target) ->
          {:error, :projectile_blocked}

        true ->
          run_item_effect(module, caster, target, level, definition, now)
      end
    end
  end

  defp run_item_effect(module, caster, target, level, definition, now) do
    caster = pace_item_cast(caster, module, definition.id, definition, level, now)

    case CastExecution.run_unconditional(module, caster, target, level, definition, :item, false) do
      {:ok, caster} ->
        retain_menu_requirements({:ok, caster}, false)

      {:local_effects, caster, effects} ->
        {:local_effects, caster, effects}

      {:failed, caster, reason} ->
        {:failed, caster, reason}

      {:skipped, caster, _reason} ->
        retain_menu_requirements({:ok, caster}, false)

      error ->
        error
    end
  end

  defp pace_item_cast(caster, module, skill_id, definition, level, now) do
    caster
    |> CastPacing.put_cooldown(skill_id, definition, level, now)
    |> CastPacing.rearm_cooldowns(module, level, definition, now)
    |> CastPacing.put_act_delay(definition, level, now)
  end

  defp retain_menu_requirements(
         {:ok, %{pending_menu_offer: %{context: context} = offer} = caster},
         keep?
       ) do
    offer = %{offer | context: Map.put(context, :consume_items?, keep?)}
    {:ok, %{caster | pending_menu_offer: offer}}
  end

  defp retain_menu_requirements(result, _keep?), do: result

  defp validate_item_cast(caster, target, level, definition) do
    with {:ok, module} <- validate_item_target(caster, target, level, definition),
         :ok <- validate_item_range(caster, module, target, level, definition) do
      {:ok, module}
    end
  end

  # The cast end of an item skill, in the reference's order: its level and
  # behavior, the target it may complete on, then the completion state of the
  # caster and the target.
  defp validate_item_target(caster, target, level, definition) do
    with :ok <- CastConditions.check_item_level(level),
         :ok <- CastConditions.check_castable(definition),
         {:ok, module} <- CastConditions.fetch_active_module(definition),
         :ok <- CastConditions.check_target(caster, target, definition),
         :ok <- CastConditions.check_cast_end(caster, target, definition, true) do
      {:ok, module}
    end
  end

  defp validate_item_range(caster, module, target, level, definition) do
    with :ok <- CastConditions.check_range(caster, target, definition, level) do
      module.validate(caster, target, level, definition)
    end
  end

  @doc """
  Runs an item-triggered cast to completion: the restricted entry `itemskill`
  uses. A timed cast completes inline. The positive skill level is authorized
  by the item's script and may exceed the learned skill's maximum.
  """
  @spec item_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:failed, PlayerState.t(), atom()}
          | {:error, atom()}
  def item_cast(%PlayerState{} = game_state, skill_id, level, target)
      when is_integer(level) and level > 0 do
    case begin_item_cast(game_state, skill_id, level, target) do
      {:instant, caster} -> {:ok, caster}
      {:instant, caster, effects} -> {:local_effects, caster, effects}
      {:casting, caster, _info} -> complete_item_cast(caster, skill_id, level, target)
      error -> error
    end
  end

  def item_cast(%PlayerState{}, _skill_id, _level, _target), do: {:error, :invalid_level}
  def item_cast(_game_state, _skill_id, _level, _target), do: {:error, :unsupported_caster}
end
