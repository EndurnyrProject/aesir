defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasher do
  @moduledoc """
  Venom Splasher (AS_SPLASHER). Arms a countdown on an enemy that explodes after
  12 minus level seconds into a poison weapon splash over 2 cells, poisoning
  everything hit, for 12 to 30 SP at 1 cell.

  Renewal: 400% plus 100% per level (plus 20% per Poison React level), poison for
  18 s, a 0.5 s cast plus 0.5 s fixed, an 11 down to 2 s cooldown, no catalyst, any
  target HP. Pre-renewal: 500% plus 50% per level (plus the same Poison React
  bonus), poison for 60 s, a 1 s cast, a 7.5 up to 12 s cooldown, one Red Gemstone,
  and the target must be at three quarters HP or less.
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
    cast_time: [renewal: List.duplicate(500, 10), pre_renewal: List.duplicate(1_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(500, 10), pre_renewal: []],
    sp_cost: Enum.to_list(12..30//2),
    cooldown: [
      renewal: Enum.to_list(11_000..2_000//-1_000),
      pre_renewal: Enum.to_list(7_500..12_000//500)
    ],
    duration: [renewal: List.duplicate(18_000, 10), pre_renewal: List.duplicate(60_000, 10)],
    item_cost: [renewal: [], pre_renewal: [%{id: 716, amount: 1}]]

  alias Aesir.Commons.GameMode
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
         true <- hp_low_enough?(target),
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

  # Pre-renewal refuses targets above three quarters of their HP; renewal dropped the gate.
  defp hp_low_enough?(target) do
    {hp, max_hp} = hp_pair(target)
    GameMode.mode() == :renewal or hp * 4 <= max_hp * 3
  end

  defp hp_pair(%{stats: %{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}}}),
    do: {hp, max_hp}

  defp hp_pair(%{hp: hp, max_hp: max_hp}), do: {hp, max_hp}

  defp poison_react_level(%PlayerState{stats: %{progression: %{learned_skills: learned}}})
       when is_map(learned),
       do: Learned.learned_level(learned, 139)

  defp poison_react_level(_caster), do: 0

  defp source_ref(%PlayerState{character_id: source_id}), do: {:player, source_id}
  defp source_ref(%{instance_id: source_id}), do: {:mob, source_id}
end
