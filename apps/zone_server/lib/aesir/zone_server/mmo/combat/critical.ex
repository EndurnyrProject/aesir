defmodule Aesir.ZoneServer.Mmo.Combat.Critical do
  @moduledoc """
  Whether a physical attack is critical.

  Only players and mercenaries carry a critical rate; every other unit never
  crits. The chance starts from the attacker's per-mille critical rate (none at
  all when it is zero), adds the equipment's per-race critical bonus, loses twice
  the target's LUK (three times for a non-player attacking a player), doubles
  against a sleeping target, is divided by the skill's divisor, adds the skill's
  own bonus and finally loses a player target's equipment critical defense
  percent (bCriticalDef). The roll is
  `random(0..999) < chance`.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime.Numeric
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AutoCounter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @critical_unit_types [:player, :mercenary]

  @doc """
  The per-mille critical chance of `attacker` hitting `defender`; zero or less
  never crits.

  ## Options
    - `:normal_attack` - a normal attack: a player's bow or gun swing adds the
      ammunition and long-range critical bonuses (default `false`).
    - `:skill_divisor` - the skill's divisor (Soul Destroyer's 2), applied after
      the sleep doubling and truncating toward zero (default `1`).
    - `:skill_bonus` - the skill's own per-mille bonus, added last (default `0`).
  """
  @spec chance(Combatant.t(), Combatant.t(), keyword()) :: integer()
  def chance(%Combatant{} = attacker, %Combatant{} = defender, opts) do
    case critical_rate(attacker) do
      0 ->
        0

      rate ->
        chance =
          rate + EquipmentBonuses.critical_add_race_rate(attacker, defender) * 10 +
            arrow_bonus(attacker, Keyword.get(opts, :normal_attack, false)) -
            DamageInputs.effective_luk(defender) * luk_factor(attacker, defender)

        (div(sleep_factor(defender) * chance, Keyword.get(opts, :skill_divisor, 1)) +
           Keyword.get(opts, :skill_bonus, 0))
        |> critical_defense(defender)
    end
  end

  # A player's normal attack with a bow or gun is an arrow attack: the
  # ammunition's critical bonus and the long-range critical bonus count.
  defp arrow_bonus(%Combatant{unit_type: :player, weapon: %{type: type}} = attacker, true) do
    if WeaponTypes.requires_ammo?(type),
      do:
        (Map.get(attacker.equip_modifiers, :arrow_critical, 0) +
           EquipmentBonuses.critical_long_rate(attacker)) * 10,
      else: 0
  end

  defp arrow_bonus(_attacker, _normal_attack?), do: 0

  # A player target's equipment critical defense (bCriticalDef) scales the
  # chance last.
  defp critical_defense(chance, %Combatant{unit_type: :player, equip_modifiers: modifiers}) do
    case Map.get(modifiers, :critical_def, 0) do
      0 -> chance
      percent -> div(chance * (100 - percent), 100)
    end
  end

  defp critical_defense(chance, _defender), do: chance

  defp sleep_factor(%Combatant{unit_type: type, unit_id: id}) do
    if StatusStorage.has_status?(type, id, :sc_sleep), do: 2, else: 1
  end

  @doc """
  Decides a normal attack's critical.

  A unit without a critical rate never crits. A Double Attack swing
  (`multi_hit: true`) never crits. A holder of Auto Counter that swings
  normally plays the Auto Counter effect, ends the stance and crits for
  certain. Otherwise the chance is rolled.

  ## Options
    - `:multi_hit` - the swing is a Double Attack (default `false`).
  """
  @spec normal_attack?(Combatant.t(), Combatant.t(), keyword()) :: boolean()
  def normal_attack?(%Combatant{} = attacker, %Combatant{} = defender, opts) do
    cond do
      critical_rate(attacker) == 0 -> false
      Keyword.get(opts, :multi_hit, false) -> false
      AutoCounter.claim_by_swing(attacker.unit_type, attacker.unit_id) -> true
      true -> roll?(attacker, defender, normal_attack: true)
    end
  end

  @doc "Rolls `chance/3` with the same options."
  @spec roll?(Combatant.t(), Combatant.t(), keyword()) :: boolean()
  def roll?(%Combatant{} = attacker, %Combatant{} = defender, opts),
    do: CriticalHits.is_critical_hit?(chance(attacker, defender, opts))

  @doc "Whether `unit` has a critical rate at all: only such units ever crit."
  @spec capable?(Combatant.t()) :: boolean()
  def capable?(%Combatant{} = unit), do: critical_rate(unit) != 0

  @doc """
  The renewal critical multiplier, `1.4 + 0.01 * crate`, applied in single
  precision and floored. A unit without CRate passes `0`.
  """
  @spec multiply(integer(), integer()) :: integer()
  def multiply(damage, crate) do
    factor =
      Numeric.float32(Numeric.float32(1.4) + Numeric.float32(Numeric.float32(0.01) * crate))

    (Numeric.float32(damage) * factor)
    |> Numeric.float32()
    |> Float.floor()
    |> trunc()
  end

  defp critical_rate(%Combatant{unit_type: type} = attacker) when type in @critical_unit_types,
    do: status_critical_rate(attacker)

  defp critical_rate(_attacker), do: 0

  defp status_critical_rate(%Combatant{combat_stats: %{critical_rate: rate}})
       when is_integer(rate),
       do: rate

  defp status_critical_rate(%Combatant{combat_stats: %{critical: display}})
       when is_integer(display),
       do: display * 10

  defp status_critical_rate(%Combatant{base_stats: stats, progression: progression}) do
    base_level = Map.get(progression || %{}, :base_level, 0)
    CriticalHits.calculate_critical_rate(%{luk: stats.luk, base_level: base_level})
  end

  defp luk_factor(%Combatant{unit_type: :player}, _defender), do: 2
  defp luk_factor(_attacker, %Combatant{unit_type: :player}), do: 3
  defp luk_factor(_attacker, _defender), do: 2
end
