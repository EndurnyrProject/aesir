defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Field do
  @moduledoc """
  Maintains a performance as a ground group plus a performer lock in either mode.
  Pre-renewal songs and ensembles use fields; renewal Moonlit also uses this path.

  The group owns the footprint and occupant statuses. Its finite lock pays SP
  and asks for asynchronous group teardown whenever performing ends.

  A song or dance field follows its walking performer; an ensemble field stays
  where it was cast, even when Longing lets a performer walk. The per-entry
  root and SP upkeep amount are configurable for Moonlit and Hermode.

  A song, a dance, and an ensemble with its own interval effect (Lullaby) act
  per cell on the skill-unit pass (`cell_profile/2`, `unit_targets/3`,
  `on_unit_hit/4`): a cell strikes with its skill's own Unit interval
  (`:tick_interval`, and the shared NoOverlap interval for `no_overlap: true`).
  A cell a song shares with another song (or a dance with another dance) is
  dissonant: for as long as the overlap lasts it strikes as Dissonance (songs) or
  Ugly Dance (dances) every 3 s at the field's level on enemies, with the
  NoOverlap interval those skills share, even a buff song that otherwise never
  strikes, and its occupants get no song status. Land Protector removes and
  silences a performance's cells unless its skill ignores it (every solo song
  and dance, and Hermode, do; the other ensembles do not).

  A monster may perform a solo song or dance: it is the field's only performer
  and carries the performing lock like a player.
  """

  require Logger

  alias Aesir.ZoneServer.Guild.Relations
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
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @dissonant_skill %{song: 317, dance: 325}
  @dissonant_effect %{song: :dissonance, dance: :ugly_dance}
  @dissonant_interval 3_000

  @doc "Places a performance and locks its caster (and optional partners)."
  @spec start(
          PlayerState.t() | MobState.t(),
          Definition.t(),
          pos_integer(),
          atom() | nil,
          keyword(),
          keyword()
        ) ::
          {:ok, PlayerState.t() | MobState.t()} | {:error, term()}
  def start(caster, definition, level, status_id, params, opts) do
    {type, id} = performer(caster)

    if StatusStorage.has_status?(type, id, :sc_dancing) do
      {:error, :already_performing}
    else
      partners = Keyword.get(opts, :partners, [])
      kind = Keyword.fetch!(opts, :kind)

      perf = %{
        status_id: status_id,
        status_params: params,
        reach: Keyword.get(opts, :reach, :everyone),
        upkeep: Keyword.fetch!(opts, :upkeep),
        upkeep_sp: Keyword.get(opts, :upkeep_sp, 1),
        root: Keyword.get(opts, :root, if(kind == :ensemble, do: :ensemble, else: :none)),
        linger_ms: Keyword.fetch!(opts, :linger_ms),
        layout_radius: Keyword.get(opts, :layout_radius, 3),
        kind: kind,
        performers: player_performers(type, id, partners),
        tick: Keyword.get(opts, :tick),
        tick_interval: Keyword.get(opts, :tick_interval, 3_000),
        no_overlap: Keyword.get(opts, :no_overlap, false),
        lesson_level: Keyword.get(opts, :lesson_level, 0),
        caster_vit: Keyword.get(opts, :caster_vit, 0)
      }

      with {:ok, group} <-
             Unit.place(caster, definition.name, level, {caster.x, caster.y},
               state: %{
                 performance: perf,
                 ignore_land_protector:
                   Keyword.get(opts, :ignore_land_protector, kind != :ensemble),
                 follows_caster: perf.kind != :ensemble
               }
             ) do
        finish_start(caster, definition, level, perf, group, partners)
      end
    end
  end

  defp performer(%PlayerState{character_id: id}), do: {:player, id}
  defp performer(%MobState{instance_id: id}), do: {:mob, id}

  defp player_performers(:player, id, partners), do: [id | partners]
  defp player_performers(_type, _id, _partners), do: []

  defp finish_start(caster, definition, level, perf, group, partners) do
    {_type, caster_id} = ref = performer(caster)

    case lock(ref, definition.id, group, perf, List.first(partners)) do
      :ok ->
        Enum.each(partners, fn partner ->
          lock_partner(partner, caster_id, definition.id, group, perf)
          remember_for_partner(partner, definition.id, level)
        end)

        {:ok, remember(caster, definition.id, level)}

      {:error, _reason} = error ->
        Unit.destroy_async(group.group_id)
        error
    end
  end

  defp remember(%PlayerState{} = caster, skill_id, level),
    do: Snapshot.remember(caster, skill_id, level)

  defp remember(caster, _skill_id, _level), do: caster

  # The partner's Encore replays the ensemble at the caster's level, even when
  # the partner's own lock failed.
  defp remember_for_partner(partner, skill_id, level) do
    case UnitRegistry.get_unit(:player, partner) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        PlayerSession.remember_song(pid, skill_id, level)

      _ ->
        :ok
    end
  end

  defp lock_partner(partner, caster_id, skill_id, group, perf) do
    case lock({:player, partner}, skill_id, group, perf, caster_id) do
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

    placement = %{
      cells: Layout.square(center, perf.layout_radius),
      state: %{},
      interval: 1_000,
      duration: Enum.fetch!(definition.duration, level - 1),
      lifecycle_policy: %LifecyclePolicy{exclusive_family: :performance}
    }

    if perf.kind in [:song, :dance] or perf.tick != nil,
      do: {:ok, Map.put(placement, :unit_range, 0)},
      else: {:ok, placement}
  end

  @doc """
  The skill a cell strikes as this pass: Dissonance or Ugly Dance on a
  dissonant cell, the performance's own interval effect otherwise, and nothing
  for a buff field's undisturbed cell.
  """
  @spec cell_profile(Group.t(), Ground.cell()) ::
          %{skill_id: pos_integer(), interval: pos_integer(), no_overlap: boolean()} | :none
  def cell_profile(%Group{state: %{performance: perf}} = group, cell) do
    case effect(group, cell) do
      {:dissonant, _effect} ->
        %{skill_id: @dissonant_skill[perf.kind], interval: @dissonant_interval, no_overlap: true}

      {:own, _effect} ->
        %{skill_id: group.skill_id, interval: perf.tick_interval, no_overlap: perf.no_overlap}

      :none ->
        :none
    end
  end

  @doc "Keeps the living units one cell's effect may reach, never its performers."
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, cell, refs) do
    case effect(group, cell) do
      :none -> []
      {_kind, effect} -> Enum.filter(refs, &Tick.target?(group, effect, &1))
    end
  end

  @doc "Applies one cell's effect to one unit."
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, cell, target, _now) do
    case effect(group, cell) do
      :none -> :ok
      {_kind, effect} -> Tick.apply(effect, group, target)
    end

    {:ok, group}
  end

  defp effect(%Group{state: %{performance: perf}} = group, cell) do
    cond do
      Overlap.dissonant?(group, cell) -> {:dissonant, @dissonant_effect[perf.kind]}
      perf.tick != nil -> {:own, perf.tick}
      true -> :none
    end
  end

  @doc """
  The field's cells act on their own pass; a performer stepping off an
  ensemble, dying or leaving the map ends its lock through the field's leave
  events, which tear the group down.
  """
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(group, _now), do: {:ok, group}

  @doc """
  Describes the field-owned status: who the field targets (its reach, the
  performers included wherever the reach lets a unit target itself) and which
  placement grants it (never on a Basilica cell; a dissonant cell and the
  performers' own placement are handled by the manager).
  """
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{state: %{performance: perf}} = group) do
    %{
      status_type: perf.status_id,
      params: perf.status_params ++ [caster_id: group.caster_id, source_type: group.caster_type],
      linger_ms: perf.linger_ms,
      target?: &reaches?(perf.reach, group, &1),
      grants?: fn mover -> not on_basilica?(group, mover) end
    }
  end

  @doc "Unlocks all performers when their group ends."
  @spec on_expire(Group.t()) :: :ok
  def on_expire(%Group{state: %{performance: %{performers: performers}}} = group) do
    group
    |> performer_refs(performers)
    |> Enum.each(fn {type, id} ->
      StatusInterpreter.remove_status(type, id, :sc_dancing, owner_refresh: :notify)
    end)
  end

  defp performer_refs(%Group{caster_type: :player}, performers),
    do: Enum.map(performers, &{:player, &1})

  defp performer_refs(%Group{caster_type: type, caster_id: id}, _performers), do: [{type, id}]

  defp lock({type, id}, skill_id, group, perf, partner_id) do
    StatusInterpreter.apply_status(type, id, :sc_dancing,
      caster_id: id,
      val1: skill_id,
      val2: group.group_id,
      val3: perf.lesson_level,
      val4: partner_id,
      duration: group.expires_at - group.created_at + 1_000,
      state: %{upkeep: perf.upkeep, ticks: 0, upkeep_sp: perf.upkeep_sp, root: perf.root},
      owner_refresh: :notify
    )
  end

  @doc "Whether the field's `reach` lets it target `mover`."
  @spec reaches?(atom(), Group.t(), {atom(), integer()}) :: boolean()
  def reaches?(reach, %Group{} = group, {type, id}) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, target, _pid}} -> eligible_unit?(reach, group, type, target)
      _ -> false
    end
  end

  defp eligible_unit?(:all, _group, type, _target) when type in [:player, :mob], do: true
  defp eligible_unit?(:everyone, _group, :player, _target), do: true

  defp eligible_unit?(:party, %{party_id: party_id}, :player, %{party_id: party_id})
       when is_integer(party_id) and party_id > 0,
       do: true

  defp eligible_unit?(:party_or_guild, group, :player, target) do
    case UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      {:ok, {_module, caster, _pid}} ->
        (is_integer(caster.party_id) and caster.party_id > 0 and
           caster.party_id == target.party_id) or
          (is_integer(caster.guild_id) and caster.guild_id > 0 and
             caster.guild_id == target.guild_id) or
          Relations.allied?(caster.guild_id, target.guild_id)

      _ ->
        false
    end
  end

  defp eligible_unit?(:enemy, group, _type, target) do
    case UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      {:ok, {_module, caster, _pid}} -> Targeting.validate_enemy(caster, target) == :ok
      _ -> false
    end
  end

  defp eligible_unit?(_reach, _group, _type, _target), do: false

  # Song and ensemble statuses never take hold on a Basilica sanctuary cell.
  defp on_basilica?(group, {type, id}) do
    case SpatialIndex.get_unit_position(type, id) do
      {:ok, {x, y, map_name}} when map_name == group.map_name -> Storage.basilica?(map_name, x, y)
      _ -> false
    end
  end
end
