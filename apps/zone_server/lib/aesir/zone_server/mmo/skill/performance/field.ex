defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Field do
  @moduledoc """
  Maintains a pre-renewal performance as a ground group plus a performer lock.

  The group owns the footprint and occupant statuses. Its finite lock pays SP
  and asks for asynchronous group teardown whenever performing ends.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field.Tick
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Overlap
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Places a performance and locks its caster (and optional partners)."
  @spec start(PlayerState.t(), Definition.t(), pos_integer(), atom() | nil, keyword(), keyword()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def start(%PlayerState{character_id: id} = caster, definition, level, status_id, params, opts) do
    if StatusStorage.has_status?(:player, id, :sc_dancing) do
      {:error, :already_performing}
    else
      partners = Keyword.get(opts, :partners, [])

      perf = %{
        status_id: status_id,
        status_params: params,
        reach: Keyword.get(opts, :reach, :everyone),
        upkeep: Keyword.fetch!(opts, :upkeep),
        linger_ms: Keyword.get(opts, :linger_ms, 20_000),
        layout_radius: Keyword.get(opts, :layout_radius, 3),
        kind: Keyword.fetch!(opts, :kind),
        performers: [id | partners],
        tick: Keyword.get(opts, :tick),
        tick_interval: Keyword.get(opts, :tick_interval, 3_000),
        next_effect_at: 0,
        next_overlap_at: 0,
        lesson_level: Keyword.get(opts, :lesson_level, 0),
        caster_vit: Keyword.get(opts, :caster_vit, 0),
        dissonant_cells: MapSet.new()
      }

      with {:ok, group} <-
             Unit.place(caster, definition.name, level, {caster.x, caster.y},
               state: %{performance: perf, ignore_land_protector: true}
             ) do
        finish_start(caster, definition, level, perf, group, partners)
      end
    end
  end

  defp finish_start(caster, definition, level, perf, group, partners) do
    case lock(caster.character_id, definition.id, group, perf.upkeep, nil) do
      :ok ->
        Enum.each(
          partners,
          &lock_partner(&1, caster.character_id, definition.id, group, perf.upkeep)
        )

        {:ok, Snapshot.remember(caster, definition.id, level)}

      {:error, _reason} = error ->
        Unit.destroy_async(group.group_id)
        error
    end
  end

  defp lock_partner(partner, caster_id, skill_id, group, upkeep) do
    case lock(partner, skill_id, group, upkeep, caster_id) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Performance partner lock failed: #{inspect(reason)}")
    end
  end

  @doc "Builds the field footprint, lifetime and one-second reconciliation cadence."
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{
        center: center,
        level: level,
        skill_id: skill_id,
        state: %{performance: perf}
      }) do
    {:ok, definition} = Catalog.by_id(skill_id)

    {:ok,
     %{
       cells: Layout.square(center, perf.layout_radius),
       state: %{},
       interval: 1_000,
       duration: Enum.fetch!(definition.duration, level - 1),
       lifecycle_policy: %LifecyclePolicy{exclusive_family: :performance}
     }}
  end

  @doc "Recomputes dissonance and applies due interval effects."
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(group, now), do: group |> Overlap.mark() |> Tick.run(now)

  @doc "Describes the field-owned status and who may receive it."
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{state: %{performance: perf}} = group) do
    %{
      status_type: perf.status_id,
      params: perf.status_params ++ [caster_id: group.caster_id, source_type: group.caster_type],
      linger_ms: perf.linger_ms,
      target?: fn {type, id} = mover ->
        not (id in perf.performers and type == :player) and
          eligible?(perf.reach, group, mover) and
          not dissonant_position?(group, mover)
      end
    }
  end

  @doc "Unlocks all performers when their group ends."
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{state: %{performance: %{performers: performers}}}) do
    Enum.each(performers, fn id ->
      StatusInterpreter.remove_status(:player, id, :sc_dancing, owner_refresh: :notify)
    end)
  end

  defp lock(id, skill_id, group, upkeep, partner_id) do
    StatusInterpreter.apply_status(:player, id, :sc_dancing,
      caster_id: id,
      val1: skill_id,
      val2: group.group_id,
      val4: partner_id,
      duration: group.expires_at - group.created_at + 1_000,
      state: %{upkeep: upkeep, ticks: 0},
      owner_refresh: :notify
    )
  end

  defp eligible?(reach, group, {type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, target, _pid}} -> eligible_unit?(reach, group, type, target)
      _ -> false
    end
  end

  defp eligible_unit?(:everyone, _group, :player, _target), do: true
  defp eligible_unit?(:mobs, _group, :mob, _target), do: true

  defp eligible_unit?(:party, %{party_id: party_id}, :player, %{party_id: party_id})
       when is_integer(party_id) and party_id > 0,
       do: true

  defp eligible_unit?(:enemy, group, _type, target) do
    case UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      {:ok, {_module, caster, _pid}} -> Targeting.validate_enemy(caster, target) == :ok
      _ -> false
    end
  end

  defp eligible_unit?(_reach, _group, _type, _target), do: false

  defp dissonant_position?(group, {type, id}) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map_name}} when map_name == group.map_name ->
        Overlap.dissonant?(group, {x, y})

      _ ->
        false
    end
  end
end
