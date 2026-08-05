defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasher do
  @moduledoc """
  Venom Splasher (AS_SPLASHER), a target-owned delayed poison explosion.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 141,
    name: :as_splasher,
    requires: [],
    display_name: "Venom Splasher",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    cast_time: List.duplicate(500, 10),
    fixed_cast_time: List.duplicate(500, 10),
    sp_cost: Enum.to_list(12..30//2),
    cooldown: Enum.to_list(11_000..2_000//-1_000)

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Splasher
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(struct(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, target, unit_type} <- TargetResolver.resolve(target_id),
         true <- unit_type in [:player, :mob, :homunculus],
         true <- Unit.living?(target),
         {:ok, entity_info} <- UnitRegistry.get_unit_info(unit_type, target_id),
         false <- PropertyChecker.check_immunity(entity_info, Splasher.metadata()) do
      :ok
    else
      _invalid -> {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(struct(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, struct()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, _definition) do
    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_id),
         :ok <- arm(caster, target_type, target_id, level) do
      {:ok, caster}
    else
      {:error, _reason} = error -> error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp arm(caster, target_type, target_id, level) do
    countdown_ms = (12 - level) * 1_000
    arm_ref = make_ref()
    {source_type, source_id} = source_ref(caster)

    params = [
      val1: level,
      duration: countdown_ms + 1_500,
      caster_id: source_id,
      source_type: source_type,
      state: %{
        arm_ref: arm_ref,
        remaining_ms: countdown_ms,
        poison_react_level: poison_react_level(caster)
      }
    ]

    case StatusInterpreter.apply_status(target_type, target_id, :sc_splasher, params) do
      :ok -> schedule_current(target_type, target_id, arm_ref)
      {:error, _reason} = error -> error
    end
  end

  defp schedule_current(target_type, target_id, arm_ref) do
    case StatusStorage.get_status(target_type, target_id, :sc_splasher) do
      %{generation: generation, started_at: started_at, state: %{arm_ref: ^arm_ref}} ->
        StatusTickManager.schedule_exact_tick(
          target_type,
          target_id,
          :sc_splasher,
          generation,
          started_at + 1_000
        )

        :ok

      _replaced ->
        :ok
    end
  end

  defp poison_react_level(%PlayerState{stats: %{progression: %{learned_skills: learned}}})
       when is_map(learned),
       do: Learned.learned_level(learned, 139)

  defp poison_react_level(_caster), do: 0

  defp source_ref(%PlayerState{character_id: source_id}), do: {:player, source_id}
  defp source_ref(%{instance_id: source_id}), do: {:mob, source_id}
end
