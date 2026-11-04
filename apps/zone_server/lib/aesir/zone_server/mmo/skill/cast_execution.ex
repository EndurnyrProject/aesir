defmodule Aesir.ZoneServer.Mmo.Skill.CastExecution do
  @moduledoc """
  Runs a skill's behavior for a validated cast and the effects that frame it:
  the cast-start reactions (ending the caster's attack, the adapter's
  `on_cast_start`, the cast-targeted event to a monster), the invocation
  under the skill's `Origin` scope, the combo settlement after a skill attack,
  and the cast animation of a ground skill that places no unit.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.GroundSkill
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.MobSkill.Event, as: MobSkillEvent
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastConditions
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @typedoc "How the cast reached the behavior: an ordinary cast or a staged input."
  @type input :: :without_input | {:with_input, term()}

  @doc """
  Runs the behavior for an ordinary cast end: the invocation collects its
  skill attacks for the combo settlement, and the outcome is validated and
  tagged with whether its catalysts are consumed.
  """
  @spec run_cast(
          module(),
          Active.caster(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          atom(),
          input(),
          module()
        ) :: term()
  def run_cast(module, caster, target, level, definition, origin, input, adapter) do
    {result, attacked?} =
      Origin.collect_skill_attacks(fn ->
        invoke(module, caster, target, level, definition, origin, input)
      end)

    result
    |> settle_skill_attack(caster, adapter, attacked?)
    |> cast_outcome(module, target, level, definition, adapter)
  end

  @doc """
  Runs a behavior without `run_cast/8`'s catalyst consumption, shared by the
  auto-cast and item-cast entry points: both are free of the skill's declared
  requirements by construction, not by their skills happening to declare none
  today. `autocast_flag?` is set only by the equipment proc entry.
  """
  @spec run_unconditional(
          module(),
          Active.caster(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          atom(),
          boolean()
        ) :: term()
  def run_unconditional(module, game_state, target, level, definition, origin, autocast_flag?) do
    scope = %{invocation: origin, autocast_flag?: autocast_flag?}
    adapter = Caster.for(game_state)

    {result, attacked?} =
      Origin.collect_skill_attacks(fn ->
        invoke_cast(module, game_state, target, level, definition, scope)
      end)

    result =
      result
      |> settle_skill_attack(game_state, adapter, attacked?)
      |> without_catalyst_flag()

    case result do
      {:ok, game_state} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:ok, game_state}

      {:local_effects, game_state, effects} ->
        announce_ground_cast(module, game_state, target, level, definition)
        {:local_effects, game_state, effects}

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

  defp without_catalyst_flag({:ok, caster, :no_consume}), do: {:ok, caster}
  defp without_catalyst_flag(result), do: result

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

  defp announce_after_effect(:after_effect, module, caster, target, level, definition),
    do: announce_ground_cast(module, caster, target, level, definition)

  defp announce_after_effect(_variant, _module, _caster, _target, _level, _definition), do: :ok

  defp invoke_cast_with_input(module, caster, target, level, definition, value, origin) do
    Origin.with_skill(
      definition.name,
      CastConditions.caster_ref(caster),
      unflagged_scope(origin),
      fn ->
        module.cast_with_input(caster, target, level, definition, value)
      end
    )
  end

  # The skill sees the scope's invocation as its origin; only
  # `run_unconditional/7` builds a flagged scope.
  defp invoke_cast(module, game_state, target, level, definition, %{invocation: origin} = scope) do
    Origin.with_skill(definition.name, CastConditions.caster_ref(game_state), scope, fn ->
      if function_exported?(module, :cast_with_origin, 5) do
        module.cast_with_origin(game_state, target, level, definition, origin)
      else
        module.cast(game_state, target, level, definition)
      end
    end)
  end

  defp unflagged_scope(origin), do: %{invocation: origin, autocast_flag?: false}

  # A ground-targeted skill without the `Skill.Ground` capability (e.g.
  # Heaven's Drive) creates no unit group, so `Unit.place/4` never broadcasts
  # its cast animation; announce the execution point here. Unit-placing skills
  # skip this - their single `GroundSkill` comes from the group placement.
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

  @doc """
  A player's accepted cast at a monster tells that monster so, before the
  cast's own effects: the cast-targeted event at its cast start. Renewal
  fires it for every cast; pre-renewal only for a cast with a cast time or
  for a skill the reference forces to cast now.
  """
  @spec notify_cast_targeted(Active.caster(), Definition.t(), Active.target(), boolean()) :: :ok
  def notify_cast_targeted(%PlayerState{} = caster, definition, target, timed?) do
    if timed? or GameMode.mode() == :renewal or
         CastConditions.forced_cast?(definition, target) do
      MobSkillEvent.deliver_target(
        {:player, caster.character_id},
        :casttargeted,
        target,
        System.system_time(:millisecond)
      )
    end

    :ok
  end

  def notify_cast_targeted(_caster, _definition, _target, _timed?), do: :ok

  @doc """
  A cast that passed its checks, up to the range, ends its player's attack as
  it begins: the target and the pending swing are dropped. A combo with the
  attack's reach keeps the attack, timed or not; a swing falling inside its
  cast ends the attack then (`CombatActionHandler.handle_auto_attack/2`). A
  refused cast never reaches here.
  """
  @spec stop_attack_at_cast_start(Active.caster(), boolean()) :: Active.caster()
  def stop_attack_at_cast_start(%PlayerState{action_state: :attacking} = caster, false) do
    {:ok, idle} = PlayerState.transition_to(caster, :idle)
    idle
  end

  def stop_attack_at_cast_start(caster, _keeps_attack?), do: caster

  @doc """
  An input cast begins and ends at its input's completion, so its attack ends
  there, once its checks passed.
  """
  @spec begin_input_cast(Active.caster(), input()) :: Active.caster()
  def begin_input_cast(game_state, {:with_input, _value}),
    do: stop_attack_at_cast_start(game_state, false)

  def begin_input_cast(game_state, :without_input), do: game_state

  @doc """
  The cast-start effects of an instant cast run before its effect, as a timed
  cast's run when its cast bar starts (the caller's job for timed casts).
  """
  @spec cast_start(Active.caster(), module(), integer()) :: Active.caster()
  def cast_start(game_state, adapter, skill_id) do
    if function_exported?(adapter, :on_cast_start, 2),
      do: adapter.on_cast_start(game_state, skill_id),
      else: game_state
  end
end
