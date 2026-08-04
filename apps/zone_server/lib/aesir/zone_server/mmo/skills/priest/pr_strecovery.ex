defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrStrecovery do
  @moduledoc """
  Status Recovery (PR_STRECOVERY).

  rAthena Renewal: `db/re/skill_db.yml:2565-2580` and
  `src/map/skills/acolyte/statusrecovery.cpp:13-46`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 72,
    name: :pr_strecovery,
    status: :sc_blind,
    display_name: "Status Recovery",
    max_level: 1,
    target_type: :target_ally,
    range: 9,
    sp_cost: [5],
    after_cast_delay: [2_000],
    duration: [18_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @undead_delay_ms 1_000
  @blind_duration_ms 18_000
  @supported_body_statuses [:sc_stone, :sc_freeze, :sc_stun, :sc_sleep]

  # NOTE: StoneWait is Aesir's :wait phase of sc_stone and is cured above.
  # Burning, White Imprison, Netherworld, and NoRecoverState have no status
  # modules. Add each here when its module exists, then remove this note.

  @impl Active
  def validate(%{character_id: caster_id}, {:unit, {:homunculus, gid}}, _level, _definition) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, {:unit, {:homunculus, _gid}}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, _level, _definition) do
    cure_body_statuses(:player, caster_id)
    {:ok, caster}
  end

  def cast(
        %{character_id: caster_id} = caster,
        {:unit, {unit_type, target_id} = target_ref},
        _level,
        _definition
      ) do
    with {:ok, %{unit_type: ^unit_type} = target} <- Combat.resolve_combatant(target_ref) do
      cure_or_defer(caster, caster_id, unit_type, target_id, target)
    end
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, _level, _definition) do
    with {:ok, %{unit_type: unit_type} = target} <- Combat.resolve_combatant(target_id) do
      cure_or_defer(caster, caster_id, unit_type, target_id, target)
    end
  end

  @doc "Applies the scheduled undead Blind. Ignores the caster state - it acts on the target."
  @impl Active
  @spec deferred(map(), PlayerState.t()) :: :ok | {:error, atom()}
  def deferred(%{unit_type: unit_type, target_id: target_id, caster_id: caster_id}, _caster) do
    apply_undead_effect(unit_type, target_id, caster_id)
  end

  defp cure_or_defer(caster, caster_id, unit_type, target_id, target) do
    if undead?(target) do
      payload = %{unit_type: unit_type, target_id: target_id, caster_id: caster_id}
      Skill.defer(__MODULE__, payload, @undead_delay_ms)
    else
      cure_body_statuses(unit_type, target_id)
    end

    {:ok, caster}
  end

  @doc false
  @spec apply_undead_effect(:player | :mob | :homunculus, integer(), integer()) ::
          :ok | {:error, atom()}
  def apply_undead_effect(unit_type, target_id, caster_id) do
    StatusInterpreter.apply_status(unit_type, target_id, :sc_blind,
      caster_id: caster_id,
      duration: @blind_duration_ms
    )
  end

  defp cure_body_statuses(unit_type, target_id) do
    Enum.each(@supported_body_statuses, fn status_id ->
      StatusInterpreter.remove_status(unit_type, target_id, status_id)
    end)
  end

  defp undead?(%{race: race} = target),
    do: RaceModifiers.undead?(race) or undead_element?(Map.get(target, :element))

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
