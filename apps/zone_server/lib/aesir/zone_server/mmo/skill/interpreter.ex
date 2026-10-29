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
  """
  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SkillRange
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobSkill.Event, as: MobSkillEvent
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.AfterCastDelay
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.CastContext
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheck
  alias Aesir.ZoneServer.Mmo.Skill.UseRestrictions
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  # Vulture's Eye: the passive whose learned level widens a `vulture_range` skill.
  @vulture_skill_id 44
  @fire_wall_skill_id 18
  # Monk and Champion combo skills: their resolved delay sizes the window they open.
  @combo_delay_skill_ids [272, 273, 371, 372]
  # How much an ordinary or item cast may shorten an act delay already armed.
  @act_delay_slack 100

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
  player's learned-rank check, for a cast a script starts (rAthena
  `unitskilluseid`); `origin: :script` tags the resulting cast info so its cast
  end skips the learned-rank re-check too.
  """
  @spec begin_cast(Active.caster(), integer(), pos_integer(), Active.target(), keyword()) ::
          term()
  def begin_cast(game_state, skill_id, level, target, opts)
      when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         {:ok, adapter} <- lifecycle_adapter(game_state) do
      begin_real_attempt(game_state, skill_id, level, target, definition, adapter, now, opts)
    end
  end

  def begin_cast(_game_state, _skill_id, _level, _target, _opts), do: {:error, :invalid_level}

  defp begin_real_attempt(caster, skill_id, level, target, definition, adapter, now, opts) do
    inputs = :erlang.apply(adapter, :cast_stats, [caster, skill_id])
    early = CastTime.early(definition, level, inputs)
    refreshed = Caster.apply_cast_reactions(caster, early.reactions)

    case validate_cast(refreshed, skill_id, level, target, now, :cast_begin, opts) do
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
      cast_timing_definition(caster, context.module, target, level, context.definition)

    time =
      if timing_definition.cast_time == context.definition.cast_time,
        do: early.time,
        else: Enum.at(timing_definition.cast_time, level - 1, 0)

    time = scale_cast_time(context.module, caster, target, level, time)

    %{timing: timing, reactions: reactions} =
      CastTime.late(timing_definition, level, context.stats, time)

    refreshed =
      caster
      |> Caster.apply_cast_reactions(reactions)
      |> stop_attack_at_cast_start(Keyword.get(opts, :attack_reach, false))

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

  # Lets a skill override its per-level cast-time table for this cast (Asura is
  # instant as a combo follow-up). Skills without the callback take the
  # definition unchanged, so their timing is byte-identical to the default path.
  @spec cast_timing_definition(
          Active.caster(),
          module(),
          Active.target(),
          pos_integer(),
          Definition.t()
        ) :: Definition.t()
  defp cast_timing_definition(game_state, module, target, level, definition) do
    if function_exported?(module, :dynamic_cast_time, 4) do
      %{cast_time: cast_time, fixed_cast_time: fixed_cast_time} =
        module.dynamic_cast_time(game_state, target, level, definition)

      %{
        definition
        | cast_time: List.replace_at(definition.cast_time, level - 1, cast_time),
          fixed_cast_time: List.replace_at(definition.fixed_cast_time, level - 1, fixed_cast_time)
      }
    else
      definition
    end
  end

  @doc """
  Validates every ordinary cast requirement without mutating the caster.
  """
  @spec preflight_cast(Caster.state(), integer(), pos_integer(), Active.target()) ::
          :ok | {:error, atom()}
  def preflight_cast(caster, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    case validate_cast(caster, skill_id, level, target, now) do
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
    case validate_player_cast(caster, skill_id, level, target, :cast_begin, opts) do
      {:ok, _context} -> :in_range
      {:error, :step_action} -> {:step, spend_early_reactions(caster, skill_id, level)}
      {:error, reason} -> {:error, reason, spend_early_reactions(caster, skill_id, level)}
    end
  end

  defp spend_early_reactions(caster, skill_id, level) do
    case fetch_definition(skill_id) do
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
    with {:ok, definition} <- fetch_definition(skill_id),
         {:ok, _module} <- fetch_active_module(definition) do
      context = CastContext.build(caster, definition, level, target, :begin)
      match?({:ok, _context}, castbegin(context, true))
    else
      _missing -> false
    end
  end

  @doc "Validates catalog identity and learned rank without mutable cast checks."
  @spec preflight_skill(Caster.state(), integer(), pos_integer()) :: :ok | {:error, atom()}
  def preflight_skill(caster, skill_id, level) when is_integer(level) and level > 0 do
    with {:ok, adapter} <- lifecycle_adapter(caster),
         {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition) do
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

    case validate_encore_replay(game_state, memory, target, now) do
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
           validate_encore_replay(game_state, memory, target, now) do
      definition = cast_timing_definition(game_state, module, target, level, definition)

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

    with {:ok, definition} <- fetch_definition(skill_id) do
      early = CastTime.early(definition, level, Caster.Player.cast_stats(caster, skill_id))
      caster = Caster.apply_cast_reactions(caster, early.reactions)
      prepare_encore_attempt(caster, memory, target, definition, early, now)
    end
  end

  defp prepare_encore_attempt(caster, memory, target, definition, early, now) do
    with {:ok, prepared} <- validate_encore_replay(caster, memory, target, now),
         {:ok, begun} <-
           begin_attempt(prepared.module, caster, target, prepared.level, prepared.definition),
         {:ok, _cost} <- encore_prepared_cost(begun, prepared, target, :begin) do
      finish_encore_timing(begun, memory, target, definition, early)
    else
      {:error, reason} ->
        if early.reactions == [],
          do: {:error, reason},
          else: {:error, reason, caster}

      # A performance has no damage cast and no cast-end requirement, so the
      # paid refusals do not reach it; pass any other outcome through.
      other ->
        other
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
      caster = cast_start(caster, Caster.Player, skill_id)

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
           validate_encore_replay(game_state, memory, target, now),
         :ok <- check_completion_caster(game_state, definition, false),
         {:ok, cost} <- encore_prepared_cost(game_state, prepared, target, :completion) do
      complete_resolved_cast(
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
          after_cast_delay: resolved_after_cast_delay(game_state, definition, level),
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
  Completes a cast a script started (rAthena `unitskilluseid`): the ordinary
  cast end, without the player cast's learned-rank re-check, because the script
  is the skill's permission. Every other cast-end condition still applies.
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
          validate_completion(game_state, skill_id, level, target, opts)

        {:with_input, _value} ->
          with {:ok, context} <-
                 validate_cast(game_state, skill_id, level, target, now, :cast_end),
               do: prepare_castend(context, game_state)
      end

    case validation do
      {:ok, prepared} ->
        game_state = begin_input_cast(game_state, input)
        complete_prepared_cast(game_state, skill_id, level, target, input, now, prepared)

      {:error, reason} ->
        castend_failure(game_state, skill_id, level, target, reason)
    end
  end

  # A cast end refused by a cast-end check runs the skill's own failure
  # reaction when it has one (`Active.castend_failed/4`); otherwise the refusal
  # stays silent and spends nothing.
  defp castend_failure(%PlayerState{} = game_state, skill_id, level, target, reason) do
    with {:ok, definition} <- fetch_definition(skill_id),
         {:ok, module} <- fetch_active_module(definition),
         true <- function_exported?(module, :castend_failed, 4),
         {:ok, failed} <- module.castend_failed(game_state, target, level, definition) do
      {:castend_failed, failed, reason}
    else
      _none -> {:error, reason}
    end
  end

  defp castend_failure(_game_state, _skill_id, _level, _target, reason), do: {:error, reason}

  defp complete_prepared_cast(
         game_state,
         skill_id,
         level,
         target,
         input,
         now,
         %CastContext{} = context
       ) do
    definition = delay_definition(game_state, context.module, target, level, context.definition)
    apply_act_delay = Enum.at(definition.after_cast_delay, level - 1) not in [nil, 0]
    after_cast_delay = resolved_after_cast_delay(game_state, definition, level)
    definition = put_resolved_combo_delay(definition, level, after_cast_delay)

    complete_resolved_cast(
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

  # The optional `dynamic_after_cast_delay/4` replaces this level's table entry
  # on a cast-local definition, so the ordinary delay pipeline still applies.
  defp delay_definition(game_state, module, target, level, definition) do
    if function_exported?(module, :dynamic_after_cast_delay, 4) do
      base = module.dynamic_after_cast_delay(game_state, target, level, definition)
      table = pad_levels(definition.after_cast_delay, level)
      %{definition | after_cast_delay: List.replace_at(table, level - 1, base)}
    else
      definition
    end
  end

  defp pad_levels(table, level) when length(table) >= level, do: table
  defp pad_levels(table, level), do: table ++ List.duplicate(0, level - length(table))

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

    with {:ok, definition} <- fetch_definition(deferred.skill_id) do
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
       |> put_cooldown(deferred.skill_id, definition, deferred.level, now)
       |> put_act_delay(definition, deferred.level, now)}
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
  mirroring rAthena's `skill_get_casttype` switch to `skill_castend_pos2`.

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

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         {:ok, module} <- fetch_active_module(definition),
         {:ok, resolved} <- resolve_auto_cast_target(definition, target),
         cost = auto_cast_sp_cost(definition, level),
         :ok <- check_sp(adapter, game_state, cost) do
      charged = adapter.deduct_sp(game_state, cost)

      case run_unconditional(module, charged, resolved, level, definition, :auto, false) do
        {:ok, game_state} ->
          {:ok, put_act_delay(game_state, definition, level, now, 0)}

        {:failed, game_state, reason} ->
          {:failed, put_act_delay(game_state, definition, level, now, 0), reason}

        {:skipped, game_state, _reason} ->
          {:ok, put_act_delay(game_state, definition, level, now, 0)}

        {:error, reason} ->
          {:error, reason, put_act_delay(charged, definition, level, now, 0)}

        other ->
          other
      end
    end
  end

  def auto_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

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
    ref = caster_ref(game_state)
    Origin.set_autocast_flag(ref, true)

    try do
      with {:ok, _definition} <- fetch_definition(skill_id) do
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

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         {:ok, module} <- fetch_active_module(definition),
         {:ok, resolved} <- resolve_auto_cast_target(definition, target),
         :ok <- check_proc_placement(game_state, definition, resolved, opts),
         {:ok, charged} <-
           Caster.Player.charge_proc_requirement(game_state, module, resolved, definition, level) do
      case run_unconditional(module, charged, resolved, level, definition, :auto, true) do
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
      check_placement(game_state, checked, target, :player)
    end
  end

  defp check_proc_placement(_game_state, _definition, _target, _opts), do: :ok

  defp proc_placement_definition(definition, opts) do
    case Keyword.fetch(opts, :placement_skill) do
      {:ok, skill_id} -> fetch_definition(skill_id)
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
    do: put_act_delay(game_state, definition, level, now, 0)

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
          | {:casting, PlayerState.t(), cast_info()}
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
        ) ::
          {:instant, PlayerState.t()}
          | {:instant, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:casting, PlayerState.t(), cast_info()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
          | {:error, atom(), PlayerState.t(), :before_start | :after_start}
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
        ) ::
          {:instant, PlayerState.t()}
          | {:instant, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:casting, PlayerState.t(), cast_info()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
          | {:error, atom(), PlayerState.t(), :before_start | :after_start}
  def begin_item_cast(%PlayerState{} = caster, skill_id, level, target, on_ready, keep?)
      when is_integer(level) and level > 0 and is_function(on_ready, 1) and is_boolean(keep?) do
    with {:ok, definition} <- fetch_definition(skill_id) do
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

    case check_player_use(caster, definition.id, level, target, :cast_begin, opts) do
      {:ok, context} ->
        case item_castbegin(context, on_ready, keep?) do
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
    case check_player_after_begin(context.caster, prepared, :cast_begin, opts) do
      {:ok, ready} -> finish_item_attempt(ready, target, early, keep?)
      {:error, reason} -> {:error, reason, prepared.caster, :after_start}
    end
  end

  defp finish_item_attempt(%CastContext{} = context, target, early, keep?) do
    definition = context.definition
    skill_id = definition.id
    caster = stop_attack_at_cast_start(context.caster, false)

    %{timing: timing, reactions: reactions} =
      CastTime.late(
        definition,
        context.level,
        Caster.Player.cast_stats(caster, skill_id),
        early.time
      )

    refreshed = Caster.apply_cast_reactions(caster, reactions)
    notify_cast_targeted(refreshed, definition, target, timing.total > 0)

    if timing.total == 0 do
      started = cast_start(refreshed, Caster.Player, skill_id)

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
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
  def complete_item_cast(caster, skill_id, level, target),
    do: complete_item_cast(caster, skill_id, level, target, false)

  @doc "Completes an item cast, charging the skill's own requirements when retained."
  @spec complete_item_cast(PlayerState.t(), integer(), pos_integer(), Active.target(), boolean()) ::
          {:ok, PlayerState.t()}
          | {:local_effects, PlayerState.t(), [Active.effect()]}
          | {:deferred, PlayerState.t(), term()}
          | {:failed, PlayerState.t(), atom()}
          | {:failed, PlayerState.t(), atom(), :type1_only | :requirements_only | :after_effect}
          | {:skipped, PlayerState.t(), atom()}
          | {:castend_failed, PlayerState.t(), atom()}
          | {:error, atom()}
  def complete_item_cast(%PlayerState{} = caster, skill_id, level, target, true) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_placement(caster, definition, target),
         {:ok, module} <- validate_item_cast(caster, target, level, definition),
         :ok <- check_castend_target(caster, target, definition),
         {:ok, cost} <- Caster.Player.castend_cost(caster, module, target, definition, level) do
      complete_resolved_cast(caster, module, target, level, definition, %{
        adapter: Caster.Player,
        prepared_cost: cost,
        skill_id: skill_id,
        level: level,
        apply_act_delay: Enum.at(definition.after_cast_delay, level - 1, 0) > 0,
        after_cast_delay: resolved_after_cast_delay(caster, definition, level),
        now: now,
        input: :without_input,
        origin: :item
      })
      |> retain_menu_requirements(true)
    end
  end

  def complete_item_cast(%PlayerState{} = caster, skill_id, level, target, false) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_placement(caster, definition, target),
         {:ok, module} <- validate_item_cast(caster, target, level, definition),
         :ok <- check_castend_target(caster, target, definition) do
      cond do
        dead_target_skip?(definition, target) ->
          {:ok, pace_item_cast(caster, module, skill_id, definition, level, now)}
          |> retain_menu_requirements(false)

        walk_path_blocked?(definition, caster, target) ->
          {:error, :projectile_blocked}

        true ->
          run_item_effect(module, caster, target, level, definition, now)
      end
    end
  end

  defp run_item_effect(module, caster, target, level, definition, now) do
    skill_id = definition.id

    case run_unconditional(module, caster, target, level, definition, :item, false) do
      {:ok, caster} ->
        {:ok, pace_item_cast(caster, module, skill_id, definition, level, now)}
        |> retain_menu_requirements(false)

      {:failed, caster, reason} ->
        {:failed, pace_item_cast(caster, module, skill_id, definition, level, now), reason}

      {:skipped, caster, _reason} ->
        {:ok, pace_item_cast(caster, module, skill_id, definition, level, now)}
        |> retain_menu_requirements(false)

      error ->
        error
    end
  end

  defp pace_item_cast(caster, module, skill_id, definition, level, now) do
    caster
    |> put_cooldown(skill_id, definition, level, now)
    |> rearm_cooldowns(module, level, definition, now)
    |> put_act_delay(definition, level, now)
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
    with :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- check_target(caster, target, definition),
         :ok <- check_cast_end(caster, target, definition, true) do
      {:ok, module}
    end
  end

  defp validate_item_range(caster, module, target, level, definition) do
    with :ok <- check_range(caster, target, definition, level) do
      module.validate(caster, target, level, definition)
    end
  end

  @doc """
  Runs an item-triggered cast: the restricted entry `itemskill` uses.

  This entry point is player-only because item scripts execute against a player
  inventory; an item-triggered cast has no meaning for a non-player caster.

  Deliberately not `complete_cast/4`. A skill cast by consuming an item is by
  construction not one the player learned, and the item itself is the cost: the
  cast is flagged so both the cast-begin and cast-end condition checks return
  early, bypassing every requirement - learned level, SP, HP, zeny, catalysts,
  ammo, weight and the act-delay gate - and charging none of them.

  What it keeps is what makes the cast well-formed rather than affordable: the
  skill must exist, be castable at that level, have a behavior module, and the
  target must be valid and in range; the behavior's own `validate/4` still runs.
  The skill's cooldown and aftercast delay are armed on success, so an item cast
  cannot be spammed past the skill's own pacing.
  """
  @spec item_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom()} | {:error, atom()}
  def item_cast(%PlayerState{} = game_state, skill_id, level, target)
      when is_integer(level) and level > 0 do
    case begin_item_cast(game_state, skill_id, level, target) do
      {:instant, caster} -> {:ok, caster}
      {:casting, caster, _info} -> complete_item_cast(caster, skill_id, level, target)
      error -> error
    end
  end

  def item_cast(%PlayerState{}, _skill_id, _level, _target), do: {:error, :invalid_level}
  def item_cast(_game_state, _skill_id, _level, _target), do: {:error, :unsupported_caster}

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
    with {:ok, definition} <- fetch_definition(skill),
         level = clamp_level(level, definition),
         :ok <- check_castable(definition),
         :ok <- check_support_target(definition),
         :ok <- check_npc_facilities(definition),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- module.validate(caster, {:unit, target_id}, level, definition) do
      invoke_npc_cast(module, caster, {:unit, target_id}, level, definition)
    end
  end

  def npc_cast(%SkillCaster{}, _skill, _level, _target), do: {:error, :invalid_level}
  def npc_cast(_caster, _skill, _level, _target), do: {:error, :unsupported_caster}

  @doc "Resolves the committed after-cast duration (`Skill.AfterCastDelay`)."
  @spec resolved_after_cast_delay(PlayerState.t() | map(), Definition.t(), pos_integer()) ::
          non_neg_integer()
  def resolved_after_cast_delay(game_state, definition, level) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil -> 0
      0 -> 0
      _base -> AfterCastDelay.resolve(game_state, definition, level)
    end
  end

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

  # Runs a behavior without `run_cast/5`'s catalyst consumption, shared by the
  # auto-cast and item-cast entry points: both are free of the skill's declared
  # requirements by construction, not by their skills happening to declare none
  # today. `autocast_flag?` is set only by the equipment proc entry.
  defp run_unconditional(module, game_state, target, level, definition, origin, autocast_flag?) do
    scope = %{invocation: origin, autocast_flag?: autocast_flag?}
    adapter = Caster.for(game_state)

    {result, attacked?} =
      Origin.collect_skill_attacks(fn ->
        invoke_cast(module, game_state, target, level, definition, scope)
      end)

    case settle_skill_attack(result, game_state, adapter, attacked?) do
      {:ok, game_state} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, game_state}

      {:ok, game_state, :no_consume} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, game_state}

      {:deferred, game_state, descriptor} ->
        {:deferred, game_state, descriptor}

      {:failed, _game_state, _reason} = failed ->
        failed

      {:failed, game_state, reason, :spare_items} ->
        {:failed, game_state, reason}

      {:failed, game_state, reason, :after_effect} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:failed, game_state, reason}

      {:skipped, _game_state, _reason} = skipped ->
        skipped

      {:error, _reason} = error ->
        error
    end
  end

  defp complete_resolved_cast(
         game_state,
         module,
         target,
         level,
         definition,
         %{
           adapter: adapter,
           prepared_cost: prepared_cost,
           skill_id: skill_id,
           level: level,
           input: input
         } = opts
       ) do
    origin = Map.get(opts, :origin, adapter.cast_origin(game_state))
    unpaid = game_state
    {game_state, prepared_cost} = adapter.commit_primary(game_state, prepared_cost)

    context = %{
      unpaid: unpaid,
      game_state: game_state,
      module: module,
      skill_id: skill_id,
      level: level,
      target: target,
      definition: definition,
      prepared_cost: prepared_cost,
      opts: opts,
      player?: is_struct(unpaid, PlayerState)
    }

    cond do
      # The reference path-searches the cast line for every damage cast before
      # its implementation, ahead of its dead-target early return.
      walk_path_blocked?(definition, game_state, target) ->
        settle_refusal(:projectile_blocked, context)

      dead_target_skip?(definition, target) ->
        {:skipped, settle_skipped(context), :target_dead}

      true ->
        result = run_cast(module, game_state, target, level, definition, origin, input, adapter)
        resolve_effect(result, context)
    end
  end

  defp resolve_effect(result, context) do
    %{
      module: module,
      skill_id: skill_id,
      level: level,
      target: target,
      definition: definition,
      prepared_cost: prepared_cost,
      opts: opts
    } = context

    case result do
      {:deferred, game_state, descriptor} ->
        deferred_result(game_state, descriptor, prepared_cost, skill_id, level, target)

      {result, game_state, effects, consume_catalysts?}
      when result in [:ok, :local_effects] and is_list(effects) ->
        prepared_cost = Map.put(prepared_cost, :consume_catalysts?, consume_catalysts?)
        settled = settle_cast(game_state, module, level, definition, prepared_cost, opts)

        if result == :local_effects,
          do: {:local_effects, settled, effects},
          else: {:ok, settled}

      {:failed, _game_state, _reason} = failed ->
        settle_failed(failed, context)

      {:failed, _game_state, _reason, _variant} = failed ->
        settle_failed(failed, context)

      # The reference ends this use without its effect and without a failure
      # message: a dead target, or an implementation whose early return skips
      # the cast-end tail. The requirement stays paid and its items are spared.
      {:skipped, game_state, reason} ->
        {:skipped, settle_skipped(%{context | game_state: game_state}), reason}

      # An effect refusal is a cast-end check made late: nothing is paid unless
      # the skill reacts to a refused cast end, the target is a dead player, the
      # target is the Emperium, or the walk path blocks the skill.
      {:error, reason} ->
        settle_refusal(reason, context)
    end
  end

  # A failed effect keeps its catalysts spent, except the `:spare_items` variant;
  # an `:after_effect` failure keeps its variant for the owner to show the skill.
  defp settle_failed({:failed, game_state, reason, :spare_items}, context),
    do: {:failed, settle_skipped(%{context | game_state: game_state}), reason}

  defp settle_failed({:failed, game_state, reason}, context),
    do: {:failed, settle_spent(game_state, context), reason}

  defp settle_failed({:failed, game_state, reason, :after_effect}, context),
    do: {:failed, settle_spent(game_state, context), reason, :after_effect}

  defp settle_spent(game_state, context) do
    %{module: module, level: level, definition: definition} = context
    settle_cast(game_state, module, level, definition, context.prepared_cost, context.opts)
  end

  defp announce_after_effect(:after_effect, module, caster, target, level, definition),
    do: announce_ground_cast(module, caster, target, level, definition)

  defp announce_after_effect(_variant, _module, _caster, _target, _level, _definition), do: :ok

  # The reference refuses a dead target at the top of its damage and no-damage
  # cast ends, after the requirement is paid: the use ends without its effect,
  # without its items, its cast-end tail or a failure message. Five skills may
  # run on the dead; only the two implemented here are listed.
  @cast_on_dead_skills [:all_resurrection, :pr_redemptio]

  defp dead_target_skip?(%{name: name}, _target) when name in @cast_on_dead_skills, do: false

  defp dead_target_skip?(%{target_type: type}, _target)
       when type in [:target_corpse, :target_resurrection],
       do: false

  defp dead_target_skip?(_definition, :self), do: false

  defp dead_target_skip?(_definition, target) do
    case player_target_state(target) do
      {:ok, false} -> true
      _alive_other_or_gone -> false
    end
  end

  # The reference's OFFICIAL_WALKPATH check runs for every cast whose type is
  # not no-damage, whatever the caster's weapon reach.
  defp walk_path_blocked?(definition, caster, target) do
    Definition.cast_type(definition) == :damage and line_blocked?(caster, target)
  end

  defp line_blocked?(caster, target) do
    with {:ok, target_id} <- unit_target_id(target),
         {:ok, {tx, ty, target_map}} <- resolve_unit_position(target_id),
         true <- target_map == caster.map_name and {caster.x, caster.y} != {tx, ty} do
      not LineOfSight.clear?(caster.map_name, {caster.x, caster.y}, {tx, ty})
    else
      _other -> false
    end
  end

  defp unit_target_id({:unit, {:player, id}}), do: {:ok, id}
  defp unit_target_id({:unit, {:mob, id}}), do: {:ok, id}
  defp unit_target_id({:unit, {:homunculus, id}}), do: {:ok, id}
  defp unit_target_id({:unit, id}) when is_integer(id), do: {:ok, id}
  defp unit_target_id(_target), do: :error

  # A use the reference ends without its effect: the paid requirement and its
  # pacing stay, its items and ammo do not, the cast-end tail does not run, and
  # the caster sees no failure.
  defp settle_skipped(%{
         game_state: game_state,
         module: module,
         level: level,
         definition: definition,
         prepared_cost: prepared_cost,
         opts: opts
       }) do
    prepared_cost =
      prepared_cost
      |> Map.put(:consume_catalysts?, false)
      |> Map.put(:consume_ammo?, false)

    settle_cast(game_state, module, level, definition, prepared_cost, opts)
  end

  # Settles a refusal by the outcome the reference gives it: nothing (unpaid),
  # the requirement with its pacing (a dead player or an early return), the
  # requirement alone (a player's Emperium refusal), or the requirement and its
  # items (a player's blocked walk path; a non-player's walk refusal breaks
  # before it pays anything).
  defp settle_refusal(reason, context) do
    settle_for(failure_settlement(reason, context), reason, context)
  end

  defp settle_for(:unpaid, reason, context) do
    castend_failure(context.unpaid, context.skill_id, context.level, context.target, reason)
  end

  defp settle_for(:skipped, reason, context) do
    {:skipped, settle_skipped(context), reason}
  end

  defp settle_for(variant, reason, %{game_state: game_state} = context)
       when variant in [:type1_only, :requirements_only] do
    paid_items =
      if variant == :type1_only do
        game_state
      else
        prepared = Map.put(context.prepared_cost, :consume_ammo?, false)
        context.opts.adapter.commit(game_state, prepared)
      end

    {:failed, paid_items, reason, variant}
  end

  # Which refusals the reference pays for. Everything else keeps the current
  # unpaid contract. A dead player stays on the map, so the reference pays the
  # requirement and its implementation returns; a dead monster or homunculus is
  # already gone, so that refusal stays unpaid.
  defp failure_settlement(:target_dead, context) do
    if player_target?(context.target), do: :skipped, else: :unpaid
  end

  # The Emperium refusal is inside the reference's `if (sd)`: a player keeps the
  # requirement and sees the failure, while a homunculus' hit is nulled inside
  # the implementation and its cast settles normally.
  defp failure_settlement(reason, %{player?: true})
       when reason in [:skill_not_allowed, :approval_required],
       do: :type1_only

  defp failure_settlement(reason, %{player?: false})
       when reason in [:skill_not_allowed, :approval_required],
       do: :skipped

  defp failure_settlement(reason, %{player?: true})
       when reason in [:projectile_blocked, :path_blocked],
       do: :requirements_only

  defp failure_settlement(_reason, _context), do: :unpaid

  defp player_target?(target), do: match?({:ok, _living}, player_target_state(target))

  defp player_target_state({:unit, {:player, id}}), do: player_liveness(id)
  defp player_target_state({:unit, :player, id}), do: player_liveness(id)

  defp player_target_state({:unit, id}) do
    case TargetResolver.resolve(id) do
      {:ok, _pid, state, :player} -> {:ok, Unit.living?(state)}
      _other -> :error
    end
  end

  defp player_target_state(_target), do: :error

  defp player_liveness(id) do
    case TargetResolver.resolve(:player, id) do
      {:ok, _pid, state, :player} -> {:ok, Unit.living?(state)}
      _other -> :error
    end
  end

  defp settle_cast(
         game_state,
         module,
         level,
         definition,
         prepared_cost,
         %{adapter: adapter} = opts
       ) do
    game_state
    |> then(&adapter.commit(&1, prepared_cost))
    |> put_cooldown(adapter, opts.skill_id, definition, level, opts.now)
    |> rearm_cooldowns(module, level, definition, opts.now)
    |> put_resolved_act_delay(opts.apply_act_delay, opts.after_cast_delay, opts.now)
  end

  defp deferred_result(
         game_state,
         descriptor,
         %{cost: cost, zeny: zeny},
         skill_id,
         level,
         target
       ) do
    {:deferred, game_state,
     %Deferred{
       effect: descriptor,
       cost: cost,
       zeny: zeny,
       skill_id: skill_id,
       level: level,
       target: target
     }}
  end

  defp deferred_result(
         _game_state,
         _descriptor,
         %{deferred_error: reason},
         _skill_id,
         _level,
         _target
       ),
       do: {:error, reason}

  defp put_resolved_combo_delay(%{id: skill_id} = definition, level, delay)
       when skill_id in @combo_delay_skill_ids do
    %{
      definition
      | after_cast_delay: List.replace_at(definition.after_cast_delay, level - 1, delay)
    }
  end

  defp put_resolved_combo_delay(definition, _level, _delay), do: definition

  defp validate_cast(caster, skill_id, level, target, now, phase \\ :cast_begin, opts \\ [])

  defp validate_cast(caster, skill_id, level, target, now, phase, opts) when is_struct(caster),
    do: validate_owned_cast(caster, skill_id, level, target, now, phase, opts)

  defp validate_cast(caster, skill_id, level, target, now, phase, opts) do
    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition) do
      validate_owned_cast(caster, skill_id, level, target, now, phase, opts)
    end
  end

  defp validate_owned_cast(%PlayerState{} = caster, skill_id, level, target, _now, phase, opts),
    do: validate_player_cast(caster, skill_id, level, target, phase, opts)

  defp validate_owned_cast(caster, skill_id, level, target, now, phase, _opts) do
    with {:ok, adapter} <- lifecycle_adapter(caster),
         :ok <- :erlang.apply(adapter, :castable_state, [caster, skill_id, :begin]),
         {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_support_status(caster, definition),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_weapon(caster, definition),
         :ok <- check_learned(caster, adapter, definition, level, :begin),
         :ok <- check_target(caster, target, definition),
         :ok <- check_concealment(caster, target, definition, phase),
         :ok <- check_end_placement(caster, definition, target, phase),
         :ok <- check_range(caster, target, definition, level),
         {:ok, _module} <- fetch_active_module(definition),
         :ok <- :erlang.apply(adapter, :castable_status, [caster, skill_id]),
         context = CastContext.build(caster, definition, level, target, :begin),
         :ok <- check_context_cooldown(context, now),
         :ok <- check_context_act_delay(context, now),
         {:ok, prepared} <- validate_and_prepare(context, phase == :cast_begin),
         :ok <- check_start_placement(prepared.caster, definition, target, phase) do
      {:ok, record_spheres_old(prepared, phase)}
    end
  end

  # A player's skill use, in the order the reference checks it: the map and
  # cooldown restrictions again, the target (gone or on another map, or the
  # player themselves for a skill that may not target its user, refused
  # silently), the statuses that forbid this use (silent), the skill's own use
  # checks, the cast-begin conditions, then the range and the skill's checks
  # on a target in range. A ground cast checks the placement of its unit after
  # its cast-begin conditions. The catalog guards (level, learned rank,
  # behavior) never fail a request the client stage let through. Whether the
  # target suits the skill and the skill's own `validate/4` are cast-end
  # checks (`check_player_castend/4`); a staged input cast, validated as it
  # ends, runs them last.
  defp validate_player_cast(caster, skill_id, level, target, phase, opts) do
    with {:ok, context} <- check_player_use(caster, skill_id, level, target, phase, opts),
         {:ok, context} <- castbegin(context, phase == :cast_begin) do
      check_player_after_begin(caster, context, phase, opts)
    end
  end

  # The stages before the cast-begin conditions. An item cast has no learned
  # rank and passes the map and cooldown restrictions with its pending item.
  defp check_player_use(caster, skill_id, level, target, phase, opts) do
    adapter = Caster.Player
    item = Keyword.get(opts, :item_skill)

    with :ok <- check_player_restrictions(caster, adapter, skill_id, item),
         {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_player_learned(caster, adapter, definition, level, opts),
         {:ok, _module} <- fetch_active_module(definition),
         :ok <- check_use_target(caster, target, definition),
         :ok <- check_support_status(caster, definition),
         :ok <- check_concealment(caster, target, definition, phase),
         :ok <- check_homunculus_support(caster, target, definition),
         context = CastContext.build(caster, definition, level, target, :begin),
         :ok <- optional_check(context, :skilluse_check) do
      {:ok, context}
    end
  end

  # A script cast (rAthena `unitskilluseid`) and an item cast may use a skill the
  # player never learned; every other cast still checks the learned rank.
  defp check_player_learned(caster, adapter, definition, level, opts) do
    if Keyword.get(opts, :learned?, true),
      do: check_learned(caster, adapter, definition, level, :begin),
      else: :ok
  end

  defp check_player_restrictions(caster, adapter, skill_id, nil),
    do: :erlang.apply(adapter, :castable_state, [caster, skill_id, :begin])

  defp check_player_restrictions(caster, _adapter, skill_id, item) do
    case UseRestrictions.check(caster, skill_id, item, System.monotonic_time(:millisecond)) do
      :ok -> :ok
      {:refuse, reply} -> {:error, {:not_ok, reply}}
    end
  end

  # The stages after the cast-begin conditions: the placement a player's cast
  # checks as it starts, the one a ground cast checks as it ends, the range, the
  # skill's own check on a target in range, and the cast end a staged input
  # cast validates last.
  defp check_player_after_begin(caster, context, phase, opts) do
    definition = context.definition

    with :ok <- check_start_placement(context.caster, definition, context.target, phase),
         :ok <- check_end_placement(caster, definition, context.target, phase),
         :ok <- check_use_range(caster, context.target, definition, context.level, opts),
         :ok <- optional_check(context, :after_range_check),
         :ok <- check_input_castend(context, phase) do
      {:ok, record_spheres_old(context, phase)}
    end
  end

  defp check_input_castend(context, :cast_end),
    do: check_player_castend(context.caster, context.target, context.definition, context)

  defp check_input_castend(_context, _phase), do: :ok

  # The cast-end checks of a player's cast that its cast begin leaves out:
  # whether the target suits the skill, then the skill's own `validate/4`.
  defp check_player_castend(caster, target, definition, context) do
    with :ok <- check_target(caster, target, definition), do: validate_module(context)
  end

  # A player reaches a target when the client's circular distance is within the
  # skill's range and, beyond the adjacent cells, within sight (14 cells) with
  # no wall between them. While the player walks, a target not reached at one
  # cell less is remembered instead (`:step_action`), to be tried again as the
  # walk goes on; a use that cannot retry that way (`walk_action: false`, an
  # item cast whose item was already claimed) simply fails. A ground cell must
  # also hold a unit placement.
  # A combo used while swinging at its target (`attack_reach: true`) has the
  # attack's reach: only the walking step rule applies.
  defp check_use_range(_caster, :self, _definition, _level, _opts), do: :ok

  defp check_use_range(caster, target, definition, level, opts) do
    if self_target?(caster, target) do
      :ok
    else
      range = effective_range(definition, caster, level)

      check_reach(
        caster,
        target,
        range,
        Keyword.get(opts, :attack_reach, false),
        Keyword.get(opts, :walk_action, true)
      )
    end
  end

  defp check_reach(caster, target, range, attack_reach?, walk_action?) do
    with {:ok, cell} <- use_target_cell(target) do
      cond do
        walking?(caster) and not reaches?(caster, cell, range - 1) ->
          out_of_reach(walk_action?)

        attack_reach? ->
          :ok

        not reaches?(caster, cell, range) ->
          {:error, :out_of_range}

        true ->
          check_use_cell(caster, target)
      end
    end
  end

  defp out_of_reach(true), do: {:error, :step_action}
  defp out_of_reach(_walk_action?), do: {:error, :out_of_range}

  defp use_target_cell({:ground, x, y}), do: {:ok, {x, y}}

  defp use_target_cell({:unit, target_id}) do
    case resolve_unit_position(target_id) do
      {:ok, {x, y, _map}} -> {:ok, {x, y}}
      {:error, _reason} -> {:error, :target_not_found}
    end
  end

  defp check_use_cell(caster, {:ground, x, y}), do: check_ground_walkable(caster.map_name, x, y)
  defp check_use_cell(_caster, _target), do: :ok

  defp walking?(%PlayerState{movement_state: :moving}), do: true
  defp walking?(_caster), do: false

  @sight_cells 14

  defp reaches?(%PlayerState{map_name: map_name, x: x, y: y}, {tx, ty}, range) do
    distance = Geometry.chebyshev_distance(x, y, tx, ty)

    Geometry.client_distance(x, y, tx, ty) <= max(range, 0) and
      (distance < 2 or
         (distance <= @sight_cells and LineOfSight.clear?(map_name, {x, y}, {tx, ty})))
  end

  # The unit a player aims at must still be on the caster's map, and a skill
  # that may not target its user refuses the player themselves; all silently.
  defp check_use_target(caster, {:unit, target_id} = target, definition) do
    if self_target?(caster, target),
      do: check_self_target(caster, target, definition),
      else: check_unit_target(caster, target_id, definition)
  end

  defp check_use_target(caster, target, definition),
    do: check_self_target(caster, target, definition)

  defp check_unit_target(caster, target_id, definition) do
    with :ok <- check_unit_target_map(caster, target_id),
         do: check_self_target(caster, {:unit, target_id}, definition)
  end

  defp check_self_target(caster, target, %{no_target_self: true}) do
    if self_target?(caster, target), do: {:error, :no_target_self}, else: :ok
  end

  defp check_self_target(_caster, _target, _definition), do: :ok

  defp self_target?(_caster, :self), do: true
  defp self_target?(%PlayerState{character_id: id}, {:unit, id}), do: true
  defp self_target?(%PlayerState{character_id: id}, {:unit, {:player, id}}), do: true
  defp self_target?(_caster, _target), do: false

  defp optional_check(%CastContext{module: module} = context, callback) do
    if function_exported?(module, callback, 4),
      do:
        apply(module, callback, [
          context.caster,
          context.target,
          context.level,
          context.definition
        ]),
      else: :ok
  end

  # The cast-begin conditions of a player's cast: a chat room refuses silently,
  # then the weight limit; a toggle skill whose status is active only ends it
  # and checks nothing more; otherwise the skill's own rows (`begin_attempt/4`),
  # the recovered-weight state, the weapon, then SP, zeny and spheres.
  defp castbegin(%CastContext{caster: caster} = context, begin?) do
    with :ok <- check_chat_room(caster), do: castbegin_requirements(context, begin?)
  end

  defp castbegin_requirements(
         %CastContext{caster: caster, definition: definition} = context,
         begin?
       ) do
    with :ok <- Caster.Player.check_weight(caster) do
      if Caster.Player.toggle_off?(caster, definition),
        do: prepare_cast(context),
        else: castbegin_conditions(context, begin?)
    end
  end

  # The source's cast-begin item branch: the item is claimed after the
  # chat-room refusal and before the weight limit. A cast whose item can no
  # longer be claimed (already spent, or the wrong item in its slot) fails
  # silently; a plain item cast then passes every later condition, while
  # `keep_requirement` runs them on the claimed caster.
  defp item_castbegin(%CastContext{caster: caster} = context, on_ready, keep?) do
    with :ok <- check_chat_room(caster),
         {:ok, claimed} <- on_ready.(caster) do
      if keep?,
        do: item_keep_requirements(%{context | caster: claimed}),
        else: {:ok, %{context | caster: claimed}}
    end
  end

  defp item_keep_requirements(%CastContext{caster: caster} = context) do
    case castbegin_requirements(context, true) do
      {:ok, prepared} -> {:ok, prepared}
      {:error, reason} -> {:error, reason, caster}
    end
  end

  defp castbegin_conditions(%CastContext{definition: definition} = context, begin?) do
    with {:ok, context} <- begin_context(context, begin?),
         :ok <- Caster.Player.check_recovered_weight(context.caster, definition),
         :ok <- check_weapon(context.caster, definition) do
      prepare_cast(context)
    end
  end

  defp check_chat_room(%PlayerState{waiting_room: nil}), do: :ok
  defp check_chat_room(_caster), do: {:error, :in_chat_room}

  # The cast-begin requirement check records the sphere count a skill reads for
  # its own damage; the cast end does not record it again.
  defp record_spheres_old(
         %CastContext{caster: %PlayerState{} = caster, cost: %{cost: %Cost{spheres_old: old}}} =
           context,
         :cast_begin
       )
       when is_integer(old),
       do: %{context | caster: %{caster | spirit_spheres_old: old}}

  defp record_spheres_old(context, _phase), do: context

  defp validate_completion(caster, skill_id, level, target, opts) do
    now = System.monotonic_time(:millisecond)

    with {:ok, adapter} <- lifecycle_adapter(caster),
         :ok <- :erlang.apply(adapter, :castable_state, [caster, skill_id, :completion]),
         {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_support_status(caster, definition) do
      if :erlang.apply(adapter, :completion_revalidates_definition?, []) do
        validate_revalidated_completion(caster, level, target, now, adapter, definition, opts)
      else
        validate_player_completion(caster, level, target, now, adapter, definition, opts)
      end
    end
  end

  defp validate_revalidated_completion(caster, level, target, now, adapter, definition, opts) do
    with :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_completion_learned(caster, adapter, definition, level, opts),
         :ok <- check_target(caster, target, definition),
         :ok <- check_placement(caster, definition, target),
         :ok <- check_cast_end(caster, target, definition, false),
         :ok <- check_range(caster, target, definition, level),
         :ok <- check_castend_target(caster, target, definition),
         {:ok, _module} <- fetch_active_module(definition),
         context = CastContext.build(caster, definition, level, target, :completion),
         :ok <- check_context_cooldown(context, now) do
      validate_and_prepare(context, false)
    end
  end

  defp validate_player_completion(caster, level, target, now, adapter, definition, opts) do
    with {:ok, _module} <- fetch_active_module(definition),
         context = CastContext.build(caster, definition, level, target, :completion),
         :ok <- check_completion_learned(caster, adapter, definition, level, opts),
         :ok <- check_castend_presence(caster, target),
         :ok <- check_target(caster, target, definition),
         :ok <- check_placement(caster, definition, target),
         :ok <- check_cast_end(caster, target, definition, false),
         :ok <- check_homunculus_support(caster, target, definition),
         :ok <- check_castend_target(caster, target, definition),
         :ok <- check_context_cooldown(context, now) do
      validate_and_prepare(context, false)
    end
  end

  # A cast a script started skips the learned-rank re-check; no other cast does.
  defp check_completion_learned(caster, adapter, definition, level, opts) do
    if Keyword.get(opts, :learned?, true),
      do: :erlang.apply(adapter, :knows?, [caster, definition, level, :completion]),
      else: :ok
  end

  # A support skill reaches a homunculus only from its owner: anyone else's is
  # refused silently, when the use starts and again when a timed cast ends. A
  # unit that cannot be resolved is left to the presence checks.
  defp check_homunculus_support(
         %PlayerState{} = caster,
         {:unit, {:homunculus, _gid} = ref},
         definition
       ) do
    if Definition.support?(definition) and foreign_homunculus?(caster, ref),
      do: {:error, :target_restricted},
      else: :ok
  end

  defp check_homunculus_support(_caster, _target, _definition), do: :ok

  defp foreign_homunculus?(%PlayerState{character_id: caster_id}, ref) do
    with {:ok, caster} <- Combat.resolve_combatant(:player, caster_id),
         {:ok, homunculus} <- Combat.resolve_combatant(ref) do
      not Targeting.direct_support?(caster, homunculus)
    else
      _unresolved -> false
    end
  end

  # A player's cast end does not check the range again; a unit target gone from
  # the caster's map fails it silently.
  defp check_castend_presence(caster, {:unit, target_id} = target) do
    if self_target?(caster, target), do: :ok, else: check_unit_target_map(caster, target_id)
  end

  defp check_castend_presence(_caster, _target), do: :ok

  defp check_unit_target_map(caster, target_id) do
    case resolve_unit_position(target_id) do
      {:ok, {_x, _y, map_name}} when map_name != caster.map_name -> {:error, :different_map}
      {:ok, _position} -> :ok
      {:error, _reason} -> {:error, :target_not_found}
    end
  end

  # A cast reaching the ground cast end checks its unit placement as its own
  # kind before anything else there. Fire Wall alone also checks it, as a
  # player, when a player's cast starts, once its starting requirements pass.
  defp check_end_placement(caster, definition, target, :cast_end),
    do: check_placement(caster, definition, target)

  defp check_end_placement(_caster, _definition, _target, _phase), do: :ok

  defp check_start_placement(caster, definition, target, :cast_begin),
    do: check_begin_placement(caster, definition, target)

  defp check_start_placement(_caster, _definition, _target, _phase), do: :ok

  defp check_begin_placement(
         %PlayerState{} = caster,
         %{id: @fire_wall_skill_id} = definition,
         target
       ),
       do: check_placement(caster, definition, target, :player)

  defp check_begin_placement(_caster, _definition, _target), do: :ok

  defp check_placement(caster, definition, target),
    do: check_placement(caster, definition, target, elem(caster_ref(caster), 0))

  defp check_placement(caster, definition, target, as) do
    with true <- placement_checked?(definition),
         {:ok, cell} <- placement_cell(caster, target) do
      PlacementCheck.check(definition, caster_ref(caster), caster.map_name, cell, as)
    else
      _unchecked -> :ok
    end
  end

  defp placement_checked?(definition),
    do: definition.active_instance > 0 or definition.no_reiteration or definition.no_footset

  defp placement_cell(_caster, {:ground, x, y}), do: {:ok, {x, y}}
  defp placement_cell(%{x: x, y: y}, :self), do: {:ok, {x, y}}

  defp placement_cell(_caster, {:unit, target_id}) do
    with {:ok, {x, y, _map}} <- resolve_unit_position(target_id), do: {:ok, {x, y}}
  end

  defp placement_cell(_caster, _target), do: :error

  defp check_support_status(caster, %{target_type: target_type})
       when target_type in [:target_ally, :target_any] do
    {type, id} = caster_ref(caster)
    if StatusInterpreter.support_blocked?(type, id), do: {:error, :status_blocked}, else: :ok
  end

  defp check_support_status(_caster, _definition), do: :ok

  # Blinding Mist: attack-type skills aimed at a fog holder fail at cast end
  # three times in four, before any requirement is spent.
  # A skill completing on an invincible player it may not reach fails before
  # the fog roll and before any cost is spent.
  defp check_castend_target(caster, target, definition) do
    cond do
      Targeting.castend_refused?(caster_ref(caster), target, definition) ->
        {:error, :target_invincible}

      Targeting.fogged_out?(target, definition) ->
        {:error, :fogged_out}

      true ->
        :ok
    end
  end

  defp lifecycle_adapter(caster) do
    adapter = Caster.for(caster)

    if function_exported?(adapter, :castable_state, 3),
      do: {:ok, adapter},
      else: {:error, :unsupported_caster}
  end

  defp validate_encore_replay(game_state, %{skill_id: skill_id} = memory, target, now) do
    level = Map.get(memory, :level)

    cond do
      not Catalog.replayable?(skill_id) ->
        {:error, :skill_not_replayable}

      not (is_integer(level) and level > 0) ->
        {:error, :invalid_replay_memory}

      true ->
        with {:ok, definition} <- fetch_definition(skill_id),
             :ok <- check_max_level(definition, level),
             :ok <- check_castable(definition),
             :ok <- check_weapon(game_state, definition),
             :ok <- Caster.Player.knows?(game_state, definition, 1, :begin),
             :ok <- check_target(game_state, target, definition),
             :ok <- check_range(game_state, target, definition, level),
             {:ok, module} <- fetch_active_module(definition),
             :ok <- check_cooldown(game_state, skill_id, now),
             :ok <- module.validate(game_state, target, level, definition) do
          {:ok, %{definition: definition, module: module, skill_id: skill_id, level: level}}
        end
    end
  end

  defp validate_encore_replay(_game_state, _memory, _target, _now),
    do: {:error, :invalid_replay_memory}

  # `begin?` runs the skill's cast-begin condition after `validate/4`; its
  # caster replaces the context's so the attempt's completion can read it.
  defp validate_and_prepare(%CastContext{} = context, begin?) do
    if context.adapter.cost_before_validation?() do
      with {:ok, context} <- prepare_cast(context),
           :ok <- validate_module(context) do
        begin_context(context, begin?)
      end
    else
      with :ok <- validate_module(context),
           {:ok, context} <- begin_context(context, begin?) do
        prepare_cast(context)
      end
    end
  end

  # The module's `validate/4` carries the reference's pre-payment gates (its
  # `skill_castend_id_check` target-type and party checks and the skill's own
  # cast-end conditions), which run before the requirement is paid whatever the
  # target's state. The dead-target early return sits below them, inside the
  # implementation, so it settles the cast (`dead_target_skip?/2`) rather than
  # skipping the gates.
  defp validate_module(%CastContext{} = context) do
    context.module.validate(context.caster, context.target, context.level, context.definition)
  end

  defp begin_context(context, false), do: {:ok, context}

  defp begin_context(%CastContext{} = context, true) do
    with {:ok, caster} <-
           begin_attempt(
             context.module,
             context.caster,
             context.target,
             context.level,
             context.definition
           ),
         do: {:ok, %{context | caster: caster}}
  end

  defp begin_attempt(module, caster, target, level, definition) do
    if function_exported?(module, :begin_attempt, 4),
      do: module.begin_attempt(caster, target, level, definition),
      else: {:ok, caster}
  end

  defp prepare_cast(%CastContext{adapter: adapter} = context) do
    args = [context.caster, context.module, context.target, context.definition, context.level]

    case :erlang.apply(adapter, cost_callback(adapter, context.phase), args) do
      {:ok, prepared} -> {:ok, %{context | cost: prepared}}
      {:error, _reason} = error -> error
    end
  end

  defp cost_callback(adapter, :completion) do
    if function_exported?(adapter, :castend_cost, 5), do: :castend_cost, else: :cost
  end

  defp cost_callback(_adapter, :begin), do: :cost

  # The cast end prepares its cost again on the caster that reaches it; an
  # adapter without cast-end requirements keeps the cast-begin cost.
  defp prepare_castend(%CastContext{adapter: adapter} = context, caster) do
    if function_exported?(adapter, :castend_cost, 5),
      do: prepare_cast(%{context | caster: caster, phase: :completion}),
      else: {:ok, context}
  end

  defp check_context_cooldown(%CastContext{} = context, now) do
    adapter = context.adapter

    if adapter.cooldown_ready?(
         context.caster,
         context.definition.id,
         now,
         context.phase
       ),
       do: :ok,
       else: {:error, :on_cooldown}
  end

  defp check_context_act_delay(%CastContext{} = context, now) do
    adapter = context.adapter

    if adapter.act_ready?(context.caster, now),
      do: :ok,
      else: {:error, :act_delayed}
  end

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
    notify_cast_targeted(game_state, prepared.definition, target, false)
    now = System.monotonic_time(:millisecond)
    started = cast_start(game_state, prepared.adapter, skill_id)

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
    notify_cast_targeted(game_state, prepared.definition, target, true)

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

  # A player's accepted cast at a monster tells that monster so, before the
  # cast's own effects: the reference's cast-targeted event at its cast start.
  # Renewal fires it for every cast; pre-renewal only for a cast with a cast
  # time or for a skill the reference forces to cast now.
  defp notify_cast_targeted(%PlayerState{} = caster, definition, target, timed?) do
    if timed? or GameMode.mode() == :renewal or forced_cast?(definition, target) do
      MobSkillEvent.deliver_target(
        {:player, caster.character_id},
        :casttargeted,
        target,
        System.system_time(:millisecond)
      )
    end

    :ok
  end

  defp notify_cast_targeted(_caster, _definition, _target, _timed?), do: :ok

  # The reference's own cast-time override list (`unit.cpp`): these skills set
  # its `combo` flag after it was cleared, so pre-renewal treats them as an
  # immediate cast even without a cast time. Asura Strike and Spell Breaker
  # always; Resurrection only against an undead target (its level 4 has no
  # cast time at all). The reference's Gate of Hell and Tiger Cannon are the
  # other two and are not implemented here.
  @forced_cast_skills [:mo_extremityfist, :sa_spellbreaker]

  @spec forced_cast?(Definition.t(), Active.target()) :: boolean()
  defp forced_cast?(%{name: name}, _target) when name in @forced_cast_skills, do: true
  defp forced_cast?(%{name: :all_resurrection}, target), do: undead_target?(target)
  defp forced_cast?(_definition, _target), do: false

  @spec undead_target?(Active.target()) :: boolean()
  defp undead_target?({:unit, target}), do: undead_combatant?(target)
  defp undead_target?({:unit, type, id}), do: undead_combatant?({type, id})
  defp undead_target?(target) when is_integer(target), do: undead_combatant?(target)

  defp undead_target?({type, _id} = ref) when type in [:player, :mob, :homunculus],
    do: undead_combatant?(ref)

  defp undead_target?(_target), do: false

  defp undead_combatant?(target) do
    case TargetResolver.resolve_combatant(target) do
      {:ok, combatant} -> RaceModifiers.undead_target?(combatant)
      {:error, _reason} -> false
    end
  end

  # The cast-start effects of an instant cast run before its effect, as a timed
  # cast's run when its cast bar starts (the caller's job for timed casts).
  # A cast that passed its checks, up to the range, ends its player's attack as
  # it begins: the target and the pending swing are dropped. A combo with the
  # attack's reach keeps the attack, timed or not; a swing falling inside its
  # cast ends the attack then (`CombatActionHandler.handle_auto_attack/2`). A
  # refused cast never reaches here.
  defp stop_attack_at_cast_start(%PlayerState{action_state: :attacking} = caster, false) do
    {:ok, idle} = PlayerState.transition_to(caster, :idle)
    idle
  end

  defp stop_attack_at_cast_start(caster, _keeps_attack?), do: caster

  # An input cast begins and ends at its input's completion, so its attack ends
  # there, once its checks passed.
  defp begin_input_cast(game_state, {:with_input, _value}),
    do: stop_attack_at_cast_start(game_state, false)

  defp begin_input_cast(game_state, :without_input), do: game_state

  defp cast_start(game_state, adapter, skill_id) do
    if function_exported?(adapter, :on_cast_start, 2),
      do: adapter.on_cast_start(game_state, skill_id),
      else: game_state
  end

  # An instant cast reaches its cast end once its cast-start effects ran: the
  # unit placement, the cast-end target, then the cast-end requirements.
  defp complete_instant_cast(game_state, skill_id, level, target, now, prepared) do
    with :ok <- check_instant_castend(game_state, target, prepared),
         :ok <- check_placement(game_state, prepared.definition, target),
         :ok <- check_castend_target(game_state, target, prepared.definition),
         {:ok, prepared} <- prepare_castend(prepared, game_state) do
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
      {:error, reason} -> castend_failure(game_state, skill_id, level, target, reason)
    end
  end

  # A player's instant cast reaches the cast-end checks its cast begin left out;
  # other casters checked them when the cast began.
  defp check_instant_castend(%PlayerState{} = caster, target, %CastContext{} = prepared),
    do: check_player_castend(caster, target, prepared.definition, %{prepared | caster: caster})

  defp check_instant_castend(_caster, _target, _prepared), do: :ok

  defp instant_result(caster, %{instant_effects: effects}), do: {:instant, caster, effects}
  defp instant_result(caster, _prepared_cost), do: {:instant, caster}

  defp fetch_definition(skill_id) when is_integer(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp fetch_definition(skill_name) when is_atom(skill_name) do
    case Catalog.by_name(skill_name) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp fetch_definition(_skill), do: {:error, :unknown_skill}

  defp clamp_level(level, definition), do: min(level, definition.max_level)

  defp check_max_level(definition, level) when level <= definition.max_level, do: :ok
  defp check_max_level(_definition, _level), do: {:error, :invalid_level}

  defp check_castable(%{target_type: :passive}), do: {:error, :passive_skill}
  defp check_castable(_definition), do: :ok

  defp check_support_target(%{target_type: type}) when type in [:target_ally, :target_any],
    do: :ok

  defp check_support_target(_definition), do: {:error, :unsupported_skill}

  defp check_npc_facilities(definition) do
    case Castability.check(definition, :npc) do
      :ok -> :ok
      {:error, {:missing, _requirements}} -> {:error, :missing_caster_facilities}
    end
  end

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

  defp check_weapon(game_state, definition),
    do: Caster.Player.check_weapon(game_state, definition)

  defp fetch_active_module(definition) do
    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_behavior}
    end
  end

  defp check_learned(
         %PlayerState{plagiarized: %{skill_id: skill_id, level: learned_level}},
         _adapter,
         %{id: skill_id},
         level,
         :begin
       )
       when learned_level >= level,
       do: :ok

  defp check_learned(caster, adapter, definition, level, phase),
    do: :erlang.apply(adapter, :knows?, [caster, definition, level, phase])

  defp check_target(caster, target, definition) do
    adapter = Caster.for(caster)

    case :erlang.apply(adapter, :validate_target, [caster, target, definition]) do
      :continue -> check_default_target(caster, target, definition)
      result -> result
    end
  end

  # A unit target concealed from the caster fails the attempt at its cast phase.
  # Only monsters are bosses or detectors, so a player or homunculus caster is
  # checked by identity alone. An unresolvable target falls through so
  # `check_range` reports it.
  defp check_concealment(caster, {:unit, target_ref}, definition, phase) do
    case unit_type_of(target_ref) do
      :not_found ->
        :ok

      target_type ->
        {caster_type, caster_id} = caster_ref(caster)

        Targeting.validate_skill_use(
          %{unit_type: caster_type, unit_id: caster_id},
          %{unit_type: target_type, unit_id: target_unit_id(target_ref)},
          definition,
          phase
        )
    end
  end

  defp check_concealment(_caster, _target, _definition, _phase), do: :ok

  # A timed cast's completion checks its caster's state, then its target.
  defp check_cast_end(caster, target, definition, item?) do
    with :ok <- check_completion_caster(caster, definition, item?),
         do: check_concealment(caster, target, definition, :cast_end)
  end

  defp check_completion_caster(caster, definition, item?) do
    {type, id} = caster_ref(caster)
    Targeting.validate_cast_completion(%{unit_type: type, unit_id: id}, definition, item?)
  end

  defp target_unit_id({_unit_type, unit_id}), do: unit_id
  defp target_unit_id(unit_id), do: unit_id

  # A target that cannot be resolved falls through so `check_range` reports it
  # as `:target_not_found`. A skill-unit cell (Ice Wall, etc.) is accepted
  # without a `Targeting.validate_enemy` call: `unit_type_of/1` only reports
  # `:skill_unit` for a cell the registry already confirmed is targetable, so
  # it is a valid enemy target by construction.
  defp check_default_target(game_state, {:unit, target_id}, %{target_type: :target_enemy}) do
    with :ok <- ensure_targetable_unit(target_id) do
      case unit_type_of(target_id) do
        :mob -> :ok
        :skill_unit -> :ok
        :player -> validate_enemy_player(game_state, target_id)
        :not_found -> :ok
      end
    end
  end

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: target_type})
       when target_type in [:target_ally, :target_any],
       do: ensure_targetable_unit(target_id)

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_corpse}),
    do: ensure_corpse_target(target_id)

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_resurrection}),
       do: ensure_resurrection_target(target_id)

  defp check_default_target(_game_state, {:ground, _x, _y}, %{target_type: :ground}), do: :ok

  defp check_default_target(_game_state, :self, %{target_type: :ground}),
    do: {:error, :invalid_target}

  defp check_default_target(_game_state, {:unit, _id}, %{target_type: :ground}),
    do: {:error, :invalid_target}

  defp check_default_target(_game_state, :self, _definition), do: :ok
  defp check_default_target(%{character_id: caster_id}, {:unit, caster_id}, _definition), do: :ok
  defp check_default_target(_game_state, _target, _definition), do: {:error, :invalid_target}

  defp check_range(_game_state, :self, _definition, _level), do: :ok

  defp check_range(game_state, {:unit, target_id}, definition, level) do
    range = effective_range(definition, game_state, level)

    case resolve_unit_position(target_id) do
      {:ok, {tx, ty, target_map}} ->
        cond do
          target_map != game_state.map_name ->
            {:error, :different_map}

          Geometry.chebyshev_distance(game_state.x, game_state.y, tx, ty) <= range ->
            :ok

          true ->
            {:error, :out_of_range}
        end

      {:error, _} ->
        {:error, :target_not_found}
    end
  end

  defp check_range(game_state, {:ground, x, y}, definition, level) do
    with :ok <- check_ground_range(game_state, x, y, definition, level) do
      check_ground_walkable(game_state.map_name, x, y)
    end
  end

  defp check_ground_range(game_state, x, y, definition, level) do
    range = effective_range(definition, game_state, level)

    if Geometry.chebyshev_distance(game_state.x, game_state.y, x, y) <= range,
      do: :ok,
      else: {:error, :out_of_range}
  end

  @doc """
  The cast-range of a skill for a given caster and level, in cells (Chebyshev).

  Resolves the definition's declared range at `level` as the server counts it
  (`SkillRange.database_range/2`: its absolute value, so a negative range does not
  take the weapon's reach, capped at 14 cells). A skill declaring
  `vulture_range: true` (the bow skills whose reach trains with Vulture's Eye) then
  adds a player caster's learned Vulture's Eye level; no other caster kind gains
  anything. Exposed so the session handler can size the move-to-range approach for
  an out-of-range cast.
  """
  @spec effective_range(Definition.t(), Active.caster(), non_neg_integer()) :: non_neg_integer()
  def effective_range(definition, game_state, level) do
    base_range = base_range(definition, game_state, level)

    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> skill_effective_range(module, game_state, level, definition, base_range)
      :error -> base_range
    end
  end

  defp base_range(definition, game_state, level),
    do: SkillRange.database_range(definition, level) + vulture_range_bonus(definition, game_state)

  defp vulture_range_bonus(%{vulture_range: true}, %PlayerState{} = game_state) do
    PlayerStats.skill_level(game_state.stats, @vulture_skill_id)
  end

  defp vulture_range_bonus(_definition, _game_state), do: 0

  defp skill_effective_range(module, game_state, level, definition, base_range) do
    if function_exported?(module, :effective_range, 4) do
      case module.effective_range(game_state, level, definition, base_range) do
        range when is_integer(range) and range >= 0 -> range
        invalid -> raise ArgumentError, "invalid effective skill range: #{inspect(invalid)}"
      end
    else
      base_range
    end
  end

  defp check_ground_walkable(map_name, x, y) do
    if Cell.placeable?(map_name, x, y) do
      :ok
    else
      {:error, :invalid_target}
    end
  end

  # Resolves player, mob, and skill-unit (Ice Wall, etc.) target ids alike
  # through `Combat.resolve_target_position/1`, the single source of truth for
  # target-position resolution shared with basic-attack targeting.
  defp resolve_unit_position(unit_id) do
    case Combat.resolve_target_position(unit_id) do
      {:ok, _type, position} -> {:ok, position}
      {:error, _reason} = error -> error
    end
  end

  defp unit_type_of(unit_id) do
    case Combat.resolve_target_position(unit_id) do
      {:ok, type, _position} -> type
      {:error, :target_not_found} -> :not_found
    end
  end

  # A dead player is a legal cast target: the reference pays the requirement and
  # its cast end returns before the effect (see `dead_target_skip?/2`). A dead
  # monster or homunculus is removed from the map, so it stays refused here.
  defp ensure_targetable_unit(unit_id) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, _target_state, :player} ->
        :ok

      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        :ok
    end
  end

  # A target that vanishes between position resolution and the typed re-resolution
  # rejects like a non-enemy instead of crashing.
  defp validate_enemy_player(game_state, target_id) do
    case TargetResolver.resolve(:player, target_id) do
      {:ok, _pid, target_state, :player} ->
        Targeting.validate_enemy_relation_allow_dead(game_state, target_state)

      _ ->
        {:error, :invalid_target}
    end
  end

  defp ensure_corpse_target(unit_id) do
    result =
      case TargetResolver.resolve(unit_id) do
        {:ok, _pid, target_state, :player} ->
          if Unit.corpse?(target_state),
            do: :ok,
            else: {:error, :invalid_target}

        {:ok, _pid, _target_state, _unit_type} ->
          {:error, :invalid_target}

        {:error, _reason} ->
          {:error, :target_not_found}
      end

    result
  catch
    :exit, _reason -> {:error, :target_not_found}
  end

  defp ensure_resurrection_target(unit_id) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, target_state, :player} ->
        if Unit.corpse?(target_state),
          do: :ok,
          else: TargetResolver.ensure_targetable(target_state, :player)

      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        {:error, :target_not_found}
    end
  catch
    :exit, _reason -> {:error, :target_not_found}
  end

  defp check_cooldown(game_state, skill_id, now) do
    if Cooldown.ready?(game_state.skill_cooldowns, skill_id, now) do
      :ok
    else
      {:error, :on_cooldown}
    end
  end

  defp check_sp(adapter, game_state, cost) do
    if adapter.sp(game_state) >= cost, do: :ok, else: {:error, :insufficient_sp}
  end

  # Reads a folded equipment modifier off the caster's `stats.modifiers.equipment`
  # map, defaulting to 0 when the key is absent or the caster carries no equipment
  # slice (unequipped players, bare-map test fixtures). Keys are either a bare
  # destination atom (global `bonus` keys) or a `{family, skill_id}` tuple
  # (per-skill `bonus2` keys), both produced by the equip-script eval fold.
  @spec equip_modifier(PlayerState.t(), atom() | {atom(), integer()}) :: integer()
  defp equip_modifier(game_state, key) do
    case Map.get(game_state, :stats) do
      nil ->
        0

      stats ->
        stats
        |> Map.get(:modifiers, %{})
        |> Map.get(:equipment, %{})
        |> Map.get(key, 0)
    end
  end

  defdelegate effective_item_cost(game_state, definition), to: Caster.Player

  defp run_cast(module, caster, target, level, definition, origin, input, adapter) do
    {result, attacked?} =
      Origin.collect_skill_attacks(fn ->
        invoke(module, caster, target, level, definition, origin, input)
      end)

    result
    |> settle_skill_attack(caster, adapter, attacked?)
    |> cast_outcome(module, target, level, definition, adapter)
  end

  defp invoke(module, caster, target, level, definition, origin, {:with_input, value}) do
    if function_exported?(module, :cast_with_input, 5) do
      invoke_cast_with_input(module, caster, target, level, definition, value, origin)
    else
      invoke_cast(module, caster, target, level, definition, unflagged_scope(origin))
    end
  end

  defp invoke(module, caster, target, level, definition, origin, :without_input),
    do: invoke_cast(module, caster, target, level, definition, unflagged_scope(origin))

  # The reference's `skill_combo` runs inside every skill attack its owner makes,
  # after the hit and before the window the attack itself earns. Applies that
  # ending to the state the effect returned, through the caster's own adapter.
  defp settle_skill_attack(result, caster, adapter, true) do
    if function_exported?(adapter, :on_skill_attack, 2),
      do: map_caster(result, &adapter.on_skill_attack(&1, caster)),
      else: result
  end

  defp settle_skill_attack(result, _caster, _adapter, false), do: result

  defp map_caster({:ok, caster}, fun), do: {:ok, fun.(caster)}
  defp map_caster({:ok, caster, tag}, fun), do: {:ok, fun.(caster), tag}

  defp map_caster({:local_effects, caster, effects}, fun),
    do: {:local_effects, fun.(caster), effects}

  defp map_caster({:deferred, caster, descriptor}, fun),
    do: {:deferred, fun.(caster), descriptor}

  defp map_caster({:failed, caster, reason}, fun), do: {:failed, fun.(caster), reason}

  defp map_caster({:failed, caster, reason, variant}, fun),
    do: {:failed, fun.(caster), reason, variant}

  defp map_caster({:skipped, caster, reason}, fun), do: {:skipped, fun.(caster), reason}

  defp map_caster(result, _fun), do: result

  defp cast_outcome(result, module, target, level, definition, adapter) do
    case result do
      {:ok, caster} ->
        valid_cast_result(adapter, caster, fn ->
          announce_ground_cast(module, caster, target, level, definition)
          {:ok, caster, [], true}
        end)

      {:ok, caster, :no_consume} ->
        valid_cast_result(adapter, caster, fn ->
          announce_ground_cast(module, caster, target, level, definition)
          {:ok, caster, [], false}
        end)

      {:local_effects, caster, effects} when is_list(effects) ->
        valid_cast_result(adapter, caster, fn ->
          announce_ground_cast(module, caster, target, level, definition)
          {:local_effects, caster, effects, true}
        end)

      {:failed, caster, reason} ->
        valid_cast_result(adapter, caster, fn -> {:failed, caster, reason} end)

      {:failed, caster, reason, variant} when variant in [:spare_items, :after_effect] ->
        valid_cast_result(adapter, caster, fn ->
          announce_after_effect(variant, module, caster, target, level, definition)
          {:failed, caster, reason, variant}
        end)

      {:skipped, caster, reason} ->
        valid_cast_result(adapter, caster, fn -> {:skipped, caster, reason} end)

      {:deferred, caster, descriptor} ->
        {:deferred, caster, descriptor}

      {:error, _reason} = error ->
        error
    end
  end

  defp valid_cast_result(adapter, caster, success) do
    if :erlang.apply(adapter, :valid_caster_result?, [caster]),
      do: success.(),
      else: {:error, :invalid_caster_result}
  end

  defp invoke_cast_with_input(module, caster, target, level, definition, value, origin) do
    Origin.with_skill(definition.name, caster_ref(caster), unflagged_scope(origin), fn ->
      module.cast_with_input(caster, target, level, definition, value)
    end)
  end

  # The skill sees the scope's invocation as its origin; only
  # `run_unconditional/7` builds a flagged scope.
  defp invoke_cast(module, game_state, target, level, definition, %{invocation: origin} = scope) do
    Origin.with_skill(definition.name, caster_ref(game_state), scope, fn ->
      if function_exported?(module, :cast_with_origin, 5) do
        module.cast_with_origin(game_state, target, level, definition, origin)
      else
        module.cast(game_state, target, level, definition)
      end
    end)
  end

  defp caster_ref(caster) do
    adapter = Caster.for(caster)
    {adapter.unit_type(caster), adapter.id(caster)}
  end

  defp unflagged_scope(origin), do: %{invocation: origin, autocast_flag?: false}

  # A ground-targeted skill without the `Skill.Ground` capability (e.g.
  # Heaven's Drive) creates no unit group, so `Unit.place/4` never broadcasts
  # its cast animation; announce the execution point here, mirroring rAthena's
  # `clif_skill_poseffect`. Unit-placing skills skip this - their single
  # `GroundSkill` comes from the group placement.
  defp announce_ground_cast(module, game_state, {:ground, x, y}, level, definition) do
    if :ground not in module.__skill_capabilities__() do
      adapter = Caster.for(game_state)

      packet = %GroundSkill{
        skill_id: definition.id,
        src_id: adapter.id(game_state),
        level: level,
        x: x,
        y: y,
        server_tick: ServerTick.now()
      }

      Broadcast.to_in_range(game_state.map_name, x, y, Config.view_range(), packet)
    end

    :ok
  end

  defp announce_ground_cast(_module, _game_state, _target, _level, _definition), do: :ok

  # Cooldown is the definition's per-level duration plus the caster's per-skill
  # equipment `{:skill_cooldown, id}` delta (rAthena bSkillCooldown, ms, negative
  # shortens). The final duration is floored at 0; a duration that collapses to 0
  # writes no entry, matching a zero-cooldown skill. The delta is read even for a
  # skill with no base cooldown, so a bonus can give one to a skill that has none.
  defp put_cooldown(game_state, skill_id, definition, level, now) do
    base = Cooldown.duration(definition, level)
    delta = equip_modifier(game_state, {:skill_cooldown, skill_id})

    case max(0, base + delta) do
      0 ->
        game_state

      duration ->
        cooldowns = Cooldown.put(game_state.skill_cooldowns, skill_id, now + duration)
        %{game_state | skill_cooldowns: cooldowns}
    end
  end

  defp rearm_cooldowns(game_state, module, level, definition, now) do
    if function_exported?(module, :rearm_cooldowns, 4),
      do: module.rearm_cooldowns(game_state, level, definition, now),
      else: game_state
  end

  defp scale_cast_time(module, caster, target, level, time) do
    if function_exported?(module, :scale_cast_time, 4),
      do: module.scale_cast_time(caster, target, level, time),
      else: time
  end

  defp put_cooldown(game_state, adapter, skill_id, definition, level, now) do
    duration =
      definition
      |> Cooldown.duration(level)
      |> Kernel.+(equip_modifier(game_state, {:skill_cooldown, skill_id}))
      |> max(0)

    expires_at = if duration == 0, do: 0, else: now + duration
    adapter.put_cooldown(game_state, skill_id, expires_at)
  end

  # After-cast act delay (AfterCastActDelay) reduced by delay-rate sources
  # (Bragi `:delay_reduction`), not ASPD, then scaled by the caster's equipment
  # `:delay_rate` (`bDelayrate`, a signed percent delta where negative is less
  # delay). Equipment applies as its own multiplicative step so it never
  # compounds additively with the status reductions. Floors the delay at 0.
  defp put_resolved_act_delay(game_state, false, _delay, _now), do: game_state

  defp put_resolved_act_delay(game_state, true, delay, now),
    do: arm_act_delay(game_state, now + delay, @act_delay_slack)

  # A new act delay never ends before the one already armed (0 is none),
  # except that an ordinary or item cast may shorten it by a small fixed
  # slack; a proc or status cast may not shorten it at all.
  defp arm_act_delay(%{act_delay_until: until} = game_state, deadline, slack)
       when is_integer(until) and until != 0,
       do: %{game_state | act_delay_until: max(deadline, until - slack)}

  defp arm_act_delay(game_state, deadline, _slack), do: %{game_state | act_delay_until: deadline}

  defp put_act_delay(game_state, definition, level, now, slack \\ @act_delay_slack)

  defp put_act_delay(%PlayerState{} = game_state, definition, level, now, slack) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil ->
        game_state

      0 ->
        game_state

      _base ->
        delay = resolved_after_cast_delay(game_state, definition, level)
        arm_act_delay(game_state, now + delay, slack)
    end
  end

  defp put_act_delay(game_state, _definition, _level, _now, _slack), do: game_state
end
