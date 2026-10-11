defmodule Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform do
  @moduledoc """
  Runs Renewal snapshots with fatigue or paired pre-renewal ensemble fields.

  Every ensemble needs a partner within one cell when its cast begins
  (`begin_attempt/2`). The completed cast reuses that partner without searching
  again, and always runs at the caster's own skill level.

  Renewal fatigues the caster and then the partner, when the partner is still
  online, before applying the snapshot. Classic ensembles cover a stationary 9x9
  square, lock both performers, and end their occupant effects on exit. Lullaby
  instead attempts sleep every six seconds; inflicted sleep survives the
  performance.

  `perform_field/4` starts a maintained ensemble in either mode, locking the
  partner, without fatigue.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Partner
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @fatigue_opts [owner_refresh: :notify, bypass_resistance: true]

  @doc """
  Finds the cast-begin partner and records it on the caster for completion.

  A classic caster already performing is refused first.
  """
  @spec begin_attempt(PlayerState.t(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def begin_attempt(%PlayerState{} = caster, %Definition{} = definition) do
    with :ok <- check_not_performing(caster) do
      case Partner.find(caster, definition.id) do
        {:ok, partner} -> {:ok, %{caster | ensemble_partner: partner.character_id}}
        :none -> {:error, :ensemble_partner_required}
      end
    end
  end

  @doc "Runs an ensemble at the caster's level with the cast-begin partner."
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

  @doc """
  Starts a field ensemble in either mode, with no ensemble fatigue.

  `:upkeep_sp` is the SP each performer pays per upkeep step.
  """
  @spec perform_field(PlayerState.t(), Definition.t(), pos_integer(), keyword()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def perform_field(caster, definition, level, opts) do
    Field.start(
      caster,
      definition,
      level,
      nil,
      [],
      [kind: :ensemble, layout_radius: 4, linger_ms: 0, partners: partners(caster)] ++ opts
    )
  end

  defp check_not_performing(caster) do
    if GameMode.mode() == :pre_renewal and
         StatusStorage.has_status?(:player, caster.character_id, :sc_dancing),
       do: {:error, :already_performing},
       else: :ok
  end

  defp classic(caster, definition, level, status_id, params_fun) do
    opts =
      [kind: :ensemble, layout_radius: 4, linger_ms: 0, partners: partners(caster)] ++
        field_options(definition.id)

    status_id = if definition.id == 306, do: nil, else: status_id

    Field.start(caster, definition, level, status_id, params_fun.(level), opts)
  end

  defp partners(%PlayerState{ensemble_partner: partner_id}) do
    if online?(partner_id), do: [partner_id], else: []
  end

  defp online?(nil), do: false
  defp online?(partner_id), do: match?({:ok, _unit}, UnitRegistry.get_unit(:player, partner_id))

  defp field_options(306), do: [reach: :enemy, upkeep: 4, tick: :lullaby, tick_interval: 6_000]
  defp field_options(307), do: [reach: :mobs, upkeep: 3]
  defp field_options(308), do: [reach: :enemy, upkeep: 4]
  defp field_options(309), do: [reach: :party, upkeep: 3]
  defp field_options(310), do: [reach: :party, upkeep: 3]
  defp field_options(311), do: [reach: :all, upkeep: 4]
  defp field_options(312), do: [reach: :party, upkeep: 5]
  defp field_options(313), do: [reach: :party, upkeep: 3]

  defp renewal(caster, definition, level, status_id, params_fun, opts) do
    partner_id = caster.ensemble_partner

    if online?(partner_id) do
      :ok = fatigue(caster.character_id)
      fatigue_partner(partner_id)
    end

    Snapshot.snapshot(caster, definition, level, status_id, params_fun.(level), opts)
  end

  # The partner is a point-in-time registry read: they may have died, warped or
  # logged out since. A dead partner yields `{:error, :target_dead}` and a
  # deregistered one makes the interpreter raise; neither fails the caster's
  # cast, and the caster's own fatigue was already applied.
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
