defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSplasher do
  @moduledoc """
  Venom Splasher (AS_SPLASHER). Arms a 12 minus level seconds countdown on an
  enemy; half a second after it runs out it explodes into a poison weapon splash
  over 2 cells, poisoning everything hit, for 12 to 30 SP at 1 cell.

  Renewal: 400% plus 100% per level (plus 20% per Poison React level), poison for
  18 s, a 0.5 s cast plus 0.5 s fixed, an 11 down to 2 s cooldown, no catalyst, any
  target HP. Pre-renewal: 500% plus 50% per level (plus the same Poison React
  bonus), poison for 60 s, a 1 s cast, a 7.5 up to 12 s cooldown, one Red Gemstone,
  and the target must be at three quarters HP or less.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 141,
    name: :as_splasher,
    ignore_atk_card: true,
    requires: [],
    display_name: "Venom Splasher",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    ignore_flee: true,
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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Splasher
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.PropertyChecker
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(struct(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  # The reference's status-immunity and classic HP checks live inside the
  # implementation, so they are paid failures rather than cast-begin refusals.
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, target, unit_type} when unit_type in [:player, :mob, :homunculus] ->
        if Unit.living?(target), do: :ok, else: {:error, :invalid_target}

      _invalid ->
        {:error, :invalid_target}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(struct(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, struct()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, _definition) do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, target, target_type} ->
        if refused?(target_type, target_id, target) do
          # The reference reports this refusal from inside the implementation.
          {:failed, caster, :invalid_target}
        else
          # A refused status start is not a cast failure; the items still settle.
          _ = arm(caster, target_type, target_id, level)
          {:ok, caster}
        end

      {:error, _reason} = error ->
        error
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp refused?(unit_type, target_id, target),
    do: not hp_low_enough?(target) or immune?(unit_type, target_id)

  defp immune?(unit_type, target_id) do
    case UnitRegistry.get_unit_info(unit_type, target_id) do
      {:ok, entity_info} -> PropertyChecker.check_immunity(entity_info, Splasher.metadata())
      {:error, _reason} -> false
    end
  end

  # The countdown's first step is a second away; the rest follow every half second.
  defp arm(caster, target_type, target_id, level) do
    countdown_ms = (12 - level) * 1_000
    {source_type, source_id} = source_ref(caster)

    StatusInterpreter.apply_status(target_type, target_id, :sc_splasher,
      val1: level,
      val4: countdown_ms,
      duration: :infinite,
      first_tick: 1_000,
      caster_id: source_id,
      source_type: source_type
    )
  end

  # Pre-renewal refuses targets above three quarters of their HP; renewal dropped the gate.
  defp hp_low_enough?(target) do
    {hp, max_hp} = hp_pair(target)
    GameMode.mode() == :renewal or hp * 4 <= max_hp * 3
  end

  defp hp_pair(%{stats: %{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}}}),
    do: {hp, max_hp}

  defp hp_pair(%MobState{hp: hp, calculated: calculated}), do: {hp, calculated.max_hp}

  defp source_ref(%PlayerState{character_id: source_id}), do: {:player, source_id}
  defp source_ref(%{instance_id: source_id}), do: {:mob, source_id}
end
