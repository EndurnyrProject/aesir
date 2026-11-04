defmodule Aesir.ZoneServer.Mmo.Skill.CastSettlement do
  @moduledoc """
  The cast end of a validated, cost-prepared cast: pays the primary
  requirement, runs the behavior, and settles whatever the outcome leaves to
  settle (items and ammo, cooldown, after-cast delay), by the outcome the
  reference gives each case: a success, a failure after the requirement, a
  use that ends without its effect, or a refusal that is paid for or not.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastConditions
  alias Aesir.ZoneServer.Mmo.Skill.CastExecution
  alias Aesir.ZoneServer.Mmo.Skill.CastPacing
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter.Deferred
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc """
  What a cast end carries into its settlement: the caster's adapter, the
  prepared cost, the skill and level, whether and how long the act delay
  arms, the clock, the input, and optionally an origin overriding the
  adapter's.
  """
  @type opts :: %{
          optional(:origin) => atom(),
          adapter: module(),
          prepared_cost: map(),
          skill_id: integer(),
          level: pos_integer(),
          apply_act_delay: boolean(),
          after_cast_delay: non_neg_integer(),
          now: integer(),
          input: CastExecution.input()
        }

  @doc """
  Pays the primary requirement and runs the behavior, then settles its
  outcome. The walk-path check and the dead-target early return run on the
  paid caster, before the behavior, as the reference orders them.
  """
  @spec complete_resolved_cast(
          Active.caster(),
          module(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          opts()
        ) :: term()
  def complete_resolved_cast(
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
      CastConditions.walk_path_blocked?(definition, game_state, target) ->
        settle_refusal(:projectile_blocked, context)

      CastConditions.dead_target_skip?(definition, target) ->
        {:skipped, settle_skipped(context), :target_dead}

      true ->
        result =
          CastExecution.run_cast(
            module,
            game_state,
            target,
            level,
            definition,
            origin,
            input,
            adapter
          )

        resolve_effect(result, context)
    end
  end

  @doc """
  A cast end refused by a cast-end check runs the skill's own failure
  reaction when it has one (`Active.castend_failed/4`); otherwise the refusal
  stays silent and spends nothing.
  """
  @spec castend_failure(Active.caster(), integer(), pos_integer(), Active.target(), atom()) ::
          {:castend_failed, PlayerState.t(), atom()} | {:error, atom()}
  def castend_failure(%PlayerState{} = game_state, skill_id, level, target, reason) do
    with {:ok, definition} <- CastConditions.fetch_definition(skill_id),
         {:ok, module} <- CastConditions.fetch_active_module(definition),
         true <- function_exported?(module, :castend_failed, 4),
         {:ok, failed} <- module.castend_failed(game_state, target, level, definition) do
      {:castend_failed, failed, reason}
    else
      _none -> {:error, reason}
    end
  end

  def castend_failure(_game_state, _skill_id, _level, _target, reason), do: {:error, reason}

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
    if CastConditions.player_target?(context.target), do: :skipped, else: :unpaid
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
    |> CastPacing.put_cooldown(adapter, opts.skill_id, definition, level, opts.now)
    |> CastPacing.rearm_cooldowns(module, level, definition, opts.now)
    |> CastPacing.put_resolved_act_delay(opts.apply_act_delay, opts.after_cast_delay, opts.now)
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
end
