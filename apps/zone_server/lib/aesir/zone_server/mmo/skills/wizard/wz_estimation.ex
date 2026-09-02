defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzEstimation do
  @moduledoc """
  Estimation (WZ_ESTIMATION), a single-target monster inspection skill.

  Renewal data comes from rAthena `db/re/skill_db.yml:3851-3863`. rAthena's
  `SkillSense` rejects player targets and sends monster data only to the caster.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 93,
    name: :wz_estimation,
    display_name: "Sense",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.EstimationView
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :invalid_target}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :ok, else: {:error, :invalid_target}
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :target_not_found}
  def cast(
        %PlayerState{character_id: caster_id} = caster,
        {:unit, target_id},
        _level,
        _definition
      ) do
    with {:ok, {_module, %MobState{} = target, _pid}} <- UnitRegistry.get_unit(:mob, target_id),
         {:ok, {_module, _caster, caster_pid}} <- UnitRegistry.get_unit(:player, caster_id) do
      PlayerSession.send_packet(caster_pid, EstimationView.result(target_id, target))
      {:ok, caster}
    else
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end
end
