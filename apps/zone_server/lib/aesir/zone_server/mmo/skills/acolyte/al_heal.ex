defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal do
  @moduledoc """
  Heal (AL_HEAL). Restores HP on an ally, or deals the same amount as a holy
  magic hit when the target is an enemy whose defence element is undead. A
  demon-race target, and an undead-element target friendly to the caster, are
  both healed normally.

  An offensive cast halves the base amount before any other term. The recipient's
  own heal-received bonus is applied downstream on the generic heal path that
  every heal flows through.

  Renewal: the base is `(base level + INT) / 5 * 30 * skill level / 10`.
  Equipment heal power (the general bonus plus the Heal-specific one) is a
  percentage of that base, the caster's MATK band is rolled and added flat on
  top, and the trait heal bonus is a final percentage of the whole. The MATK
  band is the caster's base MATK plus weapon MATK variance only: flat item and
  status MATK never reach it. With no MATK weapon the band collapses and the
  heal is deterministic.

  Pre-renewal: the base is `(base level + INT) / 8 * (4 + skill level * 8)`,
  with no MATK term and no trait bonus. Equipment heal power is a percentage of
  that base and that is the whole amount. Heal therefore scales with the caster's
  magic gear in renewal and with nothing but level and INT in pre-renewal, and
  the classic ladder is the higher of the two at full skill level.

  The caster's stats are read generically through `caster.__struct__.to_combatant/1`,
  so a `%MobState{}` caster heals off its own INT and base level the same way a
  player does; mobs simply have no equipment (heal power reads as 0) and no trait
  heal bonus.

  Still deferred in both modes: Meditatio's caster-side heal-power bonus.
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

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal.Formula
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
    amount = compute_heal(combatant, level, offensive?, 28)

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

  @doc """
  The Heal amount for `combatant` at `level`; an offensive cast (undead target)
  halves the base. Shared with B.S. Sacramenti, whose strike uses the same formula;
  `skill_id` scopes the per-skill heal bonus from equipment to the casting skill.
  """
  @spec compute_heal(map(), pos_integer(), boolean(), pos_integer()) :: non_neg_integer()
  def compute_heal(combatant, level, offensive?, skill_id) do
    combat_stats = combatant.combat_stats
    matk_min = Map.get(combat_stats, :heal_matk_min, combat_stats.matk)
    matk_max = Map.get(combat_stats, :heal_matk_max, combat_stats.matk)

    heal_power =
      Map.get(combatant.equip_modifiers, :heal_power, 0) +
        Map.get(combatant.equip_modifiers, {:skill_heal, skill_id}, 0)

    Formula.calculate(GameMode.mode(), %{
      base_level: combatant.progression.base_level,
      int: combatant.base_stats.int,
      level: level,
      matk_roll: DamageShared.roll(matk_min, matk_max),
      heal_power: heal_power,
      hplus: Map.get(combat_stats, :hplus, 0),
      offensive?: offensive?
    })
  end

  defp target_ref({unit_type, unit_id} = ref) do
    if Ref.valid?(ref), do: {unit_type, unit_id}, else: raise(ArgumentError, "invalid target ref")
  end

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
