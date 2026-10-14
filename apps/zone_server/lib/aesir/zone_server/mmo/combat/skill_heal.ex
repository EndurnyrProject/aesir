defmodule Aesir.ZoneServer.Mmo.Combat.SkillHeal do
  @moduledoc """
  What a healing skill restores, or deals when it strikes, from its caster to a
  target: the skill's base amount, the caster's heal bonuses, the target's
  received-heal bonuses and penalties and, in renewal, the caster's MATK part.
  Everything the target's bonuses add is decided here; the target's session
  only takes the amount.

  Base amounts. Heal and every healing skill without its own base (Healing
  Touch, Benediction of Chaos, Benedictio Sanctissimi Sacramenti): at level 11
  and above always 9999, with no other step. Otherwise pre-renewal `(base level
  + INT) / 8 * (4 + 8 * level)`, renewal `(base level + INT) / 5 * 30 * level /
  10`, raised 2% per Meditatio level of a player caster, or else 2% per Brain
  Surgery level of a Homunculus caster. Sanctuary heals 100 per level (777 from
  level 7) and Evil Land 100 per level (666 from level 7). Pre-renewal Apple of
  Idun heals `30 + 5 * level + VIT / 2`, plus 5 per Music Lessons level of a
  player performer. INT and VIT are the caster's effective stats.

  A strike (`heal?` false) halves the base, except Evil Land's.

  Bonuses. A player caster's heal power (`bHealPower`, never for Slim Pitcher
  or Apple of Idun) and the skill's own heal bonus (`bSkillHeal`); a player
  target's received heal power (`bHealPower2`) and the skill's received bonus
  (`bSkillHeal2`); the target's Increase Heal Rate and, in renewal, 2% per
  Assumptio level, neither for Evil Land or Apple of Idun. Pre-renewal applies
  the caster's bonus, then the target's received bonus, then Increase Heal Rate,
  each as its own truncating percentage. Renewal sums them all (Meditatio and
  Brain Surgery included) into one percentage of the base, then adds the MATK
  part (none for Sanctuary, Apple of Idun or Evil Land): a roll over the caster's
  base MATK bounds without item or skill MATK.

  Penalties, on a heal only: a target under No Recovery loses the whole amount
  (pre-renewal) or has it scaled to nothing (renewal). Renewal then raises a
  player caster's heal by its trait heal bonus (H.Plus) and never heals below 1.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats, as: HomunculusStats
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @sanctuary 70
  @apple_of_idun 322
  @slim_pitcher 478
  @evil_land 670
  @meditatio 363
  @music_lessons 315

  @max_heal_level 11
  @max_heal 9_999

  # Skills whose heal ignores the target's Increase Heal Rate and Assumptio.
  @no_target_rate [@evil_land, @apple_of_idun]
  # Skills without the renewal MATK part.
  @no_matk [@apple_of_idun, @sanctuary, @evil_land]
  # Skills the caster's heal power never reaches.
  @no_heal_power [@slim_pitcher, @apple_of_idun]

  @typedoc "What the recipe reads from the caster, taken from its live state by `caster/1`."
  @type caster :: %{
          player?: boolean(),
          base_level: non_neg_integer(),
          int: non_neg_integer(),
          vit: non_neg_integer(),
          learned: map(),
          brain_rate: non_neg_integer(),
          equipment: map(),
          heal_matk_min: non_neg_integer(),
          heal_matk_max: non_neg_integer(),
          hplus: integer()
        }

  @doc "Reads the recipe's caster inputs from a live caster state."
  @spec caster(struct()) :: caster()
  def caster(%PlayerState{stats: stats}) do
    %{
      player?: true,
      base_level: stats.progression.base_level,
      int: Stats.get_effective_stat(stats, :int),
      vit: Stats.get_effective_stat(stats, :vit),
      learned: stats.progression.learned_skills || %{},
      brain_rate: 0,
      equipment: stats.modifiers.equipment,
      heal_matk_min: stats.combat_stats.heal_matk_min,
      heal_matk_max: stats.combat_stats.heal_matk_max,
      hplus: Map.get(stats.combat_stats, :hplus, 0)
    }
  end

  def caster(%HomunculusState{} = homunculus) do
    %{
      player?: false,
      base_level: homunculus.level,
      int: homunculus.int,
      vit: homunculus.vit,
      learned: %{},
      brain_rate: HomunculusStats.healing_touch_bonus_rate(homunculus),
      equipment: %{},
      heal_matk_min: homunculus.combat_stats.matk_min,
      heal_matk_max: homunculus.combat_stats.matk_max,
      hplus: 0
    }
  end

  def caster(%module{} = state) do
    combatant = module.to_combatant(state)
    combat_stats = combatant.combat_stats

    %{
      player?: false,
      base_level: combatant.progression.base_level,
      int: combatant.base_stats.int,
      vit: combatant.base_stats.vit,
      learned: %{},
      brain_rate: 0,
      equipment: %{},
      heal_matk_min: Map.fetch!(combat_stats, :heal_matk_min),
      heal_matk_max: Map.fetch!(combat_stats, :heal_matk_max),
      hplus: 0
    }
  end

  @doc """
  The amount `skill_id` at `level` heals `target` (`heal?` true) or deals to it
  (`heal?` false). `target` is the recipient's `{unit_type, unit_id}`, or `nil`
  when it is not a unit, which takes no target bonus or penalty.
  """
  @spec amount(caster(), Ref.t() | nil, pos_integer(), pos_integer(), boolean()) :: integer()
  def amount(caster, target, skill_id, level, heal?) do
    case base(GameMode.mode(), caster, skill_id, level) do
      {:max, amount} -> amount
      {:base, hp, bonus} -> recipe(GameMode.mode(), caster, target, skill_id, hp, bonus, heal?)
    end
  end

  defp base(_mode, _caster, skill_id, level) when skill_id in [@sanctuary, @evil_land] do
    cap = if skill_id == @sanctuary, do: 777, else: 666
    {:base, if(level > 6, do: cap, else: level * 100), 0}
  end

  defp base(:pre_renewal, caster, @apple_of_idun, level) do
    lessons =
      if caster.player?, do: 5 * Learned.learned_level(caster.learned, @music_lessons), else: 0

    {:base, 30 + 5 * level + div(caster.vit, 2) + lessons, 0}
  end

  defp base(_mode, _caster, _skill_id, level) when level >= @max_heal_level,
    do: {:max, @max_heal}

  defp base(:pre_renewal, caster, _skill_id, level) do
    {:base, div(caster.base_level + caster.int, 8) * (4 + level * 8), caster_skill_rate(caster)}
  end

  defp base(:renewal, caster, _skill_id, level) do
    hp = div(div(caster.base_level + caster.int, 5) * 30 * level, 10)
    {:base, hp, caster_skill_rate(caster)}
  end

  # Meditatio for a player caster, else Brain Surgery for a Homunculus caster.
  defp caster_skill_rate(%{player?: true, learned: learned}),
    do: 2 * Learned.learned_level(learned, @meditatio)

  defp caster_skill_rate(%{brain_rate: rate}), do: rate

  defp recipe(:pre_renewal, caster, target, skill_id, hp, skill_rate, heal?) do
    hp
    |> percent(skill_rate)
    |> halve(heal?, skill_id)
    |> percent(caster_heal_power(caster, skill_id))
    |> percent(received_heal_power(target, skill_id))
    |> percent(inc_heal_rate(target, skill_id))
    |> no_recovery(heal?, target)
  end

  defp recipe(:renewal, caster, target, skill_id, hp, skill_rate, heal?) do
    bonus =
      skill_rate + caster_heal_power(caster, skill_id) + received_heal_power(target, skill_id) +
        inc_heal_rate(target, skill_id) + assumptio(target, skill_id)

    hp =
      hp
      |> halve(heal?, skill_id)
      |> percent(bonus)
      |> Kernel.+(matk_part(caster, skill_id))
      |> no_recovery(heal?, target)
      |> percent(if caster.player? and caster.hplus > 0, do: caster.hplus, else: 0)

    if heal?, do: max(hp, 1), else: hp
  end

  defp percent(hp, 0), do: hp
  defp percent(hp, rate), do: hp + div(hp * rate, 100)

  defp halve(hp, false, skill_id) when skill_id != @evil_land, do: div(hp, 2)
  defp halve(hp, _heal?, _skill_id), do: hp

  defp caster_heal_power(%{player?: true, equipment: equipment}, skill_id) do
    power = if skill_id in @no_heal_power, do: 0, else: Map.get(equipment, :heal_power, 0)
    power + Map.get(equipment, {:skill_heal, skill_id}, 0)
  end

  defp caster_heal_power(_caster, _skill_id), do: 0

  defp received_heal_power({:player, id}, skill_id) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, %PlayerState{stats: %{modifiers: %{equipment: equipment}}}, _pid}} ->
        Map.get(equipment, :heal_power2, 0) + Map.get(equipment, {:skill_heal2, skill_id}, 0)

      _unavailable ->
        0
    end
  end

  defp received_heal_power(_target, _skill_id), do: 0

  defp inc_heal_rate(_target, skill_id) when skill_id in @no_target_rate, do: 0
  defp inc_heal_rate(nil, _skill_id), do: 0

  defp inc_heal_rate({type, id}, _skill_id) do
    case StatusStorage.get_status(type, id, :sc_inchealrate) do
      %{val1: rate} when is_integer(rate) -> rate
      _absent -> 0
    end
  end

  defp assumptio(_target, skill_id) when skill_id in @no_target_rate, do: 0
  defp assumptio(nil, _skill_id), do: 0

  defp assumptio({type, id}, _skill_id) do
    case StatusStorage.get_status(type, id, :sc_assumptio) do
      %{val1: level} when is_integer(level) -> 2 * level
      _absent -> 0
    end
  end

  defp matk_part(_caster, skill_id) when skill_id in @no_matk, do: 0

  defp matk_part(caster, _skill_id),
    do: DamageShared.roll(caster.heal_matk_min, caster.heal_matk_max)

  # The only heal penalty Aesir implements is No Recovery's 100%: pre-renewal
  # subtracts all of it, renewal scales the heal by nothing.
  defp no_recovery(hp, true, {type, id}) do
    if StatusStorage.has_status?(type, id, :sc_norecover_state), do: 0, else: hp
  end

  defp no_recovery(hp, _heal?, _target), do: hp
end
