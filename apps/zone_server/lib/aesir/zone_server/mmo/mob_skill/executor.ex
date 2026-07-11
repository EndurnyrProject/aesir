defmodule Aesir.ZoneServer.Mmo.MobSkill.Executor do
  @moduledoc """
  Turns a selected mob-skill row into a concrete effect.

  `resolve_target/2` maps the row's rAthena `target` code onto a live target
  (`{:unit, type, id}` or `{:ground, x, y, area}`); `execute/2` then dispatches
  to the archetype module the `Catalog` maps the skill to. Archetype modules are
  resolved dynamically (`:elemental_nuke` -> `Archetype.ElementalNuke`) and an
  archetype without a built module is skipped, keeping intermediate waves
  shippable while the archetype set grows.

  Packet ownership: the combat primitives the archetypes call (e.g.
  `Combat.execute_magic_damage/4`) broadcast their own `SkillDamage` packets, so
  this module broadcasts only the `SkillCasting` cast bar via
  `broadcast_casting/2`.
  """

  require Logger

  alias Aesir.Net.SkillCasting
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.MobSkill.Catalog
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Emote
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @archetype_namespace Aesir.ZoneServer.Mmo.MobSkill.Archetype

  @around_self [:around, :around1, :around2, :around3, :around4]
  @around_target [:around5, :around6, :around7, :around8]

  @typedoc "A resolved cast target: a concrete unit or a ground cell."
  @type target ::
          {:unit, :player | :mob, integer()} | {:ground, integer(), integer(), atom()}

  @doc """
  Resolves the row's `target` code against the live world.

  `around`/`around1..4` anchor the ground cell on the caster, `around5..8` on
  the current target's cell (rAthena semantics); the `area` atom is passed
  through for the ground archetype to size the AoE.
  """
  @spec resolve_target(MobState.t(), map()) :: {:ok, target()} | {:error, atom()}
  def resolve_target(%MobState{target_id: nil}, %{target: :target}), do: {:error, :no_target}

  def resolve_target(%MobState{target_id: target_id}, %{target: :target}),
    do: {:ok, {:unit, :player, target_id}}

  def resolve_target(%MobState{instance_id: id}, %{target: :self}), do: {:ok, {:unit, :mob, id}}

  def resolve_target(%MobState{master_id: nil}, %{target: :master}), do: {:error, :no_master}

  def resolve_target(%MobState{master_id: master_id}, %{target: :master}),
    do: {:ok, {:unit, :mob, master_id}}

  def resolve_target(%MobState{} = state, %{target: :friend}) do
    case lowest_hp_friend(state) do
      nil -> {:error, :no_friend}
      friend_id -> {:ok, {:unit, :mob, friend_id}}
    end
  end

  def resolve_target(%MobState{} = state, %{target: :randomtarget}) do
    case players_in_skill_range(state) do
      [] -> {:error, :no_target}
      players -> {:ok, {:unit, :player, Enum.random(players)}}
    end
  end

  def resolve_target(%MobState{x: x, y: y}, %{target: area}) when area in @around_self,
    do: {:ok, {:ground, x, y, area}}

  def resolve_target(%MobState{target_id: nil}, %{target: area}) when area in @around_target,
    do: {:error, :no_target}

  def resolve_target(%MobState{target_id: target_id}, %{target: area})
      when area in @around_target do
    case SpatialIndex.get_unit_position(:player, target_id) do
      {:ok, {x, y, _map}} -> {:ok, {:ground, x, y, area}}
      {:error, :not_found} -> {:error, :no_target}
    end
  end

  def resolve_target(%MobState{}, %{target: other}), do: {:error, {:unsupported_target, other}}

  @doc """
  Resolves the row's target and dispatches to its archetype module.

  Target invalidation and archetype failures surface as `{:error, reason}` — a
  clean abort, never a crash. A `:stub` skill or an archetype whose module is
  not built yet is a no-op `:ok`.
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
      target_id: state.target_id || 0,
      x: 0,
      y: 0,
      skill_id: row.skill_id,
      property: property(row.skill),
      cast_time: row.cast_time
    }

    Broadcast.to_in_range(state.map_name, state.x, state.y, Config.view_range(), packet)
  end

  defp maybe_emote(%MobState{instance_id: instance_id}, row) do
    case Map.get(row, :emotion) do
      nil -> :ok
      emotion -> Emote.show({:mob, instance_id}, emotion)
    end
  end

  defp dispatch(state, target, row) do
    case Catalog.archetype_for(row.skill) do
      :stub ->
        :ok

      {archetype, params} ->
        module = Module.concat(@archetype_namespace, Macro.camelize(Atom.to_string(archetype)))

        if Code.ensure_loaded?(module) and function_exported?(module, :apply, 4) do
          params =
            Map.merge(params, %{
              skill_id: row.skill_id,
              skill: row.skill,
              condition: row.condition
            })

          module.apply(state, target, params, row.level)
        else
          Logger.debug(
            "MobSkill: archetype #{archetype} not implemented yet, skipping #{row.skill}"
          )

          :ok
        end
    end
  end

  defp property(skill_name) do
    case Catalog.archetype_for(skill_name) do
      {_archetype, %{element: element}} -> ElementModifiers.id(element)
      _lookup -> 0
    end
  end

  defp lowest_hp_friend(%MobState{} = state) do
    :mob
    |> SpatialIndex.get_units_in_range(state.map_name, state.x, state.y, skill_range(state))
    |> Enum.reject(&(&1 == state.instance_id))
    |> Enum.flat_map(fn id ->
      case UnitRegistry.get_unit(:mob, id) do
        {:ok, {_module, %MobState{mob_id: mob_id, is_dead: false} = friend, _pid}}
        when mob_id == state.mob_id ->
          [friend]

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

  defp players_in_skill_range(%MobState{} = state) do
    SpatialIndex.get_units_in_range(:player, state.map_name, state.x, state.y, skill_range(state))
  end

  defp skill_range(%MobState{mob_data: mob_data}), do: mob_data.skill_range
end
