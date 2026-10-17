defmodule Aesir.ZoneServer.Mmo.MobSkill.Executor do
  @moduledoc """
  Turns a selected mob-skill row into a concrete effect.

  `resolve_target/2` maps the row's rAthena `target` code onto a live target
  (`{:unit, type, id}` or `{:ground, x, y, area}`); `execute/3` then dispatches
  through the real skill catalog: `Skill.Catalog.by_id/1` resolves the row's
  `skill_id` to its `Definition`, `Skill.Catalog.active_module_for/1` resolves
  the definition's name to its `Skill.Active` module. A skill unresolvable at
  either step is a no-op `:ok` — rare once the `Selector` gates on the same
  lookup, but still reachable on a target-invalidation race.

  A resolved module runs its `validate/4` (auto-defaulted to `:ok` by `use
  Skill` when the skill does not define one) against the row's adapted target,
  after a unit target passed the concealment check for the cast `phase`
  (`:cast_begin` for an instant cast, `:cast_end` when a cast bar completes),
  then `mob_cast/5` when the module exports it, otherwise `cast/4`.
  `validate/4` and `cast/4` always see the same *adapted* target; `mob_cast/5`
  always sees the *raw*, unadapted one plus the full row — a skill exporting
  both must not expect the two calls to agree on shape.

  Adaptation depends on the resolved skill's `target_type`: a `:ground` skill
  centers its cell on a unit-shaped raw target (`mob_skills.yml` routinely
  gives ground skills a `target`/`self`/`friend`/`randomtarget` row - "center
  the ground effect on my target" - e.g. `SA_LANDPROTECTOR`, `PR_SANCTUARY`,
  `WZ_METEOR`) - the caster's own cell for a self-target, `SpatialIndex` for
  anyone else, `{:error, :no_target}` if that unit's cell cannot be resolved.
  Other unit skills retain a typed Homunculus ref while legacy player and mob
  targets remain bare IDs; ground targets become `{:ground, x, y}`.

  Packet ownership: the combat primitives a skill's `cast/4`/`mob_cast/5` calls
  (e.g. `Combat.execute_magic_attack/3`) broadcast their own `SkillDamage`
  packets, so this module broadcasts only the mob cast bar — `SkillCasting` via
  `broadcast_casting/2` and its `CastCancel` counterpart via
  `broadcast_cast_cancel/1`.
  """

  require Logger

  alias Aesir.Net.CastCancel
  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.Relationship
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.PlacementCheck
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @around_self [:around, :around1, :around2, :around3, :around4]
  @around_target [:around5, :around6, :around7, :around8]
  @mob_scope %{invocation: :mob, autocast_flag?: false}
  @friend_range 8
  @max_random_targets 30

  @typedoc "A resolved cast target: a concrete unit or a ground cell."
  @type target ::
          {:unit, :player | :mob | :homunculus, integer()}
          | {:ground, integer(), integer(), atom()}

  @doc """
  Resolves the row's `target` code against the live world.

  `around`/`around1..4` anchor the ground cell on the caster, `around5..8` on
  the current target's cell (rAthena semantics); the `area` atom is passed
  through for the ground-target skill to size the AoE. `friend` is the friend
  the row's `friendhpltmaxrate`/`friendhpinrate` condition finds
  (`hp_rate_friend/3`), otherwise the caster itself. `randomtarget` rolls one
  of the first 30 living player-side units in the skill-range square, taken in
  the map's block order.
  """
  @spec resolve_target(MobState.t(), map()) :: {:ok, target()} | {:error, atom()}
  def resolve_target(%MobState{target_ref: nil}, %{target: :target}), do: {:error, :no_target}

  def resolve_target(%MobState{target_ref: {type, id}}, %{target: :target}) do
    if living_unit?(type, id), do: {:ok, {:unit, type, id}}, else: {:error, :no_target}
  end

  def resolve_target(%MobState{instance_id: id}, %{target: :self}), do: {:ok, {:unit, :mob, id}}

  def resolve_target(%MobState{master_id: nil}, %{target: :master}), do: {:error, :no_master}

  def resolve_target(%MobState{master_id: master_id}, %{target: :master}) do
    if living_unit?(:mob, master_id),
      do: {:ok, {:unit, :mob, master_id}},
      else: {:error, :no_master}
  end

  def resolve_target(%MobState{} = state, %{target: :friend} = row) do
    case condition_friend(state, Map.get(row, :condition)) do
      nil -> {:ok, {:unit, :mob, state.instance_id}}
      {unit_type, unit_id} -> {:ok, {:unit, unit_type, unit_id}}
    end
  end

  def resolve_target(%MobState{} = state, %{target: :randomtarget}) do
    case random_targets(state) do
      [] ->
        {:error, :no_target}

      targets ->
        {unit_type, unit_id} = Enum.at(targets, :rand.uniform(length(targets)) - 1)
        {:ok, {:unit, unit_type, unit_id}}
    end
  end

  def resolve_target(%MobState{x: x, y: y}, %{target: area}) when area in @around_self,
    do: {:ok, {:ground, x, y, area}}

  def resolve_target(%MobState{target_ref: nil}, %{target: area}) when area in @around_target,
    do: {:error, :no_target}

  def resolve_target(%MobState{target_ref: {type, id}}, %{target: area})
      when area in @around_target do
    if living_unit?(type, id) do
      case SpatialIndex.get_unit_position(type, id) do
        {:ok, {x, y, _map}} -> {:ok, {:ground, x, y, area}}
        {:error, :not_found} -> {:error, :no_target}
      end
    else
      {:error, :no_target}
    end
  end

  def resolve_target(%MobState{}, %{target: other}), do: {:error, {:unsupported_target, other}}

  @doc """
  Shows the row's emotion, then resolves its target and dispatches to its skill
  module. The emotion shows even when the cast then fails. At `:cast_end` (a
  timed cast completing) the mob's own state is checked before the skill runs
  (`Targeting.validate_cast_completion/3`).

  Target invalidation, a caster that can no longer complete the cast, a failed
  `validate/4`, and a `cast/4`/`mob_cast/5`
  error surface as `{:error, reason}` — a clean abort, never a crash. A skill
  unresolvable in the catalog is a no-op `:ok`.
  """
  @spec execute(MobState.t(), map(), Targeting.skill_use_phase()) :: :ok | {:error, term()}
  def execute(%MobState{} = state, row, phase \\ :cast_begin) do
    maybe_emote(state, row)

    with {:ok, target} <- resolve_target(state, row) do
      dispatch(state, target, row, phase)
    end
  end

  @doc """
  Checks that the row's resolved unit target is not concealed from the mob at
  `phase` (`Targeting.validate_skill_use/4`); a ground target or ground skill
  (checked without a target), a target that cannot be resolved or a skill
  missing from the catalog passes, since `execute/3` reports those itself.
  """
  @spec check_target(MobState.t(), map(), Targeting.skill_use_phase()) :: :ok | {:error, term()}
  def check_target(%MobState{} = state, row, phase) do
    with {:ok, target} <- resolve_target(state, row),
         {:ok, definition} <- SkillCatalog.by_id(row.skill_id) do
      check_concealment(state, target, definition, phase)
    else
      _unresolved -> :ok
    end
  end

  @doc """
  Broadcasts the `SkillCasting` cast bar from the caster's cell.

  `property` carries the skill's element id when the catalog defines one (the
  client colors the bar by it); the unit-target/x-y convention mirrors the
  player cast bar (`target_id` for unit casts, zeroed coordinates).
  """
  @spec broadcast_casting(MobState.t(), map()) :: :ok
  def broadcast_casting(%MobState{} = state, row) do
    packet = %SkillCasting{
      src_id: state.instance_id,
      target_id: target_id(state.target_ref),
      x: 0,
      y: 0,
      skill_id: row.skill_id,
      property: property(row.skill_id),
      cast_time: row.cast_time
    }

    Broadcast.to_in_range(state.map_name, state.x, state.y, Config.view_range(), packet)
  end

  @doc """
  Broadcasts the `CastCancel` that clears the cast bar `broadcast_casting/2` put up.

  Every mob cast abort routes here (status effects that interrupt skill use
  and the forced `MobSession.interrupt_cast/1`), so an aborted cast never leaves the bar
  running on the client. Unlike the player cancel there is no separate
  self-directed send: a mob has no session of its own to notify.
  """
  @spec broadcast_cast_cancel(MobState.t()) :: :ok
  def broadcast_cast_cancel(%MobState{} = state) do
    packet = %CastCancel{gid: state.instance_id}

    Broadcast.to_in_range(state.map_name, state.x, state.y, Config.view_range(), packet)
  end

  defp target_id(nil), do: 0
  defp target_id({_type, id}), do: id

  defp maybe_emote(%MobState{instance_id: instance_id}, row) do
    case Map.get(row, :emotion) do
      nil -> :ok
      emotion -> Emote.show({:mob, instance_id}, emotion)
    end
  end

  defp dispatch(state, target, row, phase) do
    with {:ok, definition} <- SkillCatalog.by_id(row.skill_id),
         {:ok, module} <- SkillCatalog.active_module_for(definition.name) do
      run(module, state, target, row, definition, phase)
    else
      :error ->
        Logger.debug("MobSkill: #{row.skill} (#{row.skill_id}) has no active module, skipping")
        :ok
    end
  end

  defp run(module, state, target, row, definition, phase) do
    with :ok <- check_support_status(state, definition),
         :ok <- check_completion_caster(state, definition, phase),
         :ok <- check_concealment(state, target, definition, phase),
         {:ok, adapted_target} <- adapt_target(target, definition, state),
         :ok <- check_placement(state, definition, adapted_target),
         :ok <- module.validate(state, adapted_target, row.level, definition),
         :ok <- check_castend_target(state, target, definition) do
      module
      |> invoke(state, target, adapted_target, row, definition)
      |> collapse()
    end
  end

  defp check_support_status(state, %{target_type: type})
       when type in [:target_ally, :target_any] do
    if StatusInterpreter.support_blocked?(:mob, state.instance_id),
      do: {:error, :status_blocked},
      else: :ok
  end

  defp check_support_status(_state, _definition), do: :ok

  defp check_completion_caster(state, definition, :cast_end),
    do: Targeting.validate_cast_completion(concealment_caster(state), definition)

  defp check_completion_caster(_state, _definition, _phase), do: :ok

  defp check_concealment(_state, _target, %{target_type: :ground}, _phase), do: :ok

  defp check_concealment(state, {:unit, type, id}, definition, phase) do
    Targeting.validate_skill_use(
      concealment_caster(state),
      %{unit_type: type, unit_id: id},
      definition,
      phase
    )
  end

  defp check_concealment(_state, _target, _definition, _phase), do: :ok

  defp concealment_caster(%MobState{instance_id: id, mob_data: mob_data}) do
    modes = (mob_data && mob_data.modes) || []

    %{
      unit_type: :mob,
      unit_id: id,
      class: MobMode.class(modes),
      detector: :detector in modes
    }
  end

  # A ground cast end checks the unit placement as a monster: only a unit
  # already reiterated in the area refuses it.
  defp check_placement(%MobState{} = state, definition, {:ground, x, y}),
    do: PlacementCheck.check(definition, {:mob, state.instance_id}, state.map_name, {x, y}, :mob)

  defp check_placement(_state, _definition, _target), do: :ok

  defp check_castend_target(%MobState{instance_id: caster_id}, {:unit, type, id}, definition) do
    cond do
      Targeting.castend_refused?({:mob, caster_id}, {:unit, {type, id}}, definition) ->
        {:error, :target_invincible}

      Targeting.fogged_out?({:unit, {type, id}}, definition) ->
        {:error, :fogged_out}

      true ->
        :ok
    end
  end

  defp check_castend_target(_state, _target, _definition), do: :ok

  defp invoke(module, state, raw_target, adapted_target, row, definition) do
    Origin.with_skill(definition.name, {:mob, state.instance_id}, @mob_scope, fn ->
      cond do
        function_exported?(module, :mob_cast, 5) ->
          module.mob_cast(state, raw_target, row.level, definition, row)

        function_exported?(module, :cast_with_origin, 5) ->
          module.cast_with_origin(state, adapted_target, row.level, definition, :mob)

        true ->
          module.cast(state, adapted_target, row.level, definition)
      end
    end)
  end

  defp adapt_target({:unit, unit_type, id}, %{target_type: :ground}, state),
    do: ground_center(unit_type, id, state)

  defp adapt_target({:unit, :homunculus, id}, _definition, _state),
    do: {:ok, {:unit, {:homunculus, id}}}

  defp adapt_target({:unit, _unit_type, id}, _definition, _state), do: {:ok, {:unit, id}}
  defp adapt_target({:ground, x, y, _area}, _definition, _state), do: {:ok, {:ground, x, y}}

  defp ground_center(:mob, id, %MobState{instance_id: id, x: x, y: y}), do: {:ok, {:ground, x, y}}

  defp ground_center(unit_type, id, _state) do
    case SpatialIndex.get_unit_position(unit_type, id) do
      {:ok, {x, y, _map}} -> {:ok, {:ground, x, y}}
      {:error, :not_found} -> {:error, :no_target}
    end
  end

  defp collapse(:ok), do: :ok
  defp collapse({:ok, _state}), do: :ok
  defp collapse({:ok, _state, :no_consume}), do: :ok
  defp collapse({:error, _reason} = error), do: error

  defp property(skill_id) do
    case SkillCatalog.by_id(skill_id) do
      {:ok, definition} -> ElementModifiers.id(definition.element)
      :error -> 0
    end
  end

  defp condition_friend(state, %{type: :friendhpltmaxrate, value: max_rate}),
    do: hp_rate_friend(state, 0, max_rate)

  defp condition_friend(state, %{type: :friendhpinrate, value: min_rate, val1: max_rate}),
    do: hp_rate_friend(state, min_rate, max_rate)

  defp condition_friend(_state, _condition), do: nil

  @doc """
  The friend a `friendhpltmaxrate`/`friendhpinrate` row finds: within 8 cells
  of the caster in the map's block order, the first unit other than the caster
  that is not its enemy and whose HP rate (`100 * (hp / max_hp)` as a
  double, truncated) lies in `min_rate..max_rate`. A player-owned summon looks
  among players, siding with its owner (players are never its enemies), any
  other monster among monsters. A dead player still counts
  (at 0%); a dead monster has left the map. `nil` when none qualifies.
  """
  @spec hp_rate_friend(MobState.t(), integer(), integer()) :: {:player | :mob, integer()} | nil
  def hp_rate_friend(%MobState{} = state, min_rate, max_rate) do
    {unit_type, caster} =
      if state.owner_player_id,
        do: {:player, :summon},
        else: {:mob, MobState.to_combatant(state)}

    state.map_name
    |> SpatialIndex.units_in_area(
      state.x - @friend_range,
      state.y - @friend_range,
      state.x + @friend_range,
      state.y + @friend_range
    )
    |> Enum.find(fn {type, _id} = ref ->
      type == unit_type and ref != {:mob, state.instance_id} and
        friend_in_rate?(caster, ref, min_rate, max_rate)
    end)
  end

  defp friend_in_rate?(caster, {unit_type, unit_id}, min_rate, max_rate) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {module, unit, _pid}} ->
        on_map?(unit) and not enemy?(caster, module, unit) and
          rate_within?(hp_rate(unit), min_rate, max_rate)

      {:error, :not_found} ->
        false
    end
  end

  defp enemy?(:summon, PlayerState, _player), do: false
  defp enemy?(caster, module, unit), do: Relationship.enemy?(caster, module.to_combatant(unit))

  defp on_map?(%MobState{} = mob), do: Unit.living?(mob)
  defp on_map?(%PlayerState{}), do: true

  defp hp_rate(%MobState{hp: hp, max_hp: max_hp}), do: percentage(hp, max_hp)

  defp hp_rate(%PlayerState{stats: stats}),
    do: percentage(stats.current_state.hp, stats.derived_stats.max_hp)

  defp percentage(_hp, max_hp) when max_hp <= 0, do: nil
  defp percentage(hp, max_hp), do: trunc(100 * (hp / max_hp))

  defp rate_within?(nil, _min_rate, _max_rate), do: false
  defp rate_within?(rate, min_rate, max_rate), do: rate >= min_rate and rate <= max_rate

  # The living enemies the random roll indexes: the player side within the
  # skill range square, in the map's block order, at most the first 30.
  defp random_targets(%MobState{} = state) do
    range = skill_range(state)

    state.map_name
    |> SpatialIndex.units_in_area(
      state.x - range,
      state.y - range,
      state.x + range,
      state.y + range
    )
    |> Enum.filter(fn {unit_type, unit_id} ->
      unit_type in [:player, :homunculus] and living_unit?(unit_type, unit_id)
    end)
    |> Enum.take(@max_random_targets)
  end

  defp living_unit?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end

  defp skill_range(%MobState{mob_data: mob_data}), do: mob_data.skill_range
end
