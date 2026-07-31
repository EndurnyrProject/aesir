defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform do
  @moduledoc """
  Runs an ensemble snapshot and applies paired-performer fatigue.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Partner
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @fatigue_opts [owner_refresh: :notify, bypass_resistance: true]

  @doc "Runs an ensemble at its solo or partner-averaged effective level."
  @spec perform(
          PlayerState.t(),
          Definition.t(),
          pos_integer(),
          atom(),
          (pos_integer() -> keyword()),
          keyword()
        ) :: {:ok, PlayerState.t()}
  def perform(
        %PlayerState{} = caster,
        %Definition{} = definition,
        level,
        status_id,
        params_fun,
        opts
      ) do
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
