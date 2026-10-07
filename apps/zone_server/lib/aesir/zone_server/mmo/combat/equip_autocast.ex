defmodule Aesir.ZoneServer.Mmo.Combat.EquipAutocast do
  @moduledoc """
  Equipment-granted autocasts: a worn item casting a skill by itself.

  Three triggers arm from item scripts. An `:attack` proc fires on the wearer's
  own hits, a `:when_hit` proc on hits the wearer takes, and an `:on_skill` proc
  on the wearer using a named skill. Each trigger keeps its own ordered list of
  `t:entry/0` under the `{:auto_cast, trigger}` key of the wearer's equipment
  modifiers, built by `register/3` in the order the worn scripts run.

  Selection (`on_attack/4`, `when_hit/3`, `on_skill/3`) is pure: it returns the
  entries whose trigger matches as candidates, in list order, with the chance
  already halved where the hit halves it. The wearer's own session then
  resolves each candidate with `resolve/2`, which runs the usability check and
  the level and chance draws in the order of its branch.

  An attack proc's chance halves while the wearer is in the arrow-attack state;
  a when-hit proc's halves against long-range weapon damage.
  """

  alias Aesir.ZoneServer.Mmo.AutospellForceFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript

  @roll_ceiling 1_000
  @rate_cap 1_000
  @max_entries 50

  @typedoc "The trigger an autocast list arms on."
  @type trigger :: :attack | :when_hit | :on_skill

  @typedoc """
  One registered autocast: the skill and armed level (a level of 0 casts at
  level 1), the per-mille chance, the attack kinds that fire it (`0` for an
  on-skill proc), the force bits, and the id of the card that registered it
  (`0` for an item's own script). An on-skill entry also names the skill whose
  use fires it.
  """
  @type entry :: %{
          :skill_id => pos_integer(),
          :level => non_neg_integer(),
          :rate => integer(),
          :flag => non_neg_integer(),
          :force => non_neg_integer(),
          :card_id => non_neg_integer(),
          optional(:trigger_skill) => pos_integer()
        }

  @typedoc "Which proc family a candidate belongs to; each resolves in its own order."
  @type branch :: :attack | :counter | :skill

  @typedoc """
  A selected proc: the skill and armed level, whether the level is drawn at
  random up to it, the effective per-mille chance, the cast target (nil when an
  on-skill proc has none) and the `t:identity/0` of the entry that armed it.
  """
  @type candidate :: %{
          branch: branch(),
          skill_id: pos_integer(),
          level: pos_integer(),
          random_level?: boolean(),
          rate: integer(),
          target: :self | {:unit, integer()} | nil,
          entry: identity()
        }

  @typedoc """
  One registration's identity: its trigger, its position in that trigger's list
  and the entry itself. Identical registrations differ by position.
  """
  @type identity :: {trigger(), non_neg_integer(), entry()}

  @typedoc "How `resolve/2` ended: cast at a level, dropped, or refused by usability."
  @type resolution :: {:cast, pos_integer()} | :skip | {:unusable, atom()}

  @doc """
  Registers one evaluated autocast into the equipment `modifiers`, at the end
  of its trigger's list. `card_id` is the card whose script armed it, `0` for an
  item's own script or an autobonus.

  A list holding 50 entries takes no more, and a zero chance registers nothing;
  the chance and level are first narrowed to the signed 16-bit and unsigned
  16-bit values the entry stores. An on-skill registration always appends its
  own entry. An attack or when-hit registration merges into the first entry with
  the same skill, level, attack kinds and force bits whose card is the same, or
  when either chance is negative: two positive chances keep the earlier one
  (autocasts do not stack), otherwise the chances add, capped above at 1000
  (with no floor, and at 1000 if the sum leaves the 16-bit range). A new entry's
  chance is capped to -1000..1000.
  """
  @spec register(map(), EquipScript.auto_cast(), non_neg_integer()) :: map()
  def register(modifiers, %{trigger: trigger} = registration, card_id)
      when is_integer(card_id) and card_id >= 0 do
    key = {:auto_cast, trigger}
    list = Map.get(modifiers, key, [])
    rate = int16(registration.rate)

    if length(list) >= @max_entries or rate == 0 do
      modifiers
    else
      entry =
        registration
        |> Map.delete(:trigger)
        |> Map.merge(%{level: Bitwise.band(registration.level, 0xFFFF), card_id: card_id})

      Map.put(modifiers, key, add_entry(trigger, list, entry, rate))
    end
  end

  defp add_entry(:on_skill, list, entry, rate), do: list ++ [new_entry(entry, rate)]

  defp add_entry(_trigger, list, entry, rate) do
    case Enum.find_index(list, &same_proc?(&1, entry, rate)) do
      nil -> list ++ [new_entry(entry, rate)]
      index -> List.update_at(list, index, &merge_rate(&1, rate))
    end
  end

  defp new_entry(entry, rate), do: %{entry | rate: rate |> max(-@rate_cap) |> min(@rate_cap)}

  defp same_proc?(existing, entry, rate) do
    (existing.card_id == entry.card_id or existing.rate < 0 or rate < 0) and
      existing.skill_id == entry.skill_id and existing.level == entry.level and
      existing.flag == entry.flag and existing.force == entry.force
  end

  defp merge_rate(%{rate: current} = existing, rate) when current > 0 and rate > 0, do: existing

  defp merge_rate(%{rate: current} = existing, rate) do
    sum = current + rate
    %{existing | rate: if(sum in -32_768..32_767, do: min(sum, @rate_cap), else: @rate_cap)}
  end

  defp int16(value) do
    <<narrowed::signed-16>> = <<value::16>>
    narrowed
  end

  @doc """
  Selects the attacker's `:attack` procs whose battle flag matches the hit.

  `arrow_attack?` is the attacker's arrow-attack state when the hit resolves; it
  halves the chance.
  """
  @spec on_attack(Combatant.t(), Combatant.t(), BattleFlags.flag(), boolean()) :: [candidate()]
  def on_attack(%Combatant{} = attacker, %Combatant{} = defender, attack_flag, arrow_attack?) do
    attacker.equip_modifiers
    |> battle_entries(:attack, attack_flag)
    |> Enum.map(fn {entry, identity} ->
      target = if force_target?(entry.force), do: {:unit, defender.unit_id}, else: :self
      candidate(:attack, identity, entry, halve(entry.rate, arrow_attack?), target)
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
    |> Enum.map(fn {entry, identity} ->
      target = if force_target?(entry.force), do: {:unit, attacker_id}, else: :self
      candidate(:counter, identity, entry, halve(entry.rate, halved?), target)
    end)
  end

  # The `trigger` entries whose battle flag matches the hit, in list order.
  defp battle_entries(modifiers, trigger, attack_flag) do
    modifiers
    |> indexed(trigger)
    |> Enum.filter(fn {entry, _identity} ->
      BattleFlags.matches_battle?(entry.flag, attack_flag)
    end)
  end

  defp indexed(modifiers, trigger) do
    modifiers
    |> Map.get({:auto_cast, trigger}, [])
    |> Enum.with_index(fn entry, index -> {entry, {trigger, index, entry}} end)
  end

  @doc """
  The identity `identity`'s entry has in the current `modifiers`.

  A candidate is selected before the wearer's session handles it, and a refold
  in between (an autobonus starting or ending, an equipment change) can move its
  entry within its list. The entry keeps its identity at its old position when
  it is still there, and otherwise takes the first identical entry's position;
  an entry no longer registered keeps the old identity, which then names no
  entry.
  """
  @spec current_identity(map(), identity()) :: identity()
  def current_identity(modifiers, {trigger, index, entry} = identity) do
    list = Map.get(modifiers, {:auto_cast, trigger}, [])

    cond do
      Enum.at(list, index) == entry -> identity
      new_index = Enum.find_index(list, &(&1 == entry)) -> {trigger, new_index, entry}
      true -> identity
    end
  end

  @doc """
  Selects the caster's on-skill procs for one use of `trigger_skill`.

  These carry no attack kinds, and their target bit reads inverted: setting it
  keeps the proc on the caster, while its absence sends it at whatever the
  triggering skill targeted (`nil` when it targeted no unit).
  """
  @spec on_skill(map(), pos_integer(), :self | {:unit, integer()} | nil) :: [candidate()]
  def on_skill(equip_modifiers, trigger_skill, skill_target) when is_map(equip_modifiers) do
    entries = indexed(equip_modifiers, :on_skill)

    for {%{trigger_skill: ^trigger_skill} = entry, identity} <- entries do
      target = if force_target?(entry.force), do: :self, else: skill_target
      candidate(:skill, identity, entry, entry.rate, target)
    end
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

  defp candidate(branch, identity, entry, rate, target) do
    %{
      branch: branch,
      skill_id: entry.skill_id,
      level: max(entry.level, 1),
      random_level?: Bitwise.band(entry.force, AutospellForceFlag.id(:random_level)) != 0,
      rate: rate,
      target: target,
      entry: identity
    }
  end

  @spec halve(integer(), boolean()) :: integer()
  defp halve(rate, true), do: div(rate, 2)
  defp halve(rate, false), do: rate

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
