defmodule Aesir.ZoneServer.Mmo.Combat.EquipBreak do
  @moduledoc """
  Pure resolver deciding which equipment breaks on a confirmed weapon hit,
  faithful to rAthena Renewal.

  This module has no side effects and makes no process calls: it takes the
  combatants' stats plus config and returns a list of break decisions. The
  caller (the attacker `PlayerSession`, wired in a later task) dispatches each
  decision to the owning session.

  ## Parameter contract

      resolve(attacker, target, opts) :: [decision]

  - `attacker` is the attacker's `Stats.t()`. Its `modifiers.equipment` supplies
    the `:break_weapon_rate` / `:break_armor_rate` bonuses, and its `equipment`
    supplies the wielded weapon type for weapon-type break immunity.
  - `target` is a `{target_type, target_stats}` tuple. `:target` decisions are
    emitted only when `target_type` is `:player` (mobs never break in Renewal);
    for any other type the second element is ignored and no `:target` decision
    is produced. When it is `:player`, `target_stats` is the victim's `Stats.t()`
    and supplies its own `:unbreakable*` break-prevention bonuses.
  - `opts` accepts `:rng`, a `(pos_integer() -> pos_integer())` function used for
    the roll. It defaults to `&:rand.uniform/1` (returns `1..N`).

  ## Decisions

  - `{:self, :weapon}` — the attacker's own weapon breaks (natural break).
  - `{:target, :weapon}` — the target's weapon breaks.
  - `{:target, :armor}` — the target's armor breaks.

  The victim of a `:self` break is the attacker; the victim of a `:target` break
  is the target. Break-prevention is read from the respective victim's stats.

  ## Rates and the roll

  Rates are in rAthena `1/10000` units (`100` = `1.00%`). Mirroring the existing
  combat RNG convention (`HitCalculations.hit_successful?/1`, which rolls
  `:rand.uniform(100) <= hit_rate`), a slot breaks when `rng.(10_000) <= rate`.
  A rate of `0` never breaks; a rate of `10_000` always breaks.

  ## Break prevention (applied to each slot's victim)

  - A per-slot 100% unbreakable modifier (`:unbreakable_weapon` for the weapon
    slot, `:unbreakable_armor` for the armor slot) masks that slot out entirely:
    the effective rate is forced to `0` and no roll happens.
  - The percentage `:unbreakable` modifier reduces the effective rate:
    `rate = rate - div(rate * unbreakable, 100)` (rAthena `rate -= rate * unbreakable / 100`).

  ## Weapon-type immunity

  rAthena never breaks a weapon wielded fist/axe/mace/staff/book (fists, 1H/2H
  axe, mace, 2H-mace, staff, 2H-staff, book, huuma). The immunity is checked on
  the entity whose gear is breaking: the attacker's own weapon type gates the
  `:self` weapon break, while the target's own weapon type gates the `:target`
  weapon break (independent of the attacker's weapon). Armor break is unaffected.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Unit.Player.Stats

  @type decision :: {:self, :weapon} | {:target, :weapon} | {:target, :armor}
  @type target :: {:player, Stats.t()} | {atom(), term()}

  @weapon_break_immune_types ~w(
    fist one_handed_axe two_handed_axe mace two_handed_mace staff two_handed_staff book huuma
  )a

  @default_rng &:rand.uniform/1

  @doc """
  Resolves the break decisions for a confirmed weapon hit. See the module doc
  for the full parameter contract and semantics.
  """
  @spec resolve(Stats.t(), target(), keyword()) :: [decision()]
  def resolve(%Stats{} = attacker, target, opts \\ []) do
    rng = Keyword.get(opts, :rng, @default_rng)

    [
      self_weapon(attacker, rng),
      target_weapon(attacker, target, rng),
      target_armor(attacker, target, rng)
    ]
    |> Enum.reject(&is_nil/1)
  end

  @spec self_weapon(Stats.t(), (pos_integer() -> pos_integer())) ::
          {:self, :weapon} | nil
  defp self_weapon(attacker, rng) do
    rate = apply_prevention(Config.natural_break_rate(), attacker, :weapon)

    if weapon_breakable?(attacker) and broke?(rate, rng), do: {:self, :weapon}
  end

  @spec target_weapon(Stats.t(), target(), (pos_integer() -> pos_integer())) ::
          {:target, :weapon} | nil
  defp target_weapon(attacker, {:player, %Stats{} = victim}, rng) do
    rate =
      Stats.get_equipment_modifier(attacker, :break_weapon_rate)
      |> apply_prevention(victim, :weapon)

    if weapon_breakable?(victim) and broke?(rate, rng), do: {:target, :weapon}
  end

  defp target_weapon(_attacker, _target, _rng), do: nil

  @spec target_armor(Stats.t(), target(), (pos_integer() -> pos_integer())) ::
          {:target, :armor} | nil
  defp target_armor(attacker, {:player, %Stats{} = victim}, rng) do
    rate =
      Stats.get_equipment_modifier(attacker, :break_armor_rate)
      |> apply_prevention(victim, :armor)

    if broke?(rate, rng), do: {:target, :armor}
  end

  defp target_armor(_attacker, _target, _rng), do: nil

  @spec apply_prevention(integer(), Stats.t(), :weapon | :armor) :: integer()
  defp apply_prevention(rate, %Stats{} = victim, slot) do
    if slot_masked?(victim, slot) do
      0
    else
      unbreakable = Stats.get_equipment_modifier(victim, :unbreakable)
      max(0, rate - div(rate * unbreakable, 100))
    end
  end

  @spec slot_masked?(Stats.t(), :weapon | :armor) :: boolean()
  defp slot_masked?(victim, :weapon),
    do: Stats.get_equipment_modifier(victim, :unbreakable_weapon) > 0

  defp slot_masked?(victim, :armor),
    do: Stats.get_equipment_modifier(victim, :unbreakable_armor) > 0

  @spec weapon_breakable?(Stats.t()) :: boolean()
  defp weapon_breakable?(%Stats{equipment: equipment}) do
    Stats.weapon_type(equipment) not in @weapon_break_immune_types
  end

  @spec broke?(integer(), (pos_integer() -> pos_integer())) :: boolean()
  defp broke?(rate, _rng) when rate <= 0, do: false
  defp broke?(rate, rng), do: rng.(10_000) <= rate
end
