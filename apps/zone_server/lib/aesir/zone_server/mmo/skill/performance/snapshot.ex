defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot do
  @moduledoc """
  Applies finite performances to a completion-time recipient snapshot and
  remembers completed performances.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type recipient :: PlayerState.t() | {atom(), integer()}
  @type eligibility :: (recipient() -> boolean())

  @doc "Applies a performance independently to each eligible completion-time recipient."
  @spec snapshot(
          PlayerState.t(),
          Definition.t(),
          pos_integer(),
          atom(),
          keyword(),
          keyword()
        ) :: {:ok, PlayerState.t()}
  def snapshot(caster, %Definition{} = definition, level, status_id, status_params, opts) do
    scope = Keyword.get(opts, :scope, :party)

    radius =
      Keyword.get_lazy(opts, :radius, fn ->
        if definition.splash_radius > 0,
          do: definition.splash_radius,
          else: Definition.range_at_level(definition, level)
      end)

    duration =
      Keyword.get_lazy(opts, :duration, fn -> Enum.fetch!(definition.duration, level - 1) end)

    eligible? = Keyword.get(opts, :eligible?, fn _recipient -> true end)

    caster
    |> recipients(scope, radius)
    |> Enum.filter(eligible?)
    |> Enum.each(&apply_status(&1, caster.character_id, status_id, status_params, duration))

    {:ok, remember(caster, definition.id, level)}
  end

  @doc "Stores the skill id and level of a completed Encore-eligible performance."
  @spec remember(PlayerState.t(), integer(), pos_integer()) :: PlayerState.t()
  def remember(%PlayerState{} = caster, skill_id, level) when is_integer(level) and level > 0 do
    if Catalog.performance?(skill_id) do
      %{caster | last_song: %{skill_id: skill_id, level: level}}
    else
      raise ArgumentError, "skill #{skill_id} is not a performance"
    end
  end

  defp recipients(%PlayerState{} = caster, :party, radius) do
    caster
    |> party_recipients(radius)
    |> then(fn party -> [caster | party] end)
    |> Enum.uniq_by(& &1.character_id)
    |> Enum.filter(&Unit.living?/1)
  end

  defp recipients(%PlayerState{} = caster, :enemy, radius) do
    Combat.splash_targets(
      caster.map_name,
      {caster.x, caster.y},
      radius,
      caster.character_id
    )
  end

  defp party_recipients(%PlayerState{party_id: party_id}, _radius) when party_id in [nil, 0],
    do: []

  defp party_recipients(%PlayerState{} = caster, radius) do
    case PartyManager.get(caster.party_id) do
      {:ok, party} ->
        party
        |> PartyState.online_members()
        |> Enum.flat_map(&resolve_nearby_member(&1.char_id, caster, radius))

      {:error, :not_found} ->
        []
    end
  end

  defp resolve_nearby_member(character_id, caster, radius) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, %PlayerState{} = member, _pid}} ->
        if member.map_name == caster.map_name and
             Geometry.in_tile_range?(caster.x, caster.y, member.x, member.y, radius) do
          [member]
        else
          []
        end

      {:error, :not_found} ->
        []
    end
  end

  defp apply_status(
         %PlayerState{character_id: target_id},
         caster_id,
         status_id,
         params,
         duration
       ),
       do: apply_status(:player, target_id, caster_id, status_id, params, duration)

  defp apply_status({unit_type, target_id}, caster_id, status_id, params, duration),
    do: apply_status(unit_type, target_id, caster_id, status_id, params, duration)

  defp apply_status(unit_type, target_id, caster_id, status_id, status_params, duration) do
    params =
      Keyword.merge(status_params,
        caster_id: caster_id,
        duration: duration,
        owner_refresh: :notify
      )

    case StatusInterpreter.apply_status(unit_type, target_id, status_id, params) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Performance #{status_id} application to #{unit_type} #{target_id} failed: #{inspect(reason)}"
        )
    end
  end
end
