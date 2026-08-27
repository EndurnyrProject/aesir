defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutocast do
  @moduledoc """
  Equipment-granted autocasts: a worn item casting a skill by itself.

  Two triggers arm from item scripts. An `:attack` proc rolls on the wearer's
  own landed hits, an `:when_hit` proc on hits the wearer takes. Both are
  stored as `{:auto_cast, {trigger, skill_id, level, flag, force}}` entries in
  the wearer's equipment modifiers, valued by their per-mille chance, so two
  items arming the identical proc stack their chances.

  This module only decides *what* procs: it rolls the matching entries and
  returns the casts to run, leaving delivery to the caller. That keeps the
  single-writer rule intact - an attack-side proc is cast by the attacker's own
  session, a when-hit proc is handed to the defender's session, and neither
  side ever writes the other's state. It mirrors how the `SC_AUTOSPELL` bolt
  reaches its caster.

  A ranged weapon swing rolls its attack-side procs at half chance, and a proc
  armed against long-range weapon damage likewise halves when hit by one.
  """

  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.WeaponTypes

  @roll_ceiling 1_000
  @rate_cap 1_000

  @typedoc "A per-mille chance predicate: given an effective chance, did the proc land."
  @type roll_fun :: (non_neg_integer() -> boolean())

  @typedoc "A proc to run: the skill, the level it casts at, and its target."
  @type proc :: {:auto_cast, pos_integer(), pos_integer(), :self | {:unit, integer()}}

  @doc """
  Rolls the attacker's `:attack` procs for one landed hit.

  The chance halves for a ranged weapon swing, matching how a bow attack arms
  these procs at half strength.

  ## Options
    - `:roll` - a `t:roll_fun/0` used for every per-mille roll (default `:rand`).
    - `:level_roll` - a `(pos_integer() -> pos_integer())` picking the level of a
      random-level proc (default `:rand`).
  """
  @spec on_attack(Combatant.t(), Combatant.t(), BattleFlags.flag(), keyword()) :: [proc()]
  def on_attack(%Combatant{} = attacker, %Combatant{} = defender, attack_flag, opts \\ []) do
    procs(attacker, defender, :attack, attack_flag, ranged_weapon?(attacker), opts)
  end

  @doc """
  Rolls the defender's `:when_hit` procs for one hit taken.

  The chance halves against long-range weapon damage. The returned casts belong
  to the defender and must be delivered to the defender's own session.
  """
  @spec when_hit(Combatant.t(), Combatant.t(), BattleFlags.flag(), keyword()) :: [proc()]
  def when_hit(%Combatant{} = defender, %Combatant{} = attacker, attack_flag, opts \\ []) do
    procs(defender, attacker, :when_hit, attack_flag, long_weapon_hit?(attack_flag), opts)
  end

  @spec procs(
          Combatant.t(),
          Combatant.t(),
          :attack | :when_hit,
          BattleFlags.flag(),
          boolean(),
          keyword()
        ) :: [proc()]
  defp procs(wearer, other, trigger, attack_flag, halved?, opts) do
    roll = Keyword.get(opts, :roll, &default_roll/1)
    level_roll = Keyword.get(opts, :level_roll, &default_level_roll/1)

    context = %{
      other: other,
      attack_flag: attack_flag,
      halved?: halved?,
      roll: roll,
      level_roll: level_roll
    }

    Enum.flat_map(wearer.equip_modifiers, fn
      {{:auto_cast, {^trigger, skill_id, level, flag, force}}, rate} ->
        proc({skill_id, level, flag, force, rate}, context)

      _entry ->
        []
    end)
  end

  @typedoc "Everything about the hit a single armed entry is rolled against."
  @type context :: %{
          other: Combatant.t(),
          attack_flag: BattleFlags.flag(),
          halved?: boolean(),
          roll: roll_fun(),
          level_roll: (pos_integer() -> pos_integer())
        }

  @spec proc(
          {pos_integer(), pos_integer(), BattleFlags.flag(), non_neg_integer(), integer()},
          context()
        ) :: [proc()]
  defp proc({skill_id, level, flag, force, rate}, context) do
    effective = effective_rate(rate, context.halved?)

    if BattleFlags.matches_battle?(flag, context.attack_flag) and effective > 0 and
         context.roll.(effective) do
      [
        {:auto_cast, skill_id, cast_level(level, force, context.level_roll),
         cast_target(force, context.other)}
      ]
    else
      []
    end
  end

  @spec effective_rate(integer(), boolean()) :: integer()
  defp effective_rate(rate, true), do: div(min(rate, @rate_cap), 2)
  defp effective_rate(rate, false), do: min(rate, @rate_cap)

  # The random-level bit makes the proc pick any level up to the armed one.
  @spec cast_level(pos_integer(), non_neg_integer(), (pos_integer() -> pos_integer())) ::
          pos_integer()
  defp cast_level(level, force, level_roll) do
    if random_level?(force), do: level_roll.(level), else: level
  end

  # Without the target bit the proc casts on its own wearer, which is how the
  # self-buff procs (Concentration, Aura Blade) are armed.
  @spec cast_target(non_neg_integer(), Combatant.t()) :: :self | {:unit, integer()}
  defp cast_target(force, other) do
    if force_target?(force), do: {:unit, other.unit_id}, else: :self
  end

  @spec force_target?(non_neg_integer()) :: boolean()
  defp force_target?(force), do: Bitwise.band(force, AutospellForceFlag.id(:target)) != 0

  @spec random_level?(non_neg_integer()) :: boolean()
  defp random_level?(force),
    do: Bitwise.band(force, AutospellForceFlag.id(:random_level)) != 0

  @spec ranged_weapon?(Combatant.t()) :: boolean()
  defp ranged_weapon?(attacker) do
    attacker.weapon |> Map.get(:type) |> WeaponTypes.is_ranged?()
  end

  # Only long-range *weapon* damage halves a when-hit proc; magic and misc hits
  # roll at full chance whatever their range.
  @spec long_weapon_hit?(BattleFlags.flag()) :: boolean()
  defp long_weapon_hit?(attack_flag) do
    weapon_long = Bitwise.bor(BattleFlags.type_bit(:weapon), BattleFlags.range_bit(:long))

    Bitwise.band(attack_flag, weapon_long) == weapon_long
  end

  @spec default_roll(non_neg_integer()) :: boolean()
  defp default_roll(effective), do: :rand.uniform(@roll_ceiling) <= effective

  @spec default_level_roll(pos_integer()) :: pos_integer()
  defp default_level_roll(level), do: :rand.uniform(level)
end
