defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrStrecovery do
  @moduledoc """
  Status Recovery (PR_STRECOVERY). Cures Stone, Freeze, Stun, and Sleep on an ally,
  or blinds an undead target one second after the cast.

  Renewal blinds for 18 s; pre-renewal for 30 s. Both modes reach 9 cells for 5 SP
  with a 2 s delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 72,
    name: :pr_strecovery,
    requires: [:player_state],
    status: :sc_blind,
    display_name: "Status Recovery",
    max_level: 1,
    target_type: :target_ally,
    damage_kind: :magic,
    range: 9,
    sp_cost: [5],
    after_cast_delay: [2_000],
    duration: [renewal: [18_000], pre_renewal: [30_000]]

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
  @supported_body_statuses [:sc_stone, :sc_freeze, :sc_stun, :sc_sleep, :sc_stonewait]

  # NOTE: Burning, White Imprison, Netherworld, and NoRecoverState have no status
  # modules. Add each here when its module exists, then remove this note.

  @doc "A player may support only their own Homunculus; any other is refused silently."
  @impl Active
  @spec skilluse_check(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def skilluse_check(caster, target, _level, _definition), do: homunculus_support(caster, target)

  @doc """
  Checks the Homunculus ownership again when the cast ends; a caster that is
  not a player may not support a Homunculus at all.
  """
  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :target_restricted}
  def validate(caster, target, _level, _definition), do: homunculus_support(caster, target)

  defp homunculus_support(%{character_id: caster_id}, {:unit, {:homunculus, gid}}) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :target_restricted}
    end
  end

  defp homunculus_support(_caster, {:unit, {:homunculus, _gid}}), do: {:error, :target_restricted}
  defp homunculus_support(_caster, _target), do: :ok

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
        definition
      ) do
    with {:ok, %{unit_type: ^unit_type} = target} <- Combat.resolve_combatant(target_ref) do
      cure_or_defer(caster, caster_id, unit_type, target_id, target, definition)
    end
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, _level, definition) do
    with {:ok, %{unit_type: unit_type} = target} <- Combat.resolve_combatant(target_id) do
      cure_or_defer(caster, caster_id, unit_type, target_id, target, definition)
    end
  end

  @doc "Applies the scheduled undead Blind. Ignores the caster state - it acts on the target."
  @impl Active
  @spec deferred(map(), PlayerState.t()) :: :ok | {:error, atom()}
  def deferred(
        %{unit_type: unit_type, target_id: target_id, caster_id: caster_id, duration: duration},
        _caster
      ) do
    apply_undead_effect(unit_type, target_id, caster_id, duration)
  end

  defp cure_or_defer(caster, caster_id, unit_type, target_id, target, definition) do
    if undead?(target) do
      payload = %{
        unit_type: unit_type,
        target_id: target_id,
        caster_id: caster_id,
        duration: hd(definition.duration)
      }

      Skill.defer(__MODULE__, payload, @undead_delay_ms)
    else
      cure_body_statuses(unit_type, target_id)
    end

    {:ok, caster}
  end

  @doc false
  @spec apply_undead_effect(:player | :mob | :homunculus, integer(), integer(), pos_integer()) ::
          :ok | {:error, atom()}
  def apply_undead_effect(unit_type, target_id, caster_id, duration) do
    StatusInterpreter.apply_status(unit_type, target_id, :sc_blind,
      caster_id: caster_id,
      duration: duration
    )
  end

  defp cure_body_statuses(unit_type, target_id) do
    Enum.each(@supported_body_statuses, fn status_id ->
      StatusInterpreter.remove_status(unit_type, target_id, status_id)
    end)
  end

  defp undead?(target), do: RaceModifiers.undead_target?(target)
end
