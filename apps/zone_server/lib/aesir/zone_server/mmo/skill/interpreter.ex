defmodule Aesir.ZoneServer.Mmo.Skill.Interpreter do
  @moduledoc """
  Orchestrates a skill cast across two phases.

  `begin_cast/4` runs the full validation chain with the cast-begin
  requirements (SP, zeny, spirit spheres) and computes the active mode's cast
  time; a zero-cast skill resolves immediately, a timed skill returns a
  `cast_info` for the caller to schedule and leaves the game state untouched
  (no SP deducted, no cooldown set). `complete_cast/4` re-validates the target,
  checks the cast-end requirements (the skill's own, HP, weapon, ammo, items),
  spends the HP, SP, spheres and zeny up to what the caster holds, runs the
  behavior on the paid caster, then consumes the items and ammo, sets the
  cooldown, and arms the after-cast act delay. An instant cast runs its
  cast-start effects, then the same cast end.

  Resources are only consumed at the cast end, so an interrupted cast or one
  refused by a cast-end check never charges them. Starting any cast is blocked
  while the act delay is pending (`validate_cast` rejects with
  `{:error, :act_delayed}`).

  `cast/4` is the synchronous wrapper preserving the legacy single-call
  semantics: instant casts execute immediately and timed casts run their
  behavior inline through `complete_cast/4`.

  `auto_cast/4` and `item_cast/4` are narrow entry points for casts the player
  did not initiate (a status proc, an item's script); each documents exactly
  which requirements it bypasses. Status auto-casts accept every registered
  caster and charge only SP. Item casts are player-only because item scripts
  operate on player inventories.

  The pieces live beside this module: the individual conditions in
  `CastConditions`, the validation chains in `CastValidation`, the behavior
  invocation in `CastExecution`, the cast end and its settlement in
  `CastSettlement`, cooldown and act delay in `CastPacing`, and the item cast
  in `ItemCast`.
  """
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastConditions
  alias Aesir.ZoneServer.Mmo.Skill.CastContext
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.CastExecution
  alias Aesir.ZoneServer.Mmo.Skill.CastPacing
  alias Aesir.ZoneServer.Mmo.Skill.CastSettlement
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.CastValidation
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ItemCast
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.UseRestrictions
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule Deferred do
    @moduledoc "Deferred effect plus the owner-local resources settled on reply."

    alias Aesir.ZoneServer.Mmo.Skill.Active
    alias Aesir.ZoneServer.Mmo.Skill.Cost

    @enforce_keys [:effect, :cost, :zeny, :skill_id, :level, :target]
    defstruct [:effect, :cost, :zeny, :skill_id, :level, :target]

    @type t() :: %__MODULE__{
            effect: term(),
            cost: Cost.t(),
            zeny: non_neg_integer(),
            skill_id: integer(),
            level: pos_integer(),
            target: Active.target()
          }
  end

  @typedoc """
  Scheduling info for a timed cast, returned by `begin_cast/4` when the skill
  has a non-zero cast time. `fixed` is the uninterruptible leading window and
  `total` the full duration, both in milliseconds. `origin` tags who started
  the cast; an item cast carries `keep_requirement?` and an Encore replay its
  `memory`.
  """
  @type cast_info :: %{
          optional(:reactions_consumed?) => boolean(),
          optional(:origin) => atom(),
          optional(:keep_requirement?) => boolean(),
          optional(:memory) => map(),
          skill_id: integer(),
          level: pos_integer(),
          target: Active.target(),
          element: Definition.element(),
          fixed: non_neg_integer(),
          total: non_neg_integer()
        }

  @spec cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
          | {:error, atom(), PlayerState.t()}
  def cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    case begin_cast(game_state, skill_id, level, target) do
      {:instant, game_state} ->
        {:ok, game_state}

      {:instant, game_state, effects} ->
        {:local_effects, game_state, effects}

      {:casting, refreshed, info} ->
        finish_synchronous_cast(game_state, refreshed, info, skill_id, level, target)

      deferred_failed_or_error ->
        deferred_failed_or_error
    end
  end

  def cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  defp finish_synchronous_cast(original, refreshed, info, skill_id, level, target) do
    case complete_cast(refreshed, skill_id, level, target) do
      {:error, reason} ->
        if info[:reactions_consumed?] or refreshed != original,
          do: {:error, reason, refreshed},
          else: {:error, reason}

      result ->
        result
    end
  end

  @doc """
  Validates a real cast attempt and resolves its timing. Classic early timing
  runs before target/range/cost checks and can consume Foresight even when those
  checks reject the attempt. Late timing runs only after validation. On failure
  after a reaction, returns the refreshed caster so its owner can commit it;
  pure `preflight_cast/4` never runs either reaction.

  Instant casts complete immediately, while timed casts return their total
  scheduling time and the already-refreshed caster. Completion does not
  compute cast time or consume timing reactions again.
  """
  @spec begin_cast(Active.caster(), integer(), pos_integer(), Active.target()) ::
          {:instant, Active.caster()}
          | {:instant, Active.caster(), [Active.effect()]}
          | {:deferred, Active.caster(), term()}
          | {:casting, Active.caster(), cast_info()}
          | {:failed, Active.caster(), atom()}
          | {:failed, Active.caster(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, Active.caster(), atom()}
          | {:castend_failed, Active.caster(), atom()}
          | {:error, atom()}
          | {:error, atom(), Active.caster()}
  def begin_cast(game_state, skill_id, level, target),
    do: begin_cast(game_state, skill_id, level, target, [])

  @doc """
  `begin_cast/4` with options. `attack_reach: true` marks a player's combo used
  while swinging at its target: it has the attack's reach, so the skill's range
  is not checked (the walking step rule still is). `learned?: false` skips the
  player's learned-rank check, for a cast a script starts; `origin: :script`
  tags the resulting cast info so its cast end skips the learned-rank re-check
  too.
  """
  @spec begin_cast(Active.caster(), integer(), pos_integer(), Active.target(), keyword()) ::
          term()
  def begin_cast(game_state, skill_id, level, target, opts)
      when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         {:ok, adapter} <- CastValidation.lifecycle_adapter(game_state) do
      begin_real_attempt(game_state, skill_id, level, target, definition, adapter, now, opts)
    end
  end

  def begin_cast(_game_state, _skill_id, _level, _target, _opts), do: {:error, :invalid_level}

  defp begin_real_attempt(caster, skill_id, level, target, definition, adapter, now, opts) do
    inputs = :erlang.apply(adapter, :cast_stats, [caster, skill_id])
    early = CastTime.early(definition, level, inputs)
    refreshed = Caster.apply_cast_reactions(caster, early.reactions)

    case CastValidation.validate_cast(refreshed, skill_id, level, target, now, :cast_begin, opts) do
      {:ok, context} ->
        finish_attempt(context.caster, skill_id, level, target, context, early, opts)

      {:error, reason} ->
        if early.reactions == [],
          do: {:error, reason},
          else: {:error, reason, refreshed}
    end
  end

  defp finish_attempt(caster, skill_id, level, target, context, early, opts) do
    timing_definition =
      CastPacing.cast_timing_definition(
        caster,
        context.module,
        target,
        level,
        context.definition
      )

    time =
      if timing_definition.cast_time == context.definition.cast_time,
        do: early.time,
        else: Enum.at(timing_definition.cast_time, level - 1, 0)

    time = CastPacing.scale_cast_time(context.module, caster, target, level, time)

    %{timing: timing, reactions: reactions} =
      CastTime.late(timing_definition, level, context.stats, time)

    refreshed =
      caster
      |> Caster.apply_cast_reactions(reactions)
      |> CastExecution.stop_attack_at_cast_start(Keyword.get(opts, :attack_reach, false))

    context = %{context | caster: refreshed}

    case schedule(timing, refreshed, skill_id, level, target, context, opts) do
      {:error, reason} when early.reactions != [] or reactions != [] or refreshed != caster ->
        {:error, reason, refreshed}

      {:casting, caster, info} ->
        {:casting, caster,
         Map.put(info, :reactions_consumed?, early.reactions != [] or reactions != [])}

      outcome ->
        outcome
    end
  end

  @doc """
  Validates every ordinary cast requirement without mutating the caster.
  """
  @spec preflight_cast(Caster.state(), integer(), pos_integer(), Active.target()) ::
          :ok | {:error, atom()}
  def preflight_cast(caster, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    case CastValidation.validate_cast(caster, skill_id, level, target, now) do
      {:ok, _context} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def preflight_cast(_caster, _skill_id, _level, _target), do: {:error, :invalid_level}

  @doc """
  A walking player's attempt to use `skill_id`: every check up to the range,
  where a target the player does not reach at one cell less than the skill's
  range is remembered rather than refused.

  Returns `:in_range` when the cast would start now (the caller stops the walk
  and begins it with `begin_cast/5`, which runs the attempt for real),
  `{:step, caster}` when it is remembered, or `{:error, reason, caster}` when
  a check refuses it. The attempt's early cast-time reactions (Memorize, which
  the source spends computing the cast time before every attempt) are spent
  in the last two cases. Takes `begin_cast/5`'s options.
  """
  @spec walking_attempt(PlayerState.t(), integer(), pos_integer(), Active.target(), keyword()) ::
          :in_range | {:step, PlayerState.t()} | {:error, term(), PlayerState.t()}
  def walking_attempt(%PlayerState{} = caster, skill_id, level, target, opts \\ []) do
    case CastValidation.validate_player_cast(caster, skill_id, level, target, :cast_begin, opts) do
      {:ok, _context} -> :in_range
      {:error, :step_action} -> {:step, spend_early_reactions(caster, skill_id, level)}
      {:error, reason} -> {:error, reason, spend_early_reactions(caster, skill_id, level)}
    end
  end

  defp spend_early_reactions(caster, skill_id, level) do
    case CastConditions.fetch_definition(skill_id) do
      {:ok, definition} ->
        early = CastTime.early(definition, level, Caster.Player.cast_stats(caster, skill_id))
        Caster.apply_cast_reactions(caster, early.reactions)

      {:error, _reason} ->
        caster
    end
  end

  @doc """
  Whether a player's cast of `skill_id` would pass its cast-begin conditions
  now (`castbegin`), without casting anything. A combo skill's use is aimed by
  its combo only when they pass.
  """
  @spec castbegin_passes?(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          boolean()
  def castbegin_passes?(%PlayerState{} = caster, skill_id, level, target) do
    with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         {:ok, _module} <- CastConditions.fetch_active_module(definition) do
      context = CastContext.build(caster, definition, level, target, :begin)
      match?({:ok, _context}, CastValidation.castbegin(context, true))
    else
      _missing -> false
    end
  end

  @doc "Validates catalog identity and learned rank without mutable cast checks."
  @spec preflight_skill(Caster.state(), integer(), pos_integer()) :: :ok | {:error, atom()}
  def preflight_skill(caster, skill_id, level) when is_integer(level) and level > 0 do
    with {:ok, adapter} <- CastValidation.lifecycle_adapter(caster),
         {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_max_level(definition, level),
         :ok <- CastConditions.check_castable(definition) do
      :erlang.apply(adapter, :knows?, [caster, definition, level, :begin])
    end
  end

  def preflight_skill(_caster, _skill_id, _level), do: {:error, :invalid_level}

  @doc """
  Validates an Encore-remembered skill without mutating the caster.

  This restricted entry point accepts performances and ensembles.
  It reuses the remembered skill's current catalog, level, learned, weapon,
  target, module-validation, and cooldown checks. Encore's own ordinary cast
  remains responsible for its learned state, cooldown, global act delay, and
  transformed SP affordability.
  """
  @spec encore_replay_preflight(PlayerState.t(), map(), Active.target()) ::
          :ok | {:error, atom()}
  def encore_replay_preflight(game_state, memory, target) do
    now = System.monotonic_time(:millisecond)

    case CastValidation.validate_encore_replay(game_state, memory, target, now) do
      {:ok, _prepared} -> :ok
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Resolves cast timing for a replayable, fully validated Encore memory.

  The returned values are the remembered skill's current base variable and
  fixed cast times at the remembered level. The outer Encore cast applies the
  caster's ordinary timing reductions exactly once.
  """
  @spec encore_replay_timing(PlayerState.t(), map(), Active.target()) ::
          {:ok, %{cast_time: non_neg_integer(), fixed_cast_time: non_neg_integer()}}
          | {:error, atom()}
  def encore_replay_timing(game_state, memory, target) do
    now = System.monotonic_time(:millisecond)

    with {:ok, %{definition: definition, module: module, level: level}} <-
           CastValidation.validate_encore_replay(game_state, memory, target, now) do
      definition =
        CastPacing.cast_timing_definition(game_state, module, target, level, definition)

      {:ok,
       %{
         cast_time: Enum.at(definition.cast_time, level - 1, 0),
         fixed_cast_time: Enum.at(definition.fixed_cast_time, level - 1, 0)
       }}
    end
  end

  @doc """
  Starts the remembered skill as a second, ordinary timed attempt after Encore.

  The remembered skill keeps its own cast bar, cooldown and resource recipe;
  its raw SP cost is halved before ordinary performance and equipment bonuses.
  Encore's own (instant) attempt already committed separately.
  """
  @spec begin_encore_replay(PlayerState.t(), map(), Active.target()) ::
          {:instant, PlayerState.t()}
          | {:casting, PlayerState.t(), cast_info()}
          | {:failed, PlayerState.t(), atom()}
          | {:error, atom()}
          | {:error, atom(), PlayerState.t()}
  def begin_encore_replay(caster, %{skill_id: skill_id, level: level} = memory, target) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- CastConditions.fetch_definition(skill_id) do
      early = CastTime.early(definition, level, Caster.Player.cast_stats(caster, skill_id))
      caster = Caster.apply_cast_reactions(caster, early.reactions)
      prepare_encore_attempt(caster, memory, target, definition, early, now)
    end
  end

  defp prepare_encore_attempt(caster, memory, target, definition, early, now) do
    with {:ok, prepared} <- CastValidation.validate_encore_replay(caster, memory, target, now),
         {:ok, begun} <-
           CastValidation.begin_attempt(
             prepared.module,
             caster,
             target,
             prepared.level,
             prepared.definition
           ),
         {:ok, _cost} <- encore_prepared_cost(begun, prepared, target, :begin) do
      finish_encore_timing(begun, memory, target, definition, early)
    else
      {:error, reason} ->
        if early.reactions == [],
          do: {:error, reason},
          else: {:error, reason, caster}
    end
  end

  defp finish_encore_timing(
         caster,
         %{skill_id: skill_id, level: level} = memory,
         target,
         definition,
         early
       ) do
    %{timing: timing, reactions: reactions} =
      CastTime.late(definition, level, Caster.Player.cast_stats(caster, skill_id), early.time)

    caster = Caster.apply_cast_reactions(caster, reactions)

    if timing.total == 0 do
      caster = CastExecution.cast_start(caster, Caster.Player, skill_id)

      case complete_encore_replay(caster, memory, target) do
        {:ok, caster} -> {:instant, caster}
        {:error, reason} -> {:error, reason, caster}
      end
    else
      {:casting, caster,
       %{
         skill_id: skill_id,
         level: level,
         target: target,
         element: definition.element,
         fixed: timing.fixed,
         total: timing.total,
         origin: :encore,
         memory: memory
       }}
    end
  end

  @doc """
  Completes the remembered Encore skill, charging its halved raw SP at cast end.
  """
  @spec complete_encore_replay(PlayerState.t(), map(), Active.target()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def complete_encore_replay(game_state, memory, target) do
    now = System.monotonic_time(:millisecond)

    with {:ok, %{definition: definition, skill_id: skill_id, level: level} = prepared} <-
           CastValidation.validate_encore_replay(game_state, memory, target, now),
         :ok <- CastConditions.check_completion_caster(game_state, definition, false),
         {:ok, cost} <- encore_prepared_cost(game_state, prepared, target, :completion) do
      CastSettlement.complete_resolved_cast(
        game_state,
        prepared.module,
        target,
        level,
        definition,
        %{
          adapter: Caster.Player,
          prepared_cost: cost,
          skill_id: skill_id,
          level: level,
          apply_act_delay: Enum.at(definition.after_cast_delay, level - 1, 0) > 0,
          after_cast_delay: CastPacing.resolved_after_cast_delay(game_state, definition, level),
          now: now,
          input: :without_input
        }
      )
    end
  end

  defp encore_prepared_cost(caster, prepared, target, phase) do
    %{definition: definition, module: module, level: level} = prepared
    raw_half = definition.sp_cost |> Enum.at(level - 1, 0) |> div(2)
    sp = Cost.resolve_sp(caster, definition, level, raw_half)
    cost = Cost.from_definition(caster, definition, level, sp: sp)

    with {:ok, cost} <- Cost.validate_resolved(cost) do
      case phase do
        :begin ->
          Caster.Player.prepare_begin_cost(caster, module, definition, cost, 0, level)

        :completion ->
          Caster.Player.prepare_castend_cost(caster, module, target, level, definition, cost, 0)
      end
    end
  end

  @doc """
  Runs a previously-validated cast to completion.

  Re-validates the target (it may have moved, died, or logged out during the
  cast) and checks the cast-end requirements (the skill's own, HP, weapon,
  ammo, items), then spends the primary requirements (HP, SP, spheres, zeny),
  runs the behavior on the paid caster, settles the items and ammo, sets the
  cooldown, and arms the after-cast act delay. SP, zeny and spheres are not
  checked again: each is spent up to what the caster holds. A target that is
  gone or out of range fizzles with `{:error, _}` and no resources are spent.
  An effect that fails after the requirement (`{:failed, caster, reason}` from
  the behavior) is settled like a success and returned as `{:failed, ...}`.

  The cost is prepared from the pre-payment state, so `:all` SP resolves
  against the whole pool; the behavior then sees the paid pool and its own
  HP/SP changes are kept. A deferred result carries only the items left to
  settle.
  """
  @spec complete_cast(Active.caster(), integer(), pos_integer(), Active.target()) ::
          {:ok, Active.caster()}
          | {:local_effects, Active.caster(), [Active.effect()]}
          | {:deferred, Active.caster(), term()}
          | {:failed, Active.caster(), atom()}
          | {:failed, Active.caster(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, Active.caster(), atom()}
          | {:castend_failed, Active.caster(), atom()}
          | {:error, atom()}
  def complete_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0,
    do: complete_validated_cast(game_state, skill_id, level, target, :without_input)

  def complete_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  @doc """
  Completes an input-aware cast through the ordinary validation and commitment path.

  Skills without `cast_with_input/5` retain their normal `cast/4` behavior.
  """
  @spec complete_cast_with_input(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          term()
        ) ::
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
  def complete_cast_with_input(game_state, skill_id, level, target, input)
      when is_integer(level) and level > 0,
      do: complete_validated_cast(game_state, skill_id, level, target, {:with_input, input})

  def complete_cast_with_input(_game_state, _skill_id, _level, _target, _input),
    do: {:error, :invalid_level}

  @doc """
  Completes a cast a script started: the ordinary cast end, without the
  player cast's learned-rank re-check, because the script is the skill's
  permission. Every other cast-end condition still applies.
  """
  @spec complete_script_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
  def complete_script_cast(game_state, skill_id, level, target)
      when is_integer(level) and level > 0,
      do:
        complete_validated_cast(game_state, skill_id, level, target, :without_input,
          learned?: false
        )

  def complete_script_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  defp complete_validated_cast(game_state, skill_id, level, target, input, opts \\ []) do
    now = System.monotonic_time(:millisecond)

    validation =
      case input do
        :without_input ->
          CastValidation.validate_completion(game_state, skill_id, level, target, opts)

        {:with_input, _value} ->
          with {:ok, context} <-
                 CastValidation.validate_cast(game_state, skill_id, level, target, now, :cast_end),
               do: CastValidation.prepare_castend(context, game_state)
      end

    case validation do
      {:ok, prepared} ->
        game_state = CastExecution.begin_input_cast(game_state, input)
        complete_prepared_cast(game_state, skill_id, level, target, input, now, prepared)

      {:error, reason} ->
        CastSettlement.castend_failure(game_state, skill_id, level, target, reason)
    end
  end

  defp complete_prepared_cast(
         game_state,
         skill_id,
         level,
         target,
         input,
         now,
         %CastContext{} = context
       ) do
    definition =
      CastPacing.delay_definition(game_state, context.module, target, level, context.definition)

    apply_act_delay = Enum.at(definition.after_cast_delay, level - 1) not in [nil, 0]
    after_cast_delay = CastPacing.resolved_after_cast_delay(game_state, definition, level)
    definition = CastPacing.put_resolved_combo_delay(definition, level, after_cast_delay)

    CastSettlement.complete_resolved_cast(
      game_state,
      context.module,
      target,
      level,
      definition,
      %{
        adapter: context.adapter,
        prepared_cost: context.cost,
        skill_id: skill_id,
        level: level,
        apply_act_delay: apply_act_delay,
        after_cast_delay: after_cast_delay,
        now: now,
        input: input
      }
    )
  end

  @doc """
  Settles a deferred cast: spends what its cast end left to settle (items, ammo,
  Ki Translation's sphere) up to what the caster holds now, then arms the
  cooldown and act delay. The primary requirements were already paid when the
  cast ended.
  """
  @spec settle_deferred(PlayerState.t(), Deferred.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def settle_deferred(game_state, %Deferred{} = deferred) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- CastConditions.fetch_definition(deferred.skill_id) do
      prepared =
        Caster.Player.prepare_settlement(
          game_state,
          __MODULE__,
          definition,
          deferred.cost,
          deferred.zeny,
          deferred.level
        )

      {:ok,
       game_state
       |> Caster.Player.commit(prepared)
       |> CastPacing.put_cooldown(deferred.skill_id, definition, deferred.level, now)
       |> CastPacing.put_act_delay(definition, deferred.level, now)}
    end
  end

  @doc """
  Runs a status-driven auto-cast for any caster registered with `Caster.for/1`.

  Deliberately not `complete_cast/4`. The proc jumps straight to skill execution
  and skips ordinary cast requirements: no cast time, learned/range/cooldown or
  act-delay check, catalyst/ammo/zeny validation or consumption, and no cooldown
  written. It charges only SP, fixed at 2/3 of the skill's raw database cost, so
  caster `sp_cost_rate` sources deliberately do not apply. Players also receive
  the skill's aftercast delay; casters without player act-delay state do not.

  The SP is charged before the effect runs and stays spent whatever the effect
  does, and the aftercast delay is armed either way: an effect that fails
  returns `{:error, reason, charged}` for the owner to commit. Insufficient SP
  returns `{:error, :insufficient_sp}` and runs nothing, which the caller drops
  silently: a failed SP charge simply skips the proc, with no message to the
  player.

  A ground bolt (Thunderstorm, Heaven's Drive) is cast at the victim's cell,
  as the reference's cast-type switch sends it to the ground cast end.

  The skill runs as an `:auto` invocation without the caster's autocast flag:
  a status proc is automatic but never sets the runtime exemption an equipment
  proc does, so it only keeps a flag already set by an enclosing invocation.
  """
  @spec auto_cast(Active.caster(), integer(), pos_integer(), Active.target()) ::
          {:ok, Active.caster()}
          | {:failed, Active.caster(), atom()}
          | {:error, atom()}
          | {:error, atom(), Active.caster()}
  def auto_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)
    adapter = Caster.for(game_state)

    with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_max_level(definition, level),
         {:ok, module} <- CastConditions.fetch_active_module(definition),
         {:ok, resolved} <- resolve_auto_cast_target(definition, target),
         cost = auto_cast_sp_cost(definition, level),
         :ok <- CastConditions.check_sp(adapter, game_state, cost) do
      charged = adapter.deduct_sp(game_state, cost)

      case CastExecution.run_unconditional(
             module,
             charged,
             resolved,
             level,
             definition,
             :auto,
             false
           ) do
        {:ok, game_state} ->
          {:ok, CastPacing.put_act_delay(game_state, definition, level, now, 0)}

        {:failed, game_state, reason} ->
          {:failed, CastPacing.put_act_delay(game_state, definition, level, now, 0), reason}

        {:skipped, game_state, _reason} ->
          {:ok, CastPacing.put_act_delay(game_state, definition, level, now, 0)}

        {:error, reason} ->
          {:error, reason, CastPacing.put_act_delay(charged, definition, level, now, 0)}

        other ->
          other
      end
    end
  end

  def auto_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  # A status-driven proc charges two thirds of the skill's SP cost, in C integer
  # division.
  @spec auto_cast_sp_cost(Definition.t(), pos_integer()) :: non_neg_integer()
  defp auto_cast_sp_cost(definition, level) do
    div(Enum.at(definition.sp_cost, level - 1) * 2, 3)
  end

  defp resolve_auto_cast_target(%{target_type: :ground}, {:unit, target_id}) do
    case Combat.resolve_target_position(target_id) do
      {:ok, _type, {x, y, _map}} -> {:ok, {:ground, x, y}}
      {:error, _reason} = error -> error
    end
  end

  defp resolve_auto_cast_target(_definition, target), do: {:ok, target}

  @doc """
  Checks whether an equipment proc may fire `skill_id` for the wearer.

  The proc's usability check: the skill must exist and pass the map and
  cooldown restrictions of a skill use (`UseRestrictions.check/4`, given the
  wearer's pending item skill), whose refusal carries its reply as
  `{:not_ok, reply}`. The learned level, range, resources and the
  attack-motion gate are not checked. The wearer's autocast flag is set for the
  check and reset afterwards, which also clears a flag an enclosing invocation
  had set. Nothing is charged or cast.
  """
  @spec check_proc_usable(PlayerState.t(), integer(), UseRestrictions.item_skill() | nil) ::
          :ok | {:error, :unknown_skill | {:not_ok, UseRestrictions.reply()}}
  def check_proc_usable(%PlayerState{} = game_state, skill_id, pending_item) do
    ref = CastConditions.caster_ref(game_state)
    Origin.set_autocast_flag(ref, true)

    try do
      with {:ok, _definition} <- CastConditions.fetch_definition(skill_id) do
        now = System.monotonic_time(:millisecond)

        case UseRestrictions.check(game_state, skill_id, pending_item, now) do
          :ok -> :ok
          {:refuse, reply} -> {:error, {:not_ok, reply}}
        end
      end
    after
      Origin.set_autocast_flag(ref, false)
    end
  end

  @doc """
  Runs an equipment-granted proc cast: the entry the autocast bonuses use.

  Deliberately neither `complete_cast/4` nor `auto_cast/4`. The caller runs
  `check_proc_usable/3` first; the skill's requirement is consumed before its effect
  the way an ordinary cast's is, except that the proc's autocast flag waives
  the SP (Holy Light keeps its explicit SP); the HP, spheres and zeny it owes
  are spent up to what the wearer has, with no affordability check, no cast
  time, no learned or range check and no item consumption. A skill that
  charges itself on success (Tarot Card of Fate) still does. The proc never
  arms the skill's cooldown, only its after-cast delay.

  A ground skill whose unit may not be placed (`Skill.Unit.PlacementCheck`,
  checked as a player) returns `{:error, reason}` and runs nothing. An effect that fails after the
  requirement was spent returns `{:error, reason, charged}` so the owner
  commits the spent resources; both are dropped silently. The effect runs as an `:auto` invocation with the
  wearer's autocast flag set for exactly its execution.

  ## Options
    - `:act_delay?` - arm the after-cast delay (default `true`). On-skill procs
      arm none.
    - `:placement_skill` - the skill id whose unit placement a ground proc
      checks (default: the proc's own). An on-skill proc checks the skill whose
      use fired it.
  """
  @spec proc_cast(Active.caster(), integer(), pos_integer(), Active.target(), keyword()) ::
          {:ok, Active.caster()}
          | {:failed, Active.caster(), atom()}
          | {:error, atom()}
          | {:error, atom(), Active.caster()}
  def proc_cast(game_state, skill_id, level, target, opts \\ [])

  def proc_cast(%PlayerState{} = game_state, skill_id, level, target, opts)
      when is_integer(level) and level > 0 do
    now = if Keyword.get(opts, :act_delay?, true), do: System.monotonic_time(:millisecond)

    with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         :ok <- CastConditions.check_max_level(definition, level),
         {:ok, module} <- CastConditions.fetch_active_module(definition),
         {:ok, resolved} <- resolve_auto_cast_target(definition, target),
         :ok <- check_proc_placement(game_state, definition, resolved, opts),
         {:ok, charged} <-
           Caster.Player.charge_proc_requirement(game_state, module, resolved, definition, level) do
      case CastExecution.run_unconditional(
             module,
             charged,
             resolved,
             level,
             definition,
             :auto,
             true
           ) do
        {:ok, game_state} ->
          {:ok, proc_act_delay(game_state, definition, level, now)}

        {:failed, game_state, reason} ->
          {:failed, proc_act_delay(game_state, definition, level, now), reason}

        {:skipped, game_state, _reason} ->
          {:ok, proc_act_delay(game_state, definition, level, now)}

        {:error, reason} ->
          proc_failure(reason, game_state, charged, definition, level, now)

        {:deferred, _, _} ->
          proc_failure(:unsupported_skill, game_state, charged, definition, level, now)
      end
    end
  end

  def proc_cast(%PlayerState{}, _skill_id, _level, _target, _opts), do: {:error, :invalid_level}
  def proc_cast(_game_state, _skill_id, _level, _target, _opts), do: {:error, :unsupported_caster}

  # A ground proc checks its placement as a player before anything is spent. An
  # on-skill proc checks the skill whose use fired it rather than its own.
  defp check_proc_placement(game_state, %{target_type: :ground} = definition, target, opts) do
    with {:ok, checked} <- proc_placement_definition(definition, opts) do
      CastConditions.check_placement(game_state, checked, target, :player)
    end
  end

  defp check_proc_placement(_game_state, _definition, _target, _opts), do: :ok

  defp proc_placement_definition(definition, opts) do
    case Keyword.fetch(opts, :placement_skill) do
      {:ok, skill_id} -> CastConditions.fetch_definition(skill_id)
      :error -> {:ok, definition}
    end
  end

  # The effect ran and failed: the requirement stays spent and the after-cast
  # delay still arms, so the owner commits the changed state silently.
  defp proc_failure(reason, game_state, charged, definition, level, now) do
    case proc_act_delay(charged, definition, level, now) do
      ^game_state -> {:error, reason}
      changed -> {:error, reason, changed}
    end
  end

  # `now` is nil for a proc that arms no after-cast delay.
  defp proc_act_delay(game_state, _definition, _level, nil), do: game_state

  defp proc_act_delay(game_state, definition, level, now),
    do: CastPacing.put_act_delay(game_state, definition, level, now, 0)

  @doc "Begins a client-selected item skill; see `Skill.ItemCast.begin_item_cast/4`."
  defdelegate begin_item_cast(caster, skill_id, level, target), to: ItemCast

  @doc "Begins a staged item cast; see `Skill.ItemCast.begin_item_cast/5`."
  defdelegate begin_item_cast(caster, skill_id, level, target, on_ready), to: ItemCast

  @doc "Begins an item cast with requirement retention; see `Skill.ItemCast.begin_item_cast/6`."
  defdelegate begin_item_cast(caster, skill_id, level, target, on_ready, keep?), to: ItemCast

  @doc "Completes an item skill; see `Skill.ItemCast.complete_item_cast/4`."
  defdelegate complete_item_cast(caster, skill_id, level, target), to: ItemCast

  @doc "Completes an item cast with requirement retention; see `Skill.ItemCast.complete_item_cast/5`."
  defdelegate complete_item_cast(caster, skill_id, level, target, keep?), to: ItemCast

  @doc "Runs an item-triggered cast, the restricted entry `itemskill` uses; see `Skill.ItemCast.item_cast/4`."
  defdelegate item_cast(game_state, skill_id, level, target), to: ItemCast

  @doc """
  Runs a scripted NPC support cast without player-cast costs or pacing.

  This path skips learned level, SP/HP/zeny, catalysts, ammo, weight, cooldown,
  cast time, range, and the act-delay gate. It arms neither cooldown nor act
  delay because the command has no cooldown and its synthetic caster is one-shot.
  """
  @spec npc_cast(SkillCaster.t(), integer() | atom(), pos_integer(), {:unit, integer()}) ::
          {:ok, SkillCaster.t()} | {:error, atom()}
  def npc_cast(%SkillCaster{} = caster, skill, level, {:unit, target_id})
      when is_integer(level) and level > 0 and is_integer(target_id) do
    with {:ok, definition} <- CastConditions.fetch_definition(skill),
         level = CastConditions.clamp_level(level, definition),
         :ok <- CastConditions.check_castable(definition),
         :ok <- CastConditions.check_support_target(definition),
         :ok <- CastConditions.check_npc_facilities(definition),
         {:ok, module} <- CastConditions.fetch_active_module(definition),
         :ok <- module.validate(caster, {:unit, target_id}, level, definition) do
      invoke_npc_cast(module, caster, {:unit, target_id}, level, definition)
    end
  end

  def npc_cast(%SkillCaster{}, _skill, _level, _target), do: {:error, :invalid_level}
  def npc_cast(_caster, _skill, _level, _target), do: {:error, :unsupported_caster}

  defp invoke_npc_cast(module, caster, target, level, definition) do
    result =
      Origin.with_skill(definition.name, nil, fn ->
        module.cast(caster, target, level, definition)
      end)

    case result do
      {:ok, _caster} -> {:ok, caster}
      {:ok, _caster, :no_consume} -> {:ok, caster}
      {:error, _reason} = error -> error
      _other -> {:error, :unsupported_skill}
    end
  end

  @doc "Resolves the committed after-cast duration; see `Skill.CastPacing.resolved_after_cast_delay/3`."
  defdelegate resolved_after_cast_delay(game_state, definition, level), to: CastPacing

  @doc "The cast-range of a skill for a caster and level; see `Skill.CastConditions.effective_range/3`."
  defdelegate effective_range(definition, game_state, level), to: CastConditions

  defdelegate effective_item_cost(game_state, definition), to: Caster.Player

  @spec schedule(
          CastTime.result(),
          Active.caster(),
          integer(),
          pos_integer(),
          Active.target(),
          CastContext.t(),
          keyword()
        ) ::
          {:instant, Active.caster()}
          | {:instant, Active.caster(), [Active.effect()]}
          | {:deferred, Active.caster(), term()}
          | {:casting, Active.caster(), cast_info()}
          | {:failed, Active.caster(), atom()}
          | {:failed, Active.caster(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, Active.caster(), atom()}
          | {:castend_failed, Active.caster(), atom()}
          | {:error, atom()}
          | {:error, atom(), Active.caster()}
  defp schedule(%{total: 0}, game_state, skill_id, level, target, prepared, _opts) do
    CastExecution.notify_cast_targeted(game_state, prepared.definition, target, false)
    now = System.monotonic_time(:millisecond)
    started = CastExecution.cast_start(game_state, prepared.adapter, skill_id)

    case complete_instant_cast(started, skill_id, level, target, now, prepared) do
      {:error, reason} when started != game_state -> {:error, reason, started}
      outcome -> outcome
    end
  end

  defp schedule(
         %{fixed: fixed, total: total},
         game_state,
         skill_id,
         level,
         target,
         prepared,
         opts
       ) do
    CastExecution.notify_cast_targeted(game_state, prepared.definition, target, true)

    info = %{
      skill_id: skill_id,
      level: level,
      target: target,
      element: prepared.definition.element,
      fixed: fixed,
      total: total,
      origin: Keyword.get(opts, :origin, :normal)
    }

    {:casting, game_state, info}
  end

  # An instant cast reaches its cast end once its cast-start effects ran: the
  # unit placement, the cast-end target, then the cast-end requirements.
  defp complete_instant_cast(game_state, skill_id, level, target, now, prepared) do
    with :ok <- check_instant_castend(game_state, target, prepared),
         :ok <- CastConditions.check_placement(game_state, prepared.definition, target),
         :ok <- CastConditions.check_castend_target(game_state, target, prepared.definition),
         {:ok, prepared} <- CastValidation.prepare_castend(prepared, game_state) do
      case complete_prepared_cast(
             game_state,
             skill_id,
             level,
             target,
             :without_input,
             now,
             prepared
           ) do
        {:ok, game_state} -> instant_result(game_state, prepared.cost)
        {:local_effects, game_state, effects} -> {:instant, game_state, effects}
        {:deferred, game_state, descriptor} -> {:deferred, game_state, descriptor}
        {:failed, game_state, reason} -> {:failed, game_state, reason}
        {:failed, game_state, reason, variant} -> {:failed, game_state, reason, variant}
        {:skipped, game_state, reason} -> {:skipped, game_state, reason}
        {:castend_failed, game_state, reason} -> {:castend_failed, game_state, reason}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} ->
        CastSettlement.castend_failure(game_state, skill_id, level, target, reason)
    end
  end

  # A player's instant cast reaches the cast-end checks its cast begin left out;
  # other casters checked them when the cast began.
  defp check_instant_castend(%PlayerState{} = caster, target, %CastContext{} = prepared),
    do:
      CastValidation.check_player_castend(
        caster,
        target,
        prepared.definition,
        %{prepared | caster: caster}
      )

  defp check_instant_castend(_caster, _target, _prepared), do: :ok

  defp instant_result(caster, %{instant_effects: effects}), do: {:instant, caster, effects}
  defp instant_result(caster, _prepared_cost), do: {:instant, caster}
end
