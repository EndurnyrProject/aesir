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
  which requirements it bypasses.
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
  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Ammo
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  defmodule Deferred do
    @moduledoc "Deferred effect plus the owner-local resources settled on reply."

    use TypedStruct

    alias Aesir.ZoneServer.Mmo.Skill.Active
    alias Aesir.ZoneServer.Mmo.Skill.Cost

    typedstruct do
      field(:effect, term(), enforce: true)
      field(:cost, Cost.t(), enforce: true)
      field(:zeny, non_neg_integer(), enforce: true)
      field(:skill_id, integer(), enforce: true)
      field(:level, pos_integer(), enforce: true)
      field(:target, Active.target(), enforce: true)
    end
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
          {:ok, PlayerState.t()} | {:deferred, PlayerState.t(), term()} | {:error, atom()}
  def cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    case begin_cast(game_state, skill_id, level, target) do
      {:instant, game_state} -> {:ok, game_state}
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
  @spec begin_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:instant, PlayerState.t()}
          | {:deferred, PlayerState.t(), term()}
          | {:casting, PlayerState.t(), cast_info()}
          | {:error, atom()}
  def begin_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, prepared} <- validate_cast(game_state, skill_id, level, target, now) do
      %{definition: definition, module: module} = prepared
      base_stats = game_state.stats.base_stats

      timing =
        CastTime.compute(
          cast_timing_definition(game_state, module, target, level, definition),
          level,
          %{
            dex: base_stats.dex,
            int: base_stats.int,
            varcast_reductions: status_reductions(game_state.character_id, :cast_time_reduction),
            varcast_rate:
              merged_modifier(game_state.character_id, :varcast_rate) +
                equip_modifier(game_state, :varcast_rate) +
                equip_modifier(game_state, {:skill_varcast_rate, skill_id}),
            fixed_cast: equip_modifier(game_state, :fixed_cast)
          }
        )

      schedule(timing, game_state, skill_id, level, target, prepared)
    end
  end

  def begin_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  # Collects each active status's stored reduction percentage as a list, for the
  # variable-cast path that applies each as a separate multiplicative factor
  # (rAthena skill_vfcastfix). Statuses without the key are skipped.
  @spec status_reductions(integer(), atom()) :: [non_neg_integer()]
  defp status_reductions(character_id, state_key) do
    :player
    |> StatusStorage.get_unit_statuses(character_id)
    |> Enum.flat_map(fn entry ->
      case Map.get(entry.state || %{}, state_key) do
        nil -> []
        value -> [value]
      end
    end)
  end

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
          PlayerState.t(),
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
  @spec preflight_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          :ok | {:error, atom()}
  def preflight_cast(game_state, skill_id, level, target)
      when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    case validate_cast(game_state, skill_id, level, target, now) do
      {:ok, _prepared} -> :ok
      {:error, _reason} = error -> error
    end
  end

  def preflight_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

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
  @spec complete_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()} | {:deferred, PlayerState.t(), term()} | {:error, atom()}
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
        ) :: {:ok, PlayerState.t()} | {:deferred, PlayerState.t(), term()} | {:error, atom()}
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

  defp complete_prepared_cast(game_state, skill_id, level, target, input, now, prepared) do
    %{
      definition: definition,
      module: module,
      cost: cost,
      commitment: commitment,
      zeny: zeny
    } = prepared

    apply_act_delay = Enum.at(definition.after_cast_delay, level - 1) not in [nil, 0]
    after_cast_delay = resolved_after_cast_delay(game_state, definition, level)
    definition = put_resolved_combo_delay(definition, level, after_cast_delay)

    complete_resolved_cast(
      game_state,
      module,
      target,
      level,
      definition,
      %{
        commitment: commitment,
        cost: cost,
        zeny: zeny,
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
         {:ok, commitment} <- Cost.prepare(game_state, deferred.cost),
         :ok <- check_zeny(game_state, deferred.zeny),
         :ok <- check_catalysts(game_state, definition),
         :ok <- check_ammo(game_state, definition) do
      {:ok,
       game_state
       |> Cost.apply_commitment(commitment)
       |> deduct_zeny(deferred.zeny)
       |> consume_catalysts(definition)
       |> consume_ammo(definition)
       |> put_cooldown(deferred.skill_id, definition, deferred.level, now)
       |> put_act_delay(definition, deferred.level, now)}
    end
  end

  @doc """
  Runs a status-driven auto-cast: the restricted entry SA_AUTOSPELL's proc uses.

  Deliberately not `complete_cast/4`. rAthena's proc jumps straight to
  `skill_castend_*` (battle.cpp:7502-7526) and so skips everything a player cast
  earns: no cast time, no learned/range/cooldown/act-delay check, no catalyst or
  ammo consumption, and no cooldown written. What it keeps is the SP charge -
  fixed at 2/3 of the bolt's raw cost, with `skill_get_sp` read straight from the
  db, so caster `sp_cost_rate` sources deliberately do not apply - and the bolt's
  aftercast delay.

  Insufficient SP returns `{:error, :insufficient_sp}` and runs nothing, which the
  caller drops silently: rAthena's `status_charge` failing simply skips the proc,
  with no message to the player.

  A ground bolt (Thunderstorm, Heaven's Drive) is cast at the victim's cell,
  mirroring rAthena's `skill_get_casttype` switch to `skill_castend_pos2`.
  """
  @spec auto_cast(PlayerState.t(), integer(), pos_integer(), Active.target()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def auto_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         {:ok, module} <- fetch_active_module(definition),
         {:ok, resolved} <- resolve_auto_cast_target(definition, target),
         cost = auto_cast_sp_cost(definition, level),
         :ok <- check_sp(game_state, cost),
         {:ok, game_state} <-
           run_unconditional(module, game_state, resolved, level, definition, :auto) do
      {:ok,
       game_state
       |> deduct_sp(cost)
       |> put_act_delay(definition, level, now)}
    end
  end

  def auto_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  @doc """
  Runs an item-triggered cast: the restricted entry `itemskill` uses.

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
  def item_cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
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

  def item_cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

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
           commitment: commitment,
           cost: cost,
           zeny: zeny,
           skill_id: skill_id,
           level: level,
           apply_act_delay: apply_act_delay,
           after_cast_delay: after_cast_delay,
           now: now,
           input: input
         }
       ) do
    case run_cast(module, game_state, target, level, definition, input) do
      {:deferred, game_state, descriptor} ->
        {:deferred, game_state,
         %Deferred{
           effect: descriptor,
           cost: cost,
           zeny: zeny,
           skill_id: skill_id,
           level: level,
           target: target
         }}

      {:ok, game_state} ->
        {:ok,
         game_state
         |> Cost.apply_commitment(commitment)
         |> deduct_zeny(zeny)
         |> consume_ammo(definition)
         |> put_cooldown(skill_id, definition, level, now)
         |> put_resolved_act_delay(apply_act_delay, after_cast_delay, now)}

      {:error, _reason} = error ->
        error
    end
  end

  defp put_resolved_combo_delay(%{id: skill_id} = definition, level, delay)
       when skill_id in [272, 273] do
    %{
      definition
      | after_cast_delay: List.replace_at(definition.after_cast_delay, level - 1, delay)
    }
  end

  defp put_resolved_combo_delay(definition, _level, _delay), do: definition

  defp validate_cast(game_state, skill_id, level, target, now) do
    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_learned(game_state, skill_id, level),
         :ok <- check_quest_lineage(game_state, definition),
         :ok <- check_target(game_state, target, definition),
         :ok <- check_range(game_state, target, definition, level),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- check_cooldown(game_state, skill_id, now),
         :ok <- check_act_delay(game_state, now),
         :ok <- module.validate(game_state, target, level, definition) do
      prepare_cast(game_state, module, target, level, definition)
    end
  end

  defp validate_completion(game_state, skill_id, level, target) do
    with {:ok, definition} <- fetch_definition(skill_id),
         {:ok, module} <- fetch_active_module(definition),
         :ok <- check_quest_lineage(game_state, definition),
         :ok <- check_target(game_state, target, definition),
         :ok <- check_range(game_state, target, definition, level),
         :ok <- module.validate(game_state, target, level, definition) do
      prepare_cast(game_state, module, target, level, definition)
    end
  end

  defp prepare_cast(game_state, module, target, level, definition) do
    with {:ok, cost} <- resolve_cost(game_state, module, target, level, definition),
         {:ok, commitment} <- Cost.prepare(game_state, cost),
         zeny = Enum.at(definition.zeny_cost, level - 1, 0),
         :ok <- check_zeny(game_state, zeny),
         :ok <- check_catalysts(game_state, definition),
         :ok <- check_ammo(game_state, definition) do
      {:ok,
       %{
         definition: definition,
         module: module,
         cost: cost,
         commitment: commitment,
         zeny: zeny
       }}
    end
  end

  @spec schedule(
          CastTime.result(),
          PlayerState.t(),
          integer(),
          pos_integer(),
          Active.target(),
          map()
        ) ::
          {:instant, PlayerState.t()}
          | {:deferred, PlayerState.t(), term()}
          | {:casting, PlayerState.t(), cast_info()}
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
      {:ok, game_state} -> {:instant, game_state}
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

  defp fetch_definition(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp check_max_level(definition, level) when level <= definition.max_level, do: :ok
  defp check_max_level(_definition, _level), do: {:error, :invalid_level}

  defp check_castable(%{target_type: :passive}), do: {:error, :passive_skill}
  defp check_castable(_definition), do: :ok

  defp fetch_active_module(definition) do
    case Catalog.active_module_for(definition.name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_behavior}
    end
  end

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

  # A target that cannot be resolved falls through so `check_range` reports it
  # as `:target_not_found`. A skill-unit cell (Ice Wall, etc.) is accepted
  # without a `Targeting.validate_enemy` call: `unit_type_of/1` only reports
  # `:skill_unit` for a cell the registry already confirmed is targetable, so
  # it is a valid enemy target by construction.
  defp check_target(_game_state, {:unit, target_id}, %{target_type: :target_enemy}) do
    with :ok <- ensure_living_target(target_id) do
      case unit_type_of(target_id) do
        :mob -> :ok
        :skill_unit -> :ok
        :player -> {:error, :invalid_target}
        :not_found -> :ok
      end
    end
  end

  defp check_target(_game_state, {:unit, target_id}, %{target_type: target_type})
       when target_type in [:target_ally, :target_any],
       do: ensure_living_target(target_id)

  defp check_target(_game_state, {:unit, target_id}, %{target_type: :target_corpse}),
    do: ensure_corpse_target(target_id)

  defp check_target(_game_state, {:unit, target_id}, %{target_type: :target_resurrection}),
    do: ensure_resurrection_target(target_id)

  defp check_target(_game_state, {:ground, _x, _y}, %{target_type: :ground}), do: :ok

  defp check_target(_game_state, :self, _definition), do: :ok
  defp check_target(%{character_id: caster_id}, {:unit, caster_id}, _definition), do: :ok
  defp check_target(_game_state, _target, _definition), do: {:error, :invalid_target}

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
  @spec effective_range(Definition.t(), PlayerState.t(), non_neg_integer()) :: non_neg_integer()
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

  defp weapon_range(%{stats: %{equipment: equipment}}) do
    equipment
    |> PlayerStats.weapon_type()
    |> WeaponTypes.get_attack_range()
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

  defp check_act_delay(game_state, now) do
    if PlayerState.act_ready?(game_state, now), do: :ok, else: {:error, :act_delayed}
  end

  defp check_sp(game_state, cost) do
    if game_state.stats.current_state.sp >= cost, do: :ok, else: {:error, :insufficient_sp}
  end

  defp resolve_cost(game_state, module, target, level, definition) do
    cost =
      if function_exported?(module, :dynamic_cost, 4) do
        module.dynamic_cost(game_state, target, level, definition)
      else
        Cost.from_definition(game_state, definition, level,
          sp: skill_sp_cost(game_state, definition, level)
        )
      end

    Cost.validate_resolved(cost)
  end

  # SP cost after the caster's summed `sp_cost_rate` delta (negative = cheaper,
  # summing the status sources with the global and per-skill equipment rates)
  # and the caster's per-skill equipment `{:skill_use_sp, id}`
  # flat reduction. The rate floors the multiplier at 0 so a stacked over-100%
  # reduction cannot invert the cost; the flat reduction is subtracted after the
  # percent step and the final cost is floored at 0. Computed once per cast site
  # so check_sp/deduct_sp both see the same reduced value (single application).
  @spec skill_sp_cost(PlayerState.t(), Definition.t(), pos_integer()) :: non_neg_integer()
  defp skill_sp_cost(game_state, definition, level) do
    case Enum.at(definition.sp_cost, level - 1, 0) do
      :all -> game_state.stats.current_state.sp
      _cost -> reduced_skill_sp_cost(game_state, definition, level)
    end
  end

  defp reduced_skill_sp_cost(game_state, definition, level) do
    cost = Enum.at(definition.sp_cost, level - 1)

    rate =
      merged_modifier(game_state.character_id, :sp_cost_rate) +
        equip_modifier(game_state, :sp_cost_rate) +
        equip_modifier(game_state, {:skill_use_sp_rate, definition.id})

    reduced = div(cost * max(0, 100 + rate), 100)
    flat = equip_modifier(game_state, {:skill_use_sp, definition.id})
    max(0, reduced - flat)
  end

  # Reads a single summed key from the caster's merged status modifiers,
  # defaulting to 0 when no active status contributes it.
  @spec merged_modifier(integer(), atom()) :: integer()
  defp merged_modifier(character_id, key) do
    :player
    |> ModifierCalculator.get_all_modifiers(character_id)
    |> Map.get(key, 0)
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

  # A zero cost is always allowed without reading game_state.zeny: every skill
  # defaults to zeny_cost: [], so the common path must not require a :zeny key
  # (bare-map game_state fixtures in the test suite would otherwise raise).
  defp check_zeny(_game_state, 0), do: :ok

  defp check_zeny(game_state, cost) do
    if game_state.zeny >= cost, do: :ok, else: {:error, :insufficient_zeny}
  end

  # Verifies the caster holds every declared catalyst (summed across stacks)
  # before the behavior runs, so a failed catalyst check spends no SP.
  defp check_catalysts(game_state, %{item_cost: item_cost}) do
    if Enum.all?(item_cost, fn %{id: id, amount: amount} ->
         Inventory.held_amount(game_state.inventory, id) >= amount
       end) do
      :ok
    else
      {:error, :missing_catalyst}
    end
  end

  # Verifies an arrow is equipped before the behavior runs, so a failed ammo
  # check spends no SP (mirrors check_catalysts). Non-ammo skills always pass.
  defp check_ammo(game_state, definition) do
    if definition.requires_ammo and Ammo.equipped_ammo_index(game_state.inventory) == nil do
      {:error, :no_ammo}
    else
      :ok
    end
  end

  # Removes one equipped arrow on a successful cast, recording the change on
  # `:pending_inventory_persist` for the handler to write through (same shape as
  # consume_catalysts). Non-ammo skills are a no-op.
  defp consume_ammo(game_state, definition) do
    if definition.requires_ammo do
      take_one_arrow(game_state)
    else
      game_state
    end
  end

  defp take_one_arrow(game_state) do
    case Ammo.consume_one(game_state.inventory) do
      {:ok, new_inventory, change} ->
        game_state
        |> Map.put(:inventory, new_inventory)
        |> Map.update!(
          :pending_inventory_persist,
          &(&1 ++ [{game_state.inventory, new_inventory, change}])
        )

      {:error, _reason} ->
        game_state
    end
  end

  # Runs the behavior and, on a bare `{:ok, state}`, consumes the catalysts.
  # `{:ok, state, :no_consume}` completes the cast but spares them.
  defp run_cast(module, game_state, target, level, definition, input) do
    result =
      case input do
        {:with_input, value} ->
          if function_exported?(module, :cast_with_input, 5) do
            module.cast_with_input(game_state, target, level, definition, value)
          else
            invoke_cast(module, game_state, target, level, definition, :normal)
          end

        :without_input ->
          invoke_cast(module, game_state, target, level, definition, :normal)
      end

    case result do
      {:ok, game_state} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, consume_catalysts(game_state, definition)}

      {:ok, game_state, :no_consume} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, game_state}

      {:deferred, game_state, descriptor} ->
        {:deferred, game_state, descriptor}

      {:error, _reason} = error ->
        error
    end
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
      packet = %GroundSkill{
        skill_id: definition.id,
        src_id: game_state.character_id,
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

  # Purely removes each catalyst from `game_state.inventory`, accumulating the
  # per-step change descriptors onto `:pending_inventory_persist` for the
  # handler to write through (mirrors how deducted SP is persisted downstream).
  defp consume_catalysts(game_state, %{item_cost: item_cost}) do
    Enum.reduce(item_cost, game_state, fn %{id: id, amount: amount}, gs ->
      remove_item(gs, id, amount)
    end)
  end

  defp remove_item(game_state, _id, 0), do: game_state

  defp remove_item(game_state, id, amount) do
    case Inventory.stackable_index(game_state.inventory, id) do
      nil ->
        game_state

      index ->
        take = min(amount, game_state.inventory[index].amount)
        {:ok, new_inventory, change} = Inventory.remove(game_state.inventory, index, take)

        game_state
        |> Map.put(:inventory, new_inventory)
        |> Map.update!(
          :pending_inventory_persist,
          &(&1 ++ [{game_state.inventory, new_inventory, change}])
        )
        |> remove_item(id, amount - take)
    end
  end

  defp deduct_sp(game_state, cost) do
    stats = game_state.stats
    current = %{stats.current_state | sp: stats.current_state.sp - cost}
    %{game_state | stats: %{stats | current_state: current}}
  end

  defp deduct_zeny(game_state, 0), do: game_state
  defp deduct_zeny(game_state, cost), do: %{game_state | zeny: game_state.zeny - cost}

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

  # After-cast act delay (AfterCastActDelay) reduced by delay-rate sources
  # (Bragi `:delay_reduction`), not ASPD, then scaled by the caster's equipment
  # `:delay_rate` (`bDelayrate`, a signed percent delta where negative is less
  # delay). Equipment applies as its own multiplicative step so it never
  # compounds additively with the status reductions. Floors the delay at 0.
  defp put_resolved_act_delay(game_state, false, _delay, _now), do: game_state

  defp put_resolved_act_delay(game_state, true, delay, now),
    do: %{game_state | act_delay_until: now + delay}

  defp put_act_delay(game_state, definition, level, now) do
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
