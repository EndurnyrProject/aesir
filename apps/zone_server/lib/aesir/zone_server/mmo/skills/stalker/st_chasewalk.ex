defmodule Aesir.ZoneServer.Mmo.Skills.Stalker.StChasewalk do
  @moduledoc """
  Chase Walk (ST_CHASEWALK). A self toggle for 10 SP that starts Chase Walk
  (`sc_chasewalk`) at the cast level; recasting while it runs only ends it, with
  no SP spent.

  Renewal: 0.5 s cast plus 0.5 s fixed, ending it included. Pre-renewal: a
  1.2 s cast, while ending it has no cast at all.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 389,
    name: :st_chasewalk,
    requires: [],
    status: :sc_chasewalk,
    toggleable: true,
    display_name: "Chase Walk",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(10, 5),
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1_200, 5)],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc "Pre-renewal: recasting to end a running Chase Walk has no cast at all."
  @impl Active
  @spec dynamic_cast_time(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          %{cast_time: -1 | non_neg_integer(), fixed_cast_time: non_neg_integer()}
  def dynamic_cast_time(caster, _target, level, definition) do
    if GameMode.mode() == :pre_renewal and walking?(caster) do
      %{cast_time: -1, fixed_cast_time: 0}
    else
      %{
        cast_time: Enum.at(definition.cast_time, level - 1, 0),
        fixed_cast_time: Enum.at(definition.fixed_cast_time, level - 1, 0)
      }
    end
  end

  defp walking?(%PlayerState{character_id: id}),
    do: StatusStorage.has_status?(:player, id, :sc_chasewalk)

  defp walking?(%MobState{instance_id: id}),
    do: StatusStorage.has_status?(:mob, id, :sc_chasewalk)

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:failed, PlayerState.t(), atom()} | {:error, atom()}
  def cast(%PlayerState{character_id: caster_id} = caster, target, level, _definition)
      when target == :self or target == {:unit, caster_id} do
    case StatusInterpreter.toggle_status(:player, caster_id, :sc_chasewalk,
           val1: level,
           caster_id: caster_id,
           source_type: :player
         ) do
      {:ok, _applied_or_removed} -> {:ok, caster}
      {:error, reason} -> {:failed, caster, reason}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{instance_id: caster_id}, _target, level, _definition, _row) do
    StatusInterpreter.apply_status(:mob, caster_id, :sc_chasewalk,
      val1: level,
      caster_id: caster_id,
      source_type: :mob
    )
  end
end
