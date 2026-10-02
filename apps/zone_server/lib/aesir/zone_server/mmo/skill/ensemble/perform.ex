defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform do
  @moduledoc """
  Runs Renewal snapshots with fatigue or paired pre-renewal ensemble fields.

  Classic ensembles require a partner, cover a stationary 9x9 square, and
  end their occupant effects on exit. Lullaby instead attempts sleep every
  six seconds; inflicted sleep survives the performance.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Partner
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @fatigue_opts [owner_refresh: :notify, bypass_resistance: true]

  @doc "Checks the mandatory classic partner before resources are committed."
  @spec validate(PlayerState.t(), Definition.t(), pos_integer()) :: :ok | {:error, atom()}
  def validate(caster, definition, level) do
    if GameMode.mode() == :pre_renewal do
      with {:ok, _partner, _level} <- classic_partner(caster, definition, level), do: :ok
    else
      :ok
    end
  end

  @doc "Runs an ensemble at its solo or partner-averaged effective level."
  @spec perform(
          PlayerState.t(),
          Definition.t(),
          pos_integer(),
          atom(),
          (pos_integer() -> keyword()),
          keyword()
        ) :: {:ok, PlayerState.t()} | {:error, term()}
  def perform(
        %PlayerState{} = caster,
        %Definition{} = definition,
        level,
        status_id,
        params_fun,
        opts
      ) do
    case GameMode.mode() do
      :renewal -> renewal(caster, definition, level, status_id, params_fun, opts)
      :pre_renewal -> classic(caster, definition, level, status_id, params_fun)
    end
  end

  defp classic(caster, definition, level, status_id, params_fun) do
    with {:ok, partner, effective_level} <- classic_partner(caster, definition, level) do
      opts =
        [kind: :ensemble, layout_radius: 4, linger_ms: 0, partners: [partner.character_id]] ++
          field_options(definition.id)

      status_id = if definition.id == 306, do: nil, else: status_id

      Field.start(
        caster,
        definition,
        effective_level,
        status_id,
        params_fun.(effective_level),
        opts
      )
    end
  end

  defp classic_partner(caster, definition, level) do
    if StatusStorage.has_status?(:player, caster.character_id, :sc_dancing) do
      {:error, :already_performing}
    else
      case Partner.find(caster, definition.id, level) do
        :none -> {:error, :ensemble_partner_required}
        partner -> partner
      end
    end
  end

  defp field_options(306), do: [reach: :enemy, upkeep: 4, tick: :lullaby, tick_interval: 6_000]
  defp field_options(307), do: [reach: :mobs, upkeep: 3]
  defp field_options(308), do: [reach: :enemy, upkeep: 4]
  defp field_options(309), do: [reach: :party, upkeep: 3]
  defp field_options(310), do: [reach: :party, upkeep: 3]
  defp field_options(311), do: [reach: :all, upkeep: 4]
  defp field_options(312), do: [reach: :party, upkeep: 5]
  defp field_options(313), do: [reach: :party, upkeep: 3]

  defp renewal(caster, definition, level, status_id, params_fun, opts) do
    case Partner.find(caster, definition.id, level) do
      {:ok, partner, effective_level} ->
        result = snapshot(caster, definition, effective_level, status_id, params_fun, opts)
        fatigue_partner(partner.character_id)
        :ok = fatigue(caster.character_id)
        result

      :none ->
        snapshot(caster, definition, level, status_id, params_fun, opts)
    end
  end

  defp snapshot(caster, definition, level, status_id, params_fun, opts) do
    Snapshot.snapshot(caster, definition, level, status_id, params_fun.(level), opts)
  end

  # The partner is a point-in-time ETS read: they may have died, warped or logged
  # out between selection and this write. A dead partner yields `{:error,
  # :target_dead}` and a deregistered one makes the interpreter raise, and neither
  # is worth failing the caster's own cast for - the caster still owes their
  # fatigue, and an unapplied partner status self-heals because it is finite.
  defp fatigue_partner(character_id) do
    _ = fatigue(character_id)
    :ok
  rescue
    RuntimeError -> :ok
  end

  defp fatigue(character_id) do
    StatusInterpreter.apply_status(:player, character_id, :sc_ensemblefatigue, @fatigue_opts)
  end
end
