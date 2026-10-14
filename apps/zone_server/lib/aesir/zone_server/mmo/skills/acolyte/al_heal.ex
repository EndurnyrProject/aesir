defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal do
  @moduledoc """
  Heal (AL_HEAL). Restores HP on an ally, or deals the amount as a holy magic
  hit when the target is an enemy whose defence element is undead. A demon-race
  target, and an undead-element target friendly to the caster, are both healed
  normally.

  The amount is `Combat.SkillHeal`'s recipe for both modes: the base from the
  caster's base level and effective INT (9999 from level 11), halved for a
  strike, the caster's and the target's heal bonuses, the renewal MATK part,
  and the target's penalties. A monster or NPC caster heals off its own INT and
  base level with no equipment bonus.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 28,
    name: :al_heal,
    requires: [],
    display_name: "Heal",
    max_level: 10,
    target_type: :target_any,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    element: :holy,
    sp_cost: [13, 16, 19, 22, 25, 28, 31, 34, 37, 40],
    after_cast_delay: [
      renewal: List.duplicate(500, 10),
      pre_renewal: List.duplicate(1_000, 10)
    ]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def validate(
        %{character_id: caster_id},
        {:unit, {:homunculus, _gid} = target_ref},
        _level,
        _definition
      ) do
    with {:ok, caster_combatant} <- Combat.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- Combat.resolve_combatant(target_ref),
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
  @doc """
  Casts Heal on the given target.

  Branches on the target: an enemy whose defence element is undead takes the
  amount as a holy magic hit, halved as an offensive cast; every other target
  (including players, allies and unresolvable targets) has the amount restored
  as HP.
  """
  @spec cast(Active.caster(), :self | {:unit, integer()}, pos_integer(), struct()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, target, level, _definition) do
    combatant = caster.__struct__.to_combatant(caster)
    target = Active.resolve_target_id(caster, target)
    offensive? = offensive_target?(combatant, target)

    amount =
      SkillHeal.amount(
        SkillHeal.caster(caster),
        heal_target_ref(target),
        28,
        level,
        not offensive?
      )

    if offensive? do
      attack_undead(caster, target, amount, level)
    else
      heal_living_target(caster, target, amount, combatant.unit_id)
    end
  end

  defp offensive_target?(caster, target) do
    case Combat.resolve_combatant(target) do
      {:ok, target_combatant} ->
        RaceModifiers.undead_target?(target_combatant) and
          Targeting.enemy?(caster, target_combatant)

      _unresolved ->
        false
    end
  end

  defp attack_undead(caster, target, damage, level) do
    case Combat.execute_magic_damage(caster, target, damage,
           skill_id: 28,
           skill_level: level,
           element: :holy,
           skip_range: true
         ) do
      {:ok, _ref} -> {:ok, caster}
      {:error, _} = error -> error
    end
  end

  defp heal_living_target(
         %{character_id: owner_id} = caster,
         {:homunculus, gid} = target_ref,
         heal_value,
         source_id
       ) do
    case UnitRegistry.get_unit(:homunculus, gid) do
      {:ok, {HomunculusState, %HomunculusState{owner_character_id: ^owner_id}, owner_pid}}
      when owner_pid == self() ->
        effect = DamageApplication.local_heal_effect(target_ref, heal_value, {:player, source_id})
        {:local_effects, caster, [effect]}

      _ ->
        Combat.apply_heal(:homunculus, gid, heal_value, source_id)
        {:ok, caster}
    end
  end

  defp heal_living_target(caster, target, heal_value, source_id) do
    {unit_type, unit_id} = target_ref(target)
    Combat.apply_heal(unit_type, unit_id, heal_value, source_id)
    {:ok, caster}
  end

  # A target the caller could not type stays without the Assumptio bonus
  # rather than guessing its unit type.
  defp heal_target_ref({unit_type, unit_id} = ref) when is_atom(unit_type) and unit_id != nil,
    do: ref

  defp heal_target_ref(unit_id) when is_integer(unit_id), do: target_ref(unit_id)
  defp heal_target_ref(_target), do: nil

  defp target_ref({unit_type, unit_id} = ref) do
    if Ref.valid?(ref), do: {unit_type, unit_id}, else: raise(ArgumentError, "invalid target ref")
  end

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
