defmodule Aesir.ZoneServer.Mmo.Combat.BattleFlags do
  @moduledoc """
  The trigger-condition vocabulary shared by equip bonuses and combat.

  Item scripts can qualify a bonus with the kind of attack that triggers it:
  a resist that only applies against magic, an on-hit status that only procs on
  melee, an autocast that only fires on normal weapon swings. Two closely
  related bitmasks express that:

  - **Battle flags** describe an attack itself along three independent axes -
    damage type (weapon/magic/misc), range (short/long), and origin
    (skill/normal). `build/1` derives one for a hit; resist and autocast
    families match against it.
  - **Trigger flags** are the on-hit status family's variant. They carry the
    same type and range axes plus a victim axis (self/target) that decides who
    the inflicted status lands on.

  Both are normalized at transpile time: a script that names only some axes has
  the rest filled with defaults (`fill_battle/1`, `fill_trigger/1`), so a stored
  flag is always complete and matching is a pure per-axis intersection. An axis
  the script left unspecified therefore matches every attack on that axis.

  A flag of `0` means the bonus carries no trigger condition at all - the
  unqualified `bonus`/`bonus2` forms - and always applies.
  """

  import Bitwise

  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.BattleFlag

  @weapon BattleFlag.id(:weapon)
  @magic BattleFlag.id(:magic)
  @misc BattleFlag.id(:misc)
  @short BattleFlag.id(:short)
  @long BattleFlag.id(:long)
  @skill BattleFlag.id(:skill)
  @normal BattleFlag.id(:normal)

  @type_mask @weapon ||| @magic ||| @misc
  @range_mask @short ||| @long
  @origin_mask @skill ||| @normal

  @trigger_self AutoTriggerFlag.id(:self)
  @trigger_target AutoTriggerFlag.id(:target)
  @trigger_short AutoTriggerFlag.id(:short)
  @trigger_long AutoTriggerFlag.id(:long)
  @trigger_weapon AutoTriggerFlag.id(:weapon)
  @trigger_magic AutoTriggerFlag.id(:magic)
  @trigger_misc AutoTriggerFlag.id(:misc)

  @trigger_type_mask @trigger_weapon ||| @trigger_magic ||| @trigger_misc
  @trigger_range_mask @trigger_short ||| @trigger_long
  @trigger_victim_mask @trigger_self ||| @trigger_target

  @typedoc "A normalized battle flag: the bitwise union of one or more axis bits."
  @type flag :: non_neg_integer()

  @typedoc "The damage type of an attack."
  @type damage_type :: :weapon | :magic | :misc

  @typedoc "Whether an attack lands at melee or ranged distance."
  @type range :: :short | :long

  @doc "The battle-flag bit for a damage type."
  @spec type_bit(damage_type()) :: flag()
  def type_bit(:weapon), do: @weapon
  def type_bit(:magic), do: @magic
  def type_bit(:misc), do: @misc

  @doc "The battle-flag bit for an attack range."
  @spec range_bit(range()) :: flag()
  def range_bit(:short), do: @short
  def range_bit(:long), do: @long

  @doc "The battle-flag bit distinguishing a skill-sourced hit from a normal attack."
  @spec origin_bit(boolean()) :: flag()
  def origin_bit(true), do: @skill
  def origin_bit(false), do: @normal

  @doc """
  Builds the battle flag describing one hit.

  `skill?` marks a hit sourced from a skill rather than a normal attack, which
  is the axis autocast entries use to fire on swings but not on skills.
  """
  @spec build(damage_type(), range(), boolean()) :: flag()
  def build(damage_type, range, skill?) do
    type_bit(damage_type) ||| range_bit(range) ||| origin_bit(skill?)
  end

  @doc """
  Fills the axes a battle-flag script argument left unspecified.

  An unnamed range matches both distances, an unnamed damage type means weapon,
  and an unnamed origin follows the type: magic and misc bonuses can only ever
  come from a skill, while a weapon bonus covers both normal swings and skills.
  """
  @spec fill_battle(flag()) :: flag()
  def fill_battle(flag) when is_integer(flag) and flag >= 0 do
    flag
    |> fill_axis(@range_mask, @range_mask)
    |> fill_axis(@type_mask, @weapon)
    |> fill_origin()
  end

  @doc """
  Fills the axes a trigger-flag script argument left unspecified: both ranges,
  the enemy as victim, and weapon as damage type.
  """
  @spec fill_trigger(flag()) :: flag()
  def fill_trigger(flag) when is_integer(flag) and flag >= 0 do
    flag
    |> fill_axis(@trigger_range_mask, @trigger_range_mask)
    |> fill_axis(@trigger_victim_mask, @trigger_target)
    |> fill_axis(@trigger_type_mask, @trigger_weapon)
  end

  @doc """
  Whether a stored battle flag triggers on an attack.

  Every axis must intersect: a weapon-flagged bonus never fires on magic, a
  short-flagged one never on a ranged hit. An unconditional bonus (flag `0`)
  always matches.
  """
  @spec matches_battle?(flag(), flag()) :: boolean()
  def matches_battle?(0, _attack_flag), do: true

  def matches_battle?(entry_flag, attack_flag) do
    common = entry_flag &&& attack_flag

    (common &&& @type_mask) != 0 and (common &&& @range_mask) != 0 and
      (common &&& @origin_mask) != 0
  end

  @doc """
  Whether a stored trigger flag fires on an attack described by `attack_flag`.

  The type and range axes are only consulted when the entry narrows them: an
  entry naming every type, or both ranges, imposes no restriction on that axis.
  """
  @spec matches_trigger?(flag(), flag()) :: boolean()
  def matches_trigger?(0, _attack_flag), do: true

  def matches_trigger?(entry_flag, attack_flag) do
    trigger_type_matches?(entry_flag, attack_flag) and
      trigger_range_matches?(entry_flag, attack_flag)
  end

  @doc "Whether a trigger flag inflicts on the attack's other party."
  @spec target_victim?(flag()) :: boolean()
  def target_victim?(flag), do: flag == 0 or (flag &&& @trigger_target) != 0

  @doc "Whether a trigger flag inflicts on its own wearer."
  @spec self_victim?(flag()) :: boolean()
  def self_victim?(flag), do: flag != 0 and (flag &&& @trigger_self) != 0

  @spec trigger_type_matches?(flag(), flag()) :: boolean()
  defp trigger_type_matches?(entry_flag, attack_flag) do
    named = entry_flag &&& @trigger_type_mask

    named == @trigger_type_mask or
      ((named &&& @trigger_weapon) != 0 and (attack_flag &&& @weapon) != 0) or
      ((named &&& @trigger_magic) != 0 and (attack_flag &&& @magic) != 0) or
      ((named &&& @trigger_misc) != 0 and (attack_flag &&& @misc) != 0)
  end

  @spec trigger_range_matches?(flag(), flag()) :: boolean()
  defp trigger_range_matches?(entry_flag, attack_flag) do
    named = entry_flag &&& @trigger_range_mask

    named == @trigger_range_mask or
      ((named &&& @trigger_short) != 0 and (attack_flag &&& @short) != 0) or
      ((named &&& @trigger_long) != 0 and (attack_flag &&& @long) != 0)
  end

  # Leaves an axis alone when the script named any of its bits, otherwise
  # applies the axis default.
  @spec fill_axis(flag(), flag(), flag()) :: flag()
  defp fill_axis(flag, axis_mask, default) do
    if (flag &&& axis_mask) == 0, do: flag ||| default, else: flag
  end

  @spec fill_origin(flag()) :: flag()
  defp fill_origin(flag) when (flag &&& @origin_mask) != 0, do: flag

  defp fill_origin(flag) do
    flag
    |> then(fn f -> if (f &&& (@magic ||| @misc)) != 0, do: f ||| @skill, else: f end)
    |> then(fn f -> if (f &&& @weapon) != 0, do: f ||| @normal ||| @skill, else: f end)
  end
end
