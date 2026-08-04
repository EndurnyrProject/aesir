defmodule Aesir.ZoneServer.Mmo.MobSkill.Executor do
  @moduledoc """
  Turns a selected mob-skill row into a concrete effect.

  `resolve_target/2` maps the row's rAthena `target` code onto a live target
  (`{:unit, type, id}` or `{:ground, x, y, area}`); `execute/2` then dispatches
  through the real skill catalog: `Skill.Catalog.by_id/1` resolves the row's
  `skill_id` to its `Definition`, `Skill.Catalog.active_module_for/1` resolves
  the definition's name to its `Skill.Active` module. A skill unresolvable at
  either step is a no-op `:ok` — rare once the `Selector` gates on the same
  lookup, but still reachable on a target-invalidation race.

  A resolved module runs its `validate/4` (auto-defaulted to `:ok` by `use
  Skill` when the skill does not define one) against the row's adapted target,
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
  (e.g. `Combat.execute_magic_damage/4`) broadcast their own `SkillDamage`
  packets, so this module broadcasts only the mob cast bar — `SkillCasting` via
  `broadcast_casting/2` and its `CastCancel` counterpart via
  `broadcast_cast_cancel/1`.
  """

  require Logger

  alias Aesir.Net.CastCancel
  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @around_self [:around, :around1, :around2, :around3, :around4]
  @around_target [:around5, :around6, :around7, :around8]

  @typedoc "A resolved cast target: a concrete unit or a ground cell."
  @type target ::
          {:unit, :player | :mob | :homunculus, integer()}
          | {:ground, integer(), integer(), atom()}

  @doc """
  Resolves the row's `target` code against the live world.

  `around`/`around1..4` anchor the ground cell on the caster, `around5..8` on
  the current target's cell (rAthena semantics); the `area` atom is passed
  through for the ground-target skill to size the AoE.
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

  def resolve_target(%MobState{} = state, %{target: :friend}) do
    case lowest_hp_friend(state) do
      nil -> {:error, :no_friend}
      friend_id -> {:ok, {:unit, :mob, friend_id}}
    end
  end

  def resolve_target(%MobState{} = state, %{target: :randomtarget}) do
    case player_side_units_in_skill_range(state) do
      [] ->
        {:error, :no_target}

      targets ->
        {unit_type, unit_id} = Enum.random(targets)
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
  Resolves the row's target and dispatches to its skill module.

  Target invalidation, a failed `validate/4`, and a `cast/4`/`mob_cast/5`
  error surface as `{:error, reason}` — a clean abort, never a crash. A skill
  unresolvable in the catalog is a no-op `:ok`.
  """
  @spec execute(MobState.t(), map()) :: :ok | {:error, term()}
  def execute(%MobState{} = state, row) do
    with {:ok, target} <- resolve_target(state, row) do
      maybe_emote(state, row)
      dispatch(state, target, row)
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

  defp dispatch(state, target, row) do
    with {:ok, definition} <- SkillCatalog.by_id(row.skill_id),
         {:ok, module} <- SkillCatalog.active_module_for(definition.name) do
      run(module, state, target, row, definition)
    else
      :error ->
        Logger.debug("MobSkill: #{row.skill} (#{row.skill_id}) has no active module, skipping")
        :ok
    end
  end

  defp run(module, state, target, row, definition) do
    with {:ok, adapted_target} <- adapt_target(target, definition, state),
         :ok <- module.validate(state, adapted_target, row.level, definition) do
      module
      |> invoke(state, target, adapted_target, row, definition)
      |> collapse()
    end
  end

  defp invoke(module, state, raw_target, adapted_target, row, definition) do
    cond do
      function_exported?(module, :mob_cast, 5) ->
        module.mob_cast(state, raw_target, row.level, definition, row)

      function_exported?(module, :cast_with_origin, 5) ->
        module.cast_with_origin(state, adapted_target, row.level, definition, :mob)

      true ->
        module.cast(state, adapted_target, row.level, definition)
    end
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

  defp lowest_hp_friend(%MobState{} = state) do
    :mob
    |> SpatialIndex.get_units_in_range(state.map_name, state.x, state.y, skill_range(state))
    |> Enum.reject(&(&1 == state.instance_id))
    |> Enum.flat_map(fn id ->
      case UnitRegistry.get_unit(:mob, id) do
        {:ok, {_module, %MobState{mob_id: mob_id} = friend, _pid}}
        when mob_id == state.mob_id ->
          living_friend(friend)

        _other ->
          []
      end
    end)
    |> Enum.min_by(& &1.hp, fn -> nil end)
    |> then(fn
      nil -> nil
      friend -> friend.instance_id
    end)
  end

  defp living_friend(friend) do
    if Unit.living?(friend), do: [friend], else: []
  end

  defp player_side_units_in_skill_range(%MobState{} = state) do
    [:player, :homunculus]
    |> Enum.flat_map(fn unit_type ->
      unit_type
      |> SpatialIndex.get_units_in_range(state.map_name, state.x, state.y, skill_range(state))
      |> Enum.filter(&living_unit?(unit_type, &1))
      |> Enum.map(&{unit_type, &1})
    end)
  end

  defp living_unit?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end

  defp skill_range(%MobState{mob_data: mob_data}), do: mob_data.skill_range
end
