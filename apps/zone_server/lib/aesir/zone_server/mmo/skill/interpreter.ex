defmodule Aesir.ZoneServer.Mmo.Skill.Interpreter do
  @moduledoc """
  Orchestrates a skill cast across two phases.

  `begin_cast/4` runs the full validation chain and computes the renewal cast
  time; a zero-cast skill resolves immediately, a timed skill returns a
  `cast_info` for the caller to schedule and leaves the game state untouched
  (no SP deducted, no cooldown set). `complete_cast/4` re-validates the target,
  re-checks SP, runs the behavior, then deducts SP, sets the cooldown, and arms
  the after-cast act delay.

  Validate-then-cast-then-charge: SP is only consumed at castend, so a failed
  or interrupted cast never charges SP. Starting any cast is blocked while the
  act delay is pending (`validate_cast` rejects with `{:error, :act_delayed}`).

  `cast/4` is the synchronous wrapper preserving the legacy single-call
  semantics: instant casts execute immediately and timed casts run their
  behavior inline through `complete_cast/4`.

  `auto_cast/4` and `item_cast/4` are narrow entry points for casts the player
  did not initiate (a status proc, an item's script); each documents exactly
  which requirements it bypasses. Status auto-casts accept every registered
  caster and charge only SP. Item casts are player-only because item scripts
  operate on player inventories.
  """
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.AttackSpeed
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Castability
  alias Aesir.ZoneServer.Mmo.Skill.CastContext
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.SkillCaster
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

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
  `total` the full duration, both in milliseconds.
  """
  @type cast_info :: %{
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
          | {:error, atom()}
  def cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    case begin_cast(game_state, skill_id, level, target) do
      {:instant, game_state} -> {:ok, game_state}
      {:instant, game_state, effects} -> {:local_effects, game_state, effects}
      {:deferred, game_state, descriptor} -> {:deferred, game_state, descriptor}
      {:casting, game_state, _info} -> complete_cast(game_state, skill_id, level, target)
      {:error, _reason} = error -> error
    end
  end

  def cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  @doc """
  Validates a cast and resolves its timing.

  Runs the full validation chain (without deducting SP or running the behavior)
  and computes the cast time from the caster's base DEX/INT. A zero cast time
  resolves immediately through `complete_cast/4` and returns `{:instant, gs}`;
  otherwise returns `{:casting, gs, cast_info}` with `gs` unchanged so the
  caller can schedule the cast.

  Variable-cast reduction sums the caster's status-sourced `:cast_time_reduction`
  values (Suffragium, Bragi) and passes the total into `CastTime` as a plain
  integer, keeping `CastTime` pure. The additive `varcast_rate` channel folds the
  caster's status `:varcast_rate` with the per-skill equipment
  `{:skill_varcast_rate, id}` bonus (items carry negatives) at this single call
  site, so `CastTime` never reads state. The caster's equipment `:fixed_cast`
  bonus is passed the same way: a flat millisecond delta on the fixed portion.

  NOTE: cast-time reduction uses base DEX/INT only; effective/buffed DEX/INT is a
  documented later refinement.
  """
  @spec begin_cast(Active.caster(), integer(), pos_integer(), Active.target()) ::
          {:instant, Active.caster()}
          | {:instant, Active.caster(), [Active.effect()]}
          | {:deferred, Active.caster(), term()}
          | {:casting, Active.caster(), cast_info()}
          | {:error, atom()}
  def begin_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, context} <- validate_cast(game_state, skill_id, level, target, now) do
      timing_definition =
        cast_timing_definition(
          context.caster,
          context.module,
          context.target,
          context.level,
          context.definition
        )

      timing = CastTime.compute(timing_definition, context.level, context.stats)

      schedule(timing, game_state, skill_id, level, target, context)
    end
  end

  def begin_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  # Sums a stored reduction percentage (`:delay_reduction`) across the caster's
  # active statuses, for the after-cast delay path (additive sum, one multiply -
  # rAthena skill_delayfix:10491).
  @spec sum_status_reduction(integer(), atom()) :: non_neg_integer()
  defp sum_status_reduction(character_id, state_key) do
    :player
    |> StatusStorage.get_unit_statuses(character_id)
    |> Enum.reduce(0, fn entry, acc ->
      acc + Map.get(entry.state || %{}, state_key, 0)
    end)
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

  This restricted entry point accepts only Dissonance and the four Bard songs.
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
  Resolves cast timing for an allowlisted, fully validated Encore memory.

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
  Completes one allowlisted Encore replay after revalidating mutable conditions.

  This invokes the remembered behavior once and writes only the remembered
  skill's cooldown after success. It deliberately commits no resources, Encore
  cooldown, or act delay; the already-prepared outer Encore cast owns those.
  """
  @spec complete_encore_replay(PlayerState.t(), map(), Active.target()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def complete_encore_replay(game_state, memory, target) do
    now = System.monotonic_time(:millisecond)

    with {:ok, %{definition: definition, module: module, skill_id: skill_id, level: level}} <-
           validate_encore_replay(game_state, memory, target, now) do
      case run_unconditional(module, game_state, target, level, definition, :normal) do
        {:ok, game_state} ->
          {:ok, put_cooldown(game_state, skill_id, definition, level, now)}

        {:deferred, _game_state, _descriptor} ->
          {:error, :unsupported_encore_replay}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @doc """
  Runs a previously-validated cast to completion.

  Re-validates the target (it may have moved, died, or logged out during the
  cast) and re-checks every resolved resource cost, then runs the behavior,
  applies the prepared cost, sets the cooldown, and arms the after-cast act
  delay. A target that is gone or out of range fizzles with `{:error, _}` and
  no resources are spent.

  The resources are validated from the pre-effect state, so `:all` SP is visible
  to the behavior. On success, the already-validated HP and SP costs are then
  deducted from the behavior's returned state; a behavior's own HP/SP changes
  are therefore retained. Sphere consumption is prepared from the original
  collection.
  """
  @spec complete_cast(Active.caster(), integer(), pos_integer(), Active.target()) ::
          {:ok, Active.caster()}
          | {:local_effects, Active.caster(), [Active.effect()]}
          | {:deferred, Active.caster(), term()}
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
          | {:error, atom()}
  def complete_cast_with_input(game_state, skill_id, level, target, input)
      when is_integer(level) and level > 0,
      do: complete_validated_cast(game_state, skill_id, level, target, {:with_input, input})

  def complete_cast_with_input(_game_state, _skill_id, _level, _target, _input),
    do: {:error, :invalid_level}

  defp complete_validated_cast(game_state, skill_id, level, target, input) do
    now = System.monotonic_time(:millisecond)

    validation =
      case input do
        :without_input -> validate_completion(game_state, skill_id, level, target)
        {:with_input, _value} -> validate_cast(game_state, skill_id, level, target, now)
      end

    with {:ok, prepared} <- validation do
      complete_prepared_cast(game_state, skill_id, level, target, input, now, prepared)
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
    apply_act_delay = Enum.at(context.definition.after_cast_delay, level - 1) not in [nil, 0]
    after_cast_delay = resolved_after_cast_delay(game_state, context.definition, level)
    definition = put_resolved_combo_delay(context.definition, level, after_cast_delay)

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

  @doc "Settles a deferred cast against the caster's current resources."
  @spec settle_deferred(PlayerState.t(), Deferred.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def settle_deferred(game_state, %Deferred{} = deferred) do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(deferred.skill_id),
         {:ok, prepared} <-
           Caster.Player.prepare_cost(
             game_state,
             __MODULE__,
             definition,
             deferred.cost,
             deferred.zeny
           ) do
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

  Insufficient SP returns `{:error, :insufficient_sp}` and runs nothing, which the
  caller drops silently: rAthena's `status_charge` failing simply skips the proc,
  with no message to the player.

  A ground bolt (Thunderstorm, Heaven's Drive) is cast at the victim's cell,
  mirroring rAthena's `skill_get_casttype` switch to `skill_castend_pos2`.
  """
  @spec auto_cast(Active.caster(), integer(), pos_integer(), Active.target()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def auto_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)
    adapter = Caster.for(game_state)

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         {:ok, module} <- fetch_active_module(definition),
         {:ok, resolved} <- resolve_auto_cast_target(definition, target),
         cost = auto_cast_sp_cost(definition, level),
         :ok <- check_sp(adapter, game_state, cost),
         {:ok, game_state} <-
           run_unconditional(module, game_state, resolved, level, definition, :auto) do
      {:ok,
       game_state
       |> adapter.deduct_sp(cost)
       |> put_act_delay(definition, level, now)}
    end
  end

  def auto_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

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
          {:ok, PlayerState.t()} | {:error, atom()}
  def item_cast(%PlayerState{} = game_state, skill_id, level, target)
      when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- check_target(game_state, target, definition),
         :ok <- check_range(game_state, target, definition, level),
         :ok <- module.validate(game_state, target, level, definition),
         {:ok, game_state} <-
           run_unconditional(module, game_state, target, level, definition, :item) do
      {:ok,
       game_state
       |> put_cooldown(skill_id, definition, level, now)
       |> put_act_delay(definition, level, now)}
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

  @doc "Resolves the committed after-cast duration, including Monk combo flooring."
  @spec resolved_after_cast_delay(PlayerState.t() | map(), Definition.t(), pos_integer()) ::
          non_neg_integer()
  def resolved_after_cast_delay(game_state, definition, level) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil -> 0
      0 -> 0
      base -> resolve_delay(game_state, definition.id, base)
    end
  end

  # rAthena: `skill_get_sp(skill_id, skill_lv) * 2 / 3`, C integer division.
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
  # today.
  defp run_unconditional(module, game_state, target, level, definition, origin) do
    case invoke_cast(module, game_state, target, level, definition, origin) do
      {:ok, game_state} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, game_state}

      {:ok, game_state, :no_consume} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, game_state}

      {:deferred, game_state, descriptor} ->
        {:deferred, game_state, descriptor}

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
           apply_act_delay: apply_act_delay,
           after_cast_delay: after_cast_delay,
           now: now,
           input: input
         }
       ) do
    origin = adapter.cast_origin(game_state)

    case run_cast(module, game_state, target, level, definition, origin, input, adapter) do
      {:deferred, game_state, descriptor} ->
        deferred_result(game_state, descriptor, prepared_cost, skill_id, level, target)

      {result, game_state, effects, consume_catalysts?}
      when result in [:ok, :local_effects] and is_list(effects) ->
        prepared_cost = Map.put(prepared_cost, :consume_catalysts?, consume_catalysts?)

        settled =
          game_state
          |> then(&adapter.commit(&1, prepared_cost))
          |> put_cooldown(adapter, skill_id, definition, level, now)
          |> put_resolved_act_delay(apply_act_delay, after_cast_delay, now)

        if result == :local_effects,
          do: {:local_effects, settled, effects},
          else: {:ok, settled}

      {:error, _reason} = error ->
        error
    end
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
       when skill_id in [272, 273] do
    %{
      definition
      | after_cast_delay: List.replace_at(definition.after_cast_delay, level - 1, delay)
    }
  end

  defp put_resolved_combo_delay(definition, _level, _delay), do: definition

  defp validate_cast(caster, skill_id, level, target, now) when is_struct(caster),
    do: validate_owned_cast(caster, skill_id, level, target, now)

  defp validate_cast(caster, skill_id, level, target, now) do
    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition) do
      validate_owned_cast(caster, skill_id, level, target, now)
    end
  end

  defp validate_owned_cast(caster, skill_id, level, target, now) do
    with {:ok, adapter} <- lifecycle_adapter(caster),
         :ok <- :erlang.apply(adapter, :castable_state, [caster, skill_id, :begin]),
         {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_weapon(caster, definition),
         :ok <- check_learned(caster, adapter, definition, level, :begin),
         :ok <- check_target(caster, target, definition),
         :ok <- check_range(caster, target, definition, level),
         {:ok, _module} <- fetch_active_module(definition),
         :ok <- :erlang.apply(adapter, :castable_status, [caster, skill_id]),
         context = CastContext.build(caster, definition, level, target, :begin),
         :ok <- check_context_cooldown(context, now),
         :ok <- check_context_act_delay(context, now) do
      validate_and_prepare(context)
    end
  end

  defp validate_completion(caster, skill_id, level, target) do
    now = System.monotonic_time(:millisecond)

    with {:ok, adapter} <- lifecycle_adapter(caster),
         :ok <- :erlang.apply(adapter, :castable_state, [caster, skill_id, :completion]),
         {:ok, definition} <- fetch_definition(skill_id) do
      if :erlang.apply(adapter, :completion_revalidates_definition?, []) do
        validate_revalidated_completion(
          caster,
          skill_id,
          level,
          target,
          now,
          adapter,
          definition
        )
      else
        validate_player_completion(caster, skill_id, level, target, now, adapter, definition)
      end
    end
  end

  defp validate_revalidated_completion(
         caster,
         skill_id,
         level,
         target,
         now,
         adapter,
         definition
       ) do
    with :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- :erlang.apply(adapter, :knows?, [caster, definition, level, :completion]),
         :ok <- check_target(caster, target, definition),
         :ok <- check_range(caster, target, definition, level),
         {:ok, _module} <- fetch_active_module(definition),
         :ok <- :erlang.apply(adapter, :castable_status, [caster, skill_id]),
         context = CastContext.build(caster, definition, level, target, :completion),
         :ok <- check_context_cooldown(context, now) do
      validate_and_prepare(context)
    end
  end

  defp validate_player_completion(caster, skill_id, level, target, now, adapter, definition) do
    with {:ok, _module} <- fetch_active_module(definition),
         context = CastContext.build(caster, definition, level, target, :completion),
         :ok <- :erlang.apply(adapter, :knows?, [caster, definition, level, :completion]),
         :ok <- check_target(caster, target, definition),
         :ok <- check_range(caster, target, definition, level),
         :ok <- :erlang.apply(adapter, :castable_status, [caster, skill_id]),
         :ok <- check_context_cooldown(context, now) do
      validate_and_prepare(context)
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
             :ok <- check_learned(game_state, skill_id, level),
             :ok <- check_quest_lineage(game_state, definition),
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

  defp validate_and_prepare(%CastContext{} = context) do
    if context.adapter.cost_before_validation?() do
      with {:ok, context} <- prepare_cast(context),
           :ok <-
             context.module.validate(
               context.caster,
               context.target,
               context.level,
               context.definition
             ) do
        {:ok, context}
      end
    else
      with :ok <-
             context.module.validate(
               context.caster,
               context.target,
               context.level,
               context.definition
             ) do
        prepare_cast(context)
      end
    end
  end

  defp prepare_cast(%CastContext{} = context) do
    adapter = context.adapter

    case adapter.cost(
           context.caster,
           context.module,
           context.target,
           context.definition,
           context.level
         ) do
      {:ok, prepared} -> {:ok, %{context | cost: prepared}}
      {:error, _reason} = error -> error
    end
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
          CastContext.t()
        ) ::
          {:instant, Active.caster()}
          | {:instant, Active.caster(), [Active.effect()]}
          | {:deferred, Active.caster(), term()}
          | {:casting, Active.caster(), cast_info()}
          | {:error, atom()}
  defp schedule(%{total: 0}, game_state, skill_id, level, target, prepared) do
    now = System.monotonic_time(:millisecond)

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
      {:error, _reason} = error -> error
    end
  end

  defp schedule(%{fixed: fixed, total: total}, game_state, skill_id, level, target, prepared) do
    info = %{
      skill_id: skill_id,
      level: level,
      target: target,
      element: prepared.definition.element,
      fixed: fixed,
      total: total
    }

    {:casting, game_state, info}
  end

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
    case module.cast(caster, target, level, definition) do
      {:ok, _caster} -> {:ok, caster}
      {:ok, _caster, :no_consume} -> {:ok, caster}
      {:error, _reason} = error -> error
      _other -> {:error, :unsupported_skill}
    end
  end

  defp check_weapon(_game_state, %{require_weapon: []}), do: :ok

  defp check_weapon(%{stats: %{equipment: equipment}}, %{require_weapon: allowed}) do
    if PlayerStats.weapon_type(equipment) in allowed,
      do: :ok,
      else: {:error, :wrong_weapon}
  end

  defp check_weapon(_game_state, _definition), do: :ok

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

  defp check_learned(game_state, skill_id, level) do
    learned = game_state.stats.progression.learned_skills

    if Learned.learned_level(learned, skill_id) >= level do
      :ok
    else
      {:error, :skill_not_learned}
    end
  end

  defp check_quest_lineage(game_state, %{quest_skill: true} = definition) do
    if SkillTree.quest_skill_available?(game_state.stats.progression.job_id, definition) do
      :ok
    else
      {:error, :skill_not_learned}
    end
  end

  defp check_quest_lineage(_game_state, _definition), do: :ok

  defp check_target(caster, target, definition) do
    adapter = Caster.for(caster)

    case :erlang.apply(adapter, :validate_target, [caster, target, definition]) do
      :continue -> check_default_target(caster, target, definition)
      result -> result
    end
  end

  # A target that cannot be resolved falls through so `check_range` reports it
  # as `:target_not_found`. A skill-unit cell (Ice Wall, etc.) is accepted
  # without a `Targeting.validate_enemy` call: `unit_type_of/1` only reports
  # `:skill_unit` for a cell the registry already confirmed is targetable, so
  # it is a valid enemy target by construction.
  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_enemy}) do
    with :ok <- ensure_living_target(target_id) do
      case unit_type_of(target_id) do
        :mob -> :ok
        :skill_unit -> :ok
        :player -> {:error, :invalid_target}
        :not_found -> :ok
      end
    end
  end

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: target_type})
       when target_type in [:target_ally, :target_any],
       do: ensure_living_target(target_id)

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_corpse}),
    do: ensure_corpse_target(target_id)

  defp check_default_target(_game_state, {:unit, target_id}, %{target_type: :target_resurrection}),
       do: ensure_resurrection_target(target_id)

  defp check_default_target(_game_state, {:ground, _x, _y}, %{target_type: :ground}), do: :ok

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

  Resolves the definition's declared range at `level` first (`Definition.range_at_level/2`,
  a no-op for a flat range). rAthena encodes melee skills as `range: -1` ("use the
  weapon's range"); that is resolved to the caster's equipped-weapon attack range at
  cast time. Exposed so the session handler can size the move-to-range approach for an
  out-of-range cast.
  """
  @spec effective_range(Definition.t(), Active.caster(), non_neg_integer()) :: non_neg_integer()
  def effective_range(definition, game_state, level) do
    base_range = base_range(definition, game_state, level)

    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> skill_effective_range(module, game_state, level, definition, base_range)
      :error -> base_range
    end
  end

  defp base_range(definition, game_state, level) do
    case Definition.range_at_level(definition, level) do
      range when range >= 0 -> range
      _weapon_range_sentinel -> weapon_range(game_state)
    end
  end

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

  defp weapon_range(caster) do
    adapter = Caster.for(caster)
    adapter.attack_range(caster)
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

  defp ensure_living_target(unit_id) do
    case TargetResolver.resolve(unit_id) do
      {:ok, _pid, target_state, unit_type} ->
        TargetResolver.ensure_targetable(target_state, unit_type)

      {:error, _reason} ->
        :ok
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
    result =
      case input do
        {:with_input, value} ->
          if function_exported?(module, :cast_with_input, 5) do
            module.cast_with_input(caster, target, level, definition, value)
          else
            invoke_cast(module, caster, target, level, definition, origin)
          end

        :without_input ->
          invoke_cast(module, caster, target, level, definition, origin)
      end

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
        valid_cast_result(adapter, caster, fn -> {:local_effects, caster, effects, true} end)

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

  defp invoke_cast(module, game_state, target, level, definition, origin) do
    if function_exported?(module, :cast_with_origin, 5) do
      module.cast_with_origin(game_state, target, level, definition, origin)
    else
      module.cast(game_state, target, level, definition)
    end
  end

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
    do: %{game_state | act_delay_until: now + delay}

  defp put_act_delay(%PlayerState{} = game_state, definition, level, now) do
    case Enum.at(definition.after_cast_delay, level - 1) do
      nil ->
        game_state

      0 ->
        game_state

      _base ->
        %{
          game_state
          | act_delay_until: now + resolved_after_cast_delay(game_state, definition, level)
        }
    end
  end

  defp put_act_delay(game_state, _definition, _level, _now), do: game_state

  defp resolve_delay(game_state, skill_id, base) do
    base = combo_base_delay(game_state, skill_id, base)
    reduction = sum_status_reduction(game_state.character_id, :delay_reduction)
    delay_rate = equip_modifier(game_state, :delay_rate)
    reduced = round(base * (100 - reduction) / 100 * max(0, 100 + delay_rate) / 100)

    if skill_id in [272, 273], do: combo_delay_floor(game_state, reduced), else: max(0, reduced)
  end

  defp combo_base_delay(game_state, skill_id, base) when skill_id in [272, 273] do
    stats = game_state.stats.base_stats
    max(0, base - 4 * stats.agi - 2 * stats.dex)
  end

  defp combo_base_delay(_game_state, _skill_id, base), do: base

  defp combo_delay_floor(game_state, reduced) do
    attack_motion = AttackSpeed.calculate_delay_from_stats(game_state.stats) |> div(2)
    max(attack_motion, max(0, reduced))
  end
end
