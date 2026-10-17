defmodule Aesir.ZoneServer.Mmo.Combat.DamageShared do
  @moduledoc """
  Type-agnostic damage tail shared by the physical and magic calculators.

  Pulls the element-resistance step, the generic `damage_multiplier`, and the
  min-1 clamp out of the per-type calculators so both the physical
  `DamageCalculator` and the magic calculator apply them identically.

  Type-specific steps (physical `atk_bonus`/`damage_bonus` additive, weapon
  attack, MATK build) stay in their respective calculators.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  @typedoc """
  A skill's hit divisions as the source declares them: positive `n` repeats the
  one calculated damage `n` times, negative `-n` splits it into `n` equal parts.
  """
  @type signed_divisions :: integer()

  @typedoc """
  One resolved attack as the target sees it: the normalized total, the
  non-negative division count shown by the client, whether it connected, its
  result class, and the battle flag classifying it for triggered bonuses.
  """
  @type logical_hit :: %{
          damage: integer(),
          divisions: non_neg_integer(),
          hit?: boolean(),
          hit_class: :miss | :block | :hit,
          attack_flag: BattleFlags.flag()
        }

  @doc """
  Classifies one settled hit as its additional and counter stages see it.

  A Magic Rod interception is a miss and a blocking status's stop a block. A
  reflected hit connected even when it reaches its new target for nothing, as
  does a hit dealt as connected without being calculated (`connected?: true`,
  e.g. the zero-damage hit Wink of Charm deals a monster it charms).
  Any other hit whose total before Devotion forwarding (`settled_total/2`) is
  below 1 is a miss. A Devotion-forwarded hit that resolves after the attack
  motion (not `immediate?`) is a block. Everything else connected (`:hit`).
  """
  @spec hit_class(map(), integer(), boolean()) :: :miss | :block | :hit
  def hit_class(%{magic_rod_miss?: true}, _damage, _immediate?), do: :miss
  def hit_class(%{blocked?: true}, _damage, _immediate?), do: :block
  def hit_class(%{reflected: true}, _damage, _immediate?), do: :hit
  def hit_class(%{connected?: true}, _damage, _immediate?), do: :hit

  def hit_class(hit_info, damage, immediate?) do
    cond do
      settled_total(hit_info, damage) < 1 -> :miss
      Map.get(hit_info, :devotion_rerouted?, false) and not immediate? -> :block
      true -> :hit
    end
  end

  @doc """
  Whether a delivered damage notification is active damage, the only kind that
  breaks damage-broken statuses, counts against Endure and interrupts a cast.

  Passive HP loss (`:passive?`, `:status_tick?`) never is, nor is a hit Devotion
  forwarded to the Crusader, for the devotee. An attack (metadata carrying
  `:dmg_type`) is only when it connected (`hit_class/3` is `:hit`): a missed or
  blocked attack never reaches the target's damage handling at all. Any other
  notification is, even when it took no HP.
  """
  @spec active_damage?(map()) :: boolean()
  def active_damage?(%{passive?: true}), do: false
  def active_damage?(%{status_tick?: true}), do: false
  def active_damage?(%{devotion_rerouted?: true}), do: false

  def active_damage?(%{dmg_type: _} = info),
    do: hit_class(info, Map.get(info, :damage, 0), true) == :hit

  def active_damage?(_info), do: true

  @doc """
  Whether delivering `damage` with `hit_info` stops a walking target that does
  not endure it: a battle hit (an attack, or damage reflected back at its
  attacker) that deals at least 1. Status ticks, passive HP loss, the damage
  Devotion forwards to the Crusader and a fixed hit marked `walk_delay?: false`
  never do.
  """
  @spec walk_delay?(map(), integer()) :: boolean()
  def walk_delay?(_hit_info, damage) when damage < 1, do: false
  def walk_delay?(%{walk_delay?: false}, _damage), do: false
  def walk_delay?(%{passive?: true}, _damage), do: false
  def walk_delay?(%{status_tick?: true}, _damage), do: false
  def walk_delay?(%{redirected: true}, _damage), do: false
  def walk_delay?(%{dmg_type: _}, _damage), do: true
  def walk_delay?(%{reflected: true}, _damage), do: true
  def walk_delay?(_hit_info, _damage), do: false

  @doc """
  A settled hit's total before Devotion forwarding: the forwarded amount for a
  rerouted hit (the devotee itself takes 0), else `damage`.
  """
  @spec settled_total(map(), integer()) :: integer()
  def settled_total(%{devotion_rerouted?: true} = hit_info, damage),
    do: Map.get(hit_info, :devotion_damage, damage)

  def settled_total(_hit_info, damage), do: damage

  @doc """
  The division count a settled attack shows: a player's attack whose total
  before Devotion forwarding (`settled_total/2`) is below 1 shows one.
  """
  @spec display_divisions(map(), map(), integer(), non_neg_integer()) :: non_neg_integer()
  def display_divisions(%{unit_type: :player}, hit_info, damage, divisions) do
    if settled_total(hit_info, damage) < 1, do: 1, else: divisions
  end

  def display_divisions(_attacker, _hit_info, _damage, divisions), do: divisions

  @doc """
  Normalizes one calculated damage into its logical total and division count.

  Positive divisions multiply the damage; negative divisions floor it to an
  equal split of that many parts, so a total below the count becomes zero. Zero
  damage keeps the normalized count. An effective runtime count of zero (a
  restricted invocation that found no spheres) yields no damage and no
  divisions rather than a fabricated hit. Reference-specific minima are the
  caller's branch, never this helper's.
  """
  @spec normalize_damage_divisions(integer(), signed_divisions()) ::
          {integer(), non_neg_integer()}
  def normalize_damage_divisions(damage, divisions) when divisions > 0,
    do: {damage * divisions, divisions}

  def normalize_damage_divisions(damage, divisions) when divisions < 0 do
    count = -divisions
    {div(damage, count) * count, count}
  end

  def normalize_damage_divisions(_damage, 0), do: {0, 0}

  @doc """
  Runs one attribute step on an integer `damage`, the reference `battle_attr_fix`.

  Reads the defender's `{element, level}` (default `{:neutral, 1}`); a defender
  without an element tuple passes `damage` through. The step captures, in order,
  the attacker's matching element field (`{:element_ratio, element}`: Volcano,
  Deluge, Violent Gale) and, for fire against a webbed player, mob or Homunculus,
  the web bonus. A webbed holder loses its shortest web in this step, so every
  attribute step is an actual application: never call this to preview damage.

  Options:

    * `:attacker_modifiers` - the attacker's status modifiers when already resolved;
      otherwise they are read for `attacker`.
    * `:allow_negative` - lets a negative final ratio through (the weapon
      post-defense step); otherwise a negative ratio deals 0.
  """
  @spec apply_element_step(
          integer(),
          ElementModifiers.element(),
          map() | nil,
          map(),
          keyword()
        ) :: integer()
  def apply_element_step(damage, attack_element, attacker, defender, opts \\ []) do
    case Map.get(defender, :element, {:neutral, 1}) do
      {defense_element, defense_level} ->
        modifiers =
          Keyword.get_lazy(opts, :attacker_modifiers, fn -> attacker_modifiers(attacker) end)

        ElementModifiers.adjust_damage(damage, %{
          attack_element: attack_element,
          defense_element: defense_element,
          defense_level: defense_level,
          modifiers:
            field_modifier(modifiers, attack_element) ++ web_modifier(attack_element, defender),
          allow_negative_ratio?: Keyword.get(opts, :allow_negative, false)
        })

      _no_element ->
        damage
    end
  end

  defp field_modifier(modifiers, attack_element) do
    case Map.get(modifiers, {:element_ratio, attack_element}, 0) do
      0 -> []
      points -> [{:field, points}]
    end
  end

  defp web_modifier(:fire, %{unit_type: type, unit_id: id})
       when type in [:player, :mob, :homunculus] do
    if SpiderWeb.consume(type, id), do: [{:spider_web, 100}], else: []
  end

  defp web_modifier(_element, _defender), do: []

  @doc """
  The attack element a weapon endow imposes, `nil` without one.

  Weapon Enchant (`enchant_arms_element`) outranks the other endows, which
  share the `attack_element` key and exclude each other.
  """
  @spec endow_element(map()) :: atom() | nil
  def endow_element(modifiers),
    do: Map.get(modifiers, :enchant_arms_element) || Map.get(modifiers, :attack_element)

  @doc """
  Resolves an attacker combatant's aggregated status modifiers for the flat-
  damage element step.

  The flat BF_MISC path (`MiscDamageCalculator`) and the explicit-amount magic
  paths (`MagicAttack.execute_magic_damage/4` and fixed skill-unit hits) skip
  the full `DamageCalculator`/`MagicDamageCalculator` pipeline, so they never
  resolve the attacker's modifiers on their own. This is the seam that lets an
  `{:element_ratio, element}` bonus (the Sage element fields Volcano, Deluge and
  Violent Gale) reach those paths through `apply_element_step/5`.

  Returns `%{}` for an attacker without a resolvable unit (unowned traps,
  environmental damage), so `apply_element_step/5` simply finds no bonus.
  """
  @spec attacker_modifiers(map() | nil) :: map()
  def attacker_modifiers(%{unit_type: unit_type, unit_id: unit_id})
      when unit_type in [:player, :mob, :homunculus] and is_integer(unit_id) do
    ModifierCalculator.get_all_modifiers(unit_type, unit_id)
  end

  def attacker_modifiers(_attacker), do: %{}

  @doc """
  Applies the generic status-effect `damage_multiplier` to `damage`.

  Multiplies by `1.0 + damage_multiplier`, defaulting the multiplier to `0.0`
  when absent.
  """
  @spec apply_damage_multiplier(number(), map()) :: number()
  def apply_damage_multiplier(damage, modifiers) do
    damage * (1.0 + Map.get(modifiers, :damage_multiplier, 0.0))
  end

  @doc """
  Clamps a damage value to a minimum of 1 and truncates to an integer.
  """
  @spec clamp_min_one(number()) :: pos_integer()
  def clamp_min_one(value) do
    max(1, trunc(value))
  end

  @doc """
  Rolls an integer in the half-open range `[min, max)`.

  Mirrors rAthena's `min + rnd()%(max-min)` shape (upper bound exclusive), so
  the result is `min` when `max <= min` and otherwise lands in `[min, max - 1]`.
  """
  @spec roll(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def roll(min, max) when max > min, do: min + (:rand.uniform(max - min) - 1)
  def roll(min, _max), do: min

  @doc """
  Rolls the per-hit weapon overrefine damage extra.

  Mirrors rAthena's `damage += rnd()%overrefine + 1` (`battle.cpp:2419`): a
  uniform integer in `1..band`. A `band` of `0` is a no-op.
  """
  @spec overrefine_roll(non_neg_integer()) :: non_neg_integer()
  def overrefine_roll(0), do: 0
  def overrefine_roll(band) when band > 0, do: roll(1, band + 1)

  @doc """
  Applies the rAthena Res/MRes soft-capped reduction curve to `damage`.

  Reduces `damage` by `res/(res+400) * 0.8`, so the reduction trends toward
  but never reaches 80% as `res` grows. A `res` of `0` (or below) is a no-op.
  """
  @spec res_reduction(number(), non_neg_integer()) :: number()
  def res_reduction(damage, res) when res > 0,
    do: damage - trunc(res / (res + 400) * 0.8 * damage)

  # ponytail: no ignore_res/ignore_mres pierce term yet -- every source is an
  # unmodeled 4th-job skill/status. Add the capped (50%) pierce when one
  # lands. rAthena battle.cpp:5603 / 6063.
  def res_reduction(damage, _res), do: damage
end
