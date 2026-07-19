defmodule Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses do
  @moduledoc """
  Pure read surface combat uses for equipment-granted damage bonuses.

  Every read sums a family's specific-param key with its `:all` key
  (`Map.get(combatant.equip_modifiers, key, 0)`), matching how the status
  modifier tuple keys already sum in the magic calculator. Mobs carry an
  empty `equip_modifiers` map, so every read is zero for them.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @typedoc "A percent (or per-mille, depending on family) sum read from equip_modifiers."
  @type rate :: integer()

  @doc """
  Physical attack-side rate sums keyed on the defender's traits.

  Race and class share one family group per renewal (`race_class`). `bAddEle`
  keys on the defender's own defense element (`defender.element`), not the
  attack's element, so `attack_element` is accepted for call-site symmetry
  with `damage_taken_rates/3` but is not read here.
  """
  @spec attack_rates(Combatant.t(), Combatant.t(), pos_integer() | nil, atom()) :: %{
          race_class: rate(),
          element: rate(),
          size: rate(),
          skill: rate()
        }
  def attack_rates(%Combatant{} = attacker, %Combatant{} = defender, skill_id, _attack_element) do
    %{
      race_class:
        read(attacker, :addrace, defender.race) + read(attacker, :addclass, defender.class),
      element: read(attacker, :addele, element_atom(defender.element)),
      size: read(attacker, :addsize, defender.size),
      skill: skill_rate(attacker, :skill_atk, skill_id)
    }
  end

  @doc """
  Damage-taken-side rate sums keyed on the attacker's traits, read off the
  defender's own equipment.
  """
  @spec damage_taken_rates(Combatant.t(), Combatant.t(), atom()) :: %{
          race_class: rate(),
          element: rate(),
          size: rate()
        }
  def damage_taken_rates(%Combatant{} = defender, %Combatant{} = attacker, attack_element) do
    %{
      race_class:
        read(defender, :subrace, attacker.race) + read(defender, :subclass, attacker.class),
      element: read(defender, :subele, attack_element),
      size: read(defender, :subsize, attacker.size)
    }
  end

  @doc """
  Magic attack-side rate sums keyed on the defender's traits and the spell's
  element.
  """
  @spec magic_attack_rates(Combatant.t(), Combatant.t(), pos_integer() | nil, atom()) :: %{
          race: rate(),
          element_target: rate(),
          size: rate(),
          atk_ele: rate(),
          skill: rate()
        }
  def magic_attack_rates(
        %Combatant{} = attacker,
        %Combatant{} = defender,
        skill_id,
        spell_element
      ) do
    %{
      race: read(attacker, :magic_addrace, defender.race),
      element_target: read(attacker, :magic_addele, element_atom(defender.element)),
      size: read(attacker, :magic_addsize, defender.size),
      atk_ele: read(attacker, :magic_atk_ele, spell_element),
      skill: skill_rate(attacker, :skill_atk, skill_id)
    }
  end

  @doc """
  Percent damage bonus the attacker's equipment grants to long-range physical
  attacks (`bLongAtkRate`).

  The bonus belongs to the long-attack damage class, so it is read only when the
  attacker swings a ranged weapon; melee attackers — and every mob, which
  carries no equipment — read zero.
  """
  @spec long_atk_rate(Combatant.t()) :: rate()
  def long_atk_rate(%Combatant{} = attacker) do
    if attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() do
      Map.get(attacker.equip_modifiers, :long_atk_rate, 0)
    else
      0
    end
  end

  @doc """
  Percent damage bonus the attacker's equipment grants to close-range physical
  attacks (`bShortAtkRate`).

  The exact counterpart of `long_atk_rate/1`: the bonus belongs to the melee
  damage class, so it is read only when the attacker swings a non-ranged
  weapon. Ranged attackers — and every mob, which carries no equipment — read
  zero.
  """
  @spec short_atk_rate(Combatant.t()) :: rate()
  def short_atk_rate(%Combatant{} = attacker) do
    if attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?() do
      0
    else
      Map.get(attacker.equip_modifiers, :short_atk_rate, 0)
    end
  end

  @doc """
  Per-mille chance the attacker's equipment grants to land a perfect hit
  (`bPerfectHitAddRate`), an attack that ignores the defender's flee entirely.

  Ungated by weapon or target: any attacker's equipment can carry it, and mobs
  read zero.
  """
  @spec perfect_hit_rate(Combatant.t()) :: rate()
  def perfect_hit_rate(%Combatant{} = attacker) do
    Map.get(attacker.equip_modifiers, :perfect_hit, 0)
  end

  @doc """
  Per-mille chance the attacker's equipment grants to drain HP from the damage
  a normal attack deals (`bonus2 bHPDrainRate,rate,per` first argument).
  """
  @spec hp_drain_rate(Combatant.t()) :: rate()
  def hp_drain_rate(%Combatant{} = attacker) do
    Map.get(attacker.equip_modifiers, :hp_drain_rate, 0)
  end

  @doc """
  Percent of the damage dealt the attacker recovers as HP when a drain roll
  succeeds (`bonus2 bHPDrainRate,rate,per` second argument).
  """
  @spec hp_drain_percent(Combatant.t()) :: rate()
  def hp_drain_percent(%Combatant{} = attacker) do
    Map.get(attacker.equip_modifiers, :hp_drain_percent, 0)
  end

  @doc """
  Radius in cells of the area-of-effect the attacker's equipment adds around the
  primary target of a normal attack (`bSplashRange`). Zero means the attack hits
  only its target.
  """
  @spec splash_range(Combatant.t()) :: non_neg_integer()
  def splash_range(%Combatant{} = attacker) do
    max(Map.get(attacker.equip_modifiers, :splash_range, 0), 0)
  end

  @doc """
  Percent of the defender's hard DEF ignored by the attacker's equipment,
  capped at 100.
  """
  @spec ignore_def_rate(Combatant.t(), atom()) :: rate()
  def ignore_def_rate(%Combatant{} = attacker, defender_race) do
    min(read(attacker, :ignore_def_race, defender_race), 100)
  end

  @doc """
  Percent of the defender's hard MDEF ignored by the attacker's equipment,
  capped at 100.
  """
  @spec ignore_mdef_rate(Combatant.t(), atom()) :: rate()
  def ignore_mdef_rate(%Combatant{} = attacker, defender_race) do
    min(read(attacker, :ignore_mdef_race, defender_race), 100)
  end

  @spec read(Combatant.t(), atom(), atom()) :: rate()
  defp read(combatant, family, param) do
    Map.get(combatant.equip_modifiers, {family, param}, 0) +
      Map.get(combatant.equip_modifiers, {family, :all}, 0)
  end

  @spec skill_rate(Combatant.t(), atom(), pos_integer() | nil) :: rate()
  defp skill_rate(_combatant, _family, nil), do: 0

  defp skill_rate(combatant, family, skill_id) when is_integer(skill_id) do
    Map.get(combatant.equip_modifiers, {family, skill_id}, 0)
  end

  @spec element_atom(tuple() | atom()) :: atom()
  defp element_atom({element, _level}), do: element
  defp element_atom(element) when is_atom(element), do: element
end
