defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutocast do
  @moduledoc """
  Equipment-granted autocasts: a worn item casting a skill by itself.

  Three triggers arm from item scripts. An `:attack` proc fires on the wearer's
  own hits, a `:when_hit` proc on hits the wearer takes, and an on-skill proc on
  the wearer using a named skill. Attack and when-hit procs are stored as
  `{:auto_cast, {trigger, skill_id, level, flag, force}}` entries in the
  wearer's equipment modifiers, valued by their per-mille chance.

  Selection (`on_attack/4`, `when_hit/3`, `on_skill/3`) is pure: it returns the
  entries whose trigger matches as candidates, with the chance already capped
  and halved where the hit halves it. The wearer's own session then resolves
  each candidate with `resolve/2`, which runs the usability check and the level
  and chance draws in the order of its branch.

  An attack proc's chance halves while the wearer is in the arrow-attack state;
  a when-hit proc's halves against long-range weapon damage.
  """

  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant

  @roll_ceiling 1_000
  @rate_cap 1_000

  @typedoc "Which proc family a candidate belongs to; each resolves in its own order."
  @type branch :: :attack | :counter | :skill

  @typedoc """
  A selected proc: the skill and armed level, whether the level is drawn at
  random up to it, the effective per-mille chance, the cast target (nil when an
  on-skill proc has none) and the modifier entry that armed it.
  """
  @type candidate :: %{
          branch: branch(),
          skill_id: pos_integer(),
          level: pos_integer(),
          random_level?: boolean(),
          rate: integer(),
          target: :self | {:unit, integer()} | nil,
          entry: term()
        }

  @typedoc "How `resolve/2` ended: cast at a level, dropped, or refused by usability."
  @type resolution :: {:cast, pos_integer()} | :skip | {:unusable, atom()}

  @doc """
  Selects the attacker's `:attack` procs whose battle flag matches the hit.

  `arrow_attack?` is the attacker's arrow-attack state when the hit resolves; it
  halves the chance.
  """
  @spec on_attack(Combatant.t(), Combatant.t(), BattleFlags.flag(), boolean()) :: [candidate()]
  def on_attack(%Combatant{} = attacker, %Combatant{} = defender, attack_flag, arrow_attack?) do
    attacker.equip_modifiers
    |> battle_entries(:attack, attack_flag)
    |> Enum.map(fn {entry, {skill_id, level, force}, rate} ->
      target = if force_target?(force), do: {:unit, defender.unit_id}, else: :self
      candidate(:attack, entry, skill_id, level, force, halve(rate, arrow_attack?), target)
    end)
  end

  @doc """
  Selects the defender's `:when_hit` procs whose battle flag matches the hit.

  The chance halves against long-range weapon damage. The target bit sends the
  proc at the attacker (`attacker_id`); otherwise it stays on the defender.
  """
  @spec when_hit(%{equip_modifiers: map()}, integer(), BattleFlags.flag()) :: [candidate()]
  def when_hit(%{equip_modifiers: modifiers}, attacker_id, attack_flag) do
    halved? = long_weapon_hit?(attack_flag)

    modifiers
    |> battle_entries(:when_hit, attack_flag)
    |> Enum.map(fn {entry, {skill_id, level, force}, rate} ->
      target = if force_target?(force), do: {:unit, attacker_id}, else: :self
      candidate(:counter, entry, skill_id, level, force, halve(rate, halved?), target)
    end)
  end

  # The `trigger` entries whose battle flag matches the hit, in modifier order.
  defp battle_entries(modifiers, trigger, attack_flag) do
    for {{:auto_cast, {^trigger, skill_id, level, flag, force}} = entry, rate} <- modifiers,
        BattleFlags.matches_battle?(flag, attack_flag),
        do: {entry, {skill_id, level, force}, rate}
  end

  @doc """
  Selects the caster's on-skill procs for one use of `trigger_skill`.

  These carry no attack kinds, and their target bit reads inverted: setting it
  keeps the proc on the caster, while its absence sends it at whatever the
  triggering skill targeted (`nil` when it targeted no unit).
  """
  @spec on_skill(map(), pos_integer(), :self | {:unit, integer()} | nil) :: [candidate()]
  def on_skill(equip_modifiers, trigger_skill, skill_target) when is_map(equip_modifiers) do
    Enum.flat_map(equip_modifiers, fn
      {{:auto_cast_on_skill, {^trigger_skill, skill_id, level, force}} = entry, rate} ->
        target = if force_target?(force), do: :self, else: skill_target
        [candidate(:skill, entry, skill_id, level, force, min(rate, @rate_cap), target)]

      _entry ->
        []
    end)
  end

  @doc """
  Resolves one candidate in its wearer's session, in its branch's order.

  An attack proc checks usability, draws its level, then rolls its chance. A
  counter proc draws its level before the usability check. An on-skill proc
  checks usability, drops a candidate without a target, rolls, then draws its
  level. A failed usability check returns its reason and stops before the roll.

  ## Options
    - `:usable` - `(skill_id -> :ok | {:error, atom()})`, the usability check (required).
    - `:roll` - a per-mille chance predicate (default `:rand`).
    - `:level_roll` - picks a level from 1 up to the armed one (default `:rand`).
  """
  @spec resolve(candidate(), keyword()) :: resolution()
  def resolve(%{branch: :attack} = candidate, opts) do
    with :ok <- usable(candidate, opts) do
      level = draw_level(candidate, opts)
      if roll(candidate, opts), do: {:cast, level}, else: :skip
    end
  end

  def resolve(%{branch: :counter} = candidate, opts) do
    level = draw_level(candidate, opts)

    with :ok <- usable(candidate, opts) do
      if roll(candidate, opts), do: {:cast, level}, else: :skip
    end
  end

  def resolve(%{branch: :skill} = candidate, opts) do
    with :ok <- usable(candidate, opts) do
      cond do
        is_nil(candidate.target) -> :skip
        roll(candidate, opts) -> {:cast, draw_level(candidate, opts)}
        true -> :skip
      end
    end
  end

  defp usable(candidate, opts) do
    case Keyword.fetch!(opts, :usable).(candidate.skill_id) do
      :ok -> :ok
      {:error, reason} -> {:unusable, reason}
    end
  end

  defp roll(%{rate: rate}, opts) do
    rate > 0 and Keyword.get(opts, :roll, &default_roll/1).(rate)
  end

  defp draw_level(%{random_level?: true, level: level}, opts),
    do: Keyword.get(opts, :level_roll, &:rand.uniform/1).(level)

  defp draw_level(%{level: level}, _opts), do: level

  defp candidate(branch, entry, skill_id, level, force, rate, target) do
    %{
      branch: branch,
      skill_id: skill_id,
      level: level,
      random_level?: Bitwise.band(force, AutospellForceFlag.id(:random_level)) != 0,
      rate: rate,
      target: target,
      entry: entry
    }
  end

  @spec halve(integer(), boolean()) :: integer()
  defp halve(rate, true), do: div(min(rate, @rate_cap), 2)
  defp halve(rate, false), do: min(rate, @rate_cap)

  @spec force_target?(non_neg_integer()) :: boolean()
  defp force_target?(force), do: Bitwise.band(force, AutospellForceFlag.id(:target)) != 0

  # Only long-range *weapon* damage halves a when-hit proc; magic and misc hits
  # roll at full chance whatever their range.
  @spec long_weapon_hit?(BattleFlags.flag()) :: boolean()
  defp long_weapon_hit?(attack_flag) do
    weapon_long = Bitwise.bor(BattleFlags.type_bit(:weapon), BattleFlags.range_bit(:long))

    Bitwise.band(attack_flag, weapon_long) == weapon_long
  end

  @spec default_roll(integer()) :: boolean()
  defp default_roll(rate), do: :rand.uniform(@roll_ceiling) <= rate
end
