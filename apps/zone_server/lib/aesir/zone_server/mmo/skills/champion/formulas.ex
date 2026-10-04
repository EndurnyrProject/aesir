defmodule Aesir.ZoneServer.Mmo.Skills.Champion.Formulas do
  @moduledoc """
  Pure arithmetic for the Champion skills. Functions whose value differs between
  renewal and pre-renewal branch on the booted mode.

  Renewal ratios scale with the caster's base level above 99 (`ratio * BaseLv / 100`):
  Raging Palm Strike `200 + 100*lv + STR`, Glacier Fist `500 + 150*lv`, and Chain
  Crush Combo `200*lv`. Pre-renewal ratios are flat: Palm Strike `200 + 100*lv`,
  Glacier Fist `40 + 100*lv`, and Chain Crush `400 + 100*lv`.

  The Glacier Fist immobilise chance, its duration, Chain Crush's displayed hit
  count, and Palm Strike's impact delay are the same in both modes.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier

  @doc "Raging Palm Strike skill ratio."
  @spec palm_ratio(pos_integer(), non_neg_integer(), pos_integer()) :: pos_integer()
  def palm_ratio(level, str, base_level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(200 + 100 * level + str, base_level)
      :pre_renewal -> 200 + 100 * level
    end
  end

  @doc "Glacier Fist skill ratio."
  @spec glacier_ratio(pos_integer(), pos_integer()) :: pos_integer()
  def glacier_ratio(level, base_level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(500 + 150 * level, base_level)
      :pre_renewal -> 40 + 100 * level
    end
  end

  @doc "Chain Crush Combo skill ratio."
  @spec chain_crush_ratio(pos_integer(), pos_integer()) :: pos_integer()
  def chain_crush_ratio(level, base_level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(200 * level, base_level)
      :pre_renewal -> 400 + 100 * level
    end
  end

  @doc "Hits Chain Crush Combo displays: one per two levels, rounded up."
  @spec chain_crush_display_hits(pos_integer()) :: pos_integer()
  def chain_crush_display_hits(level), do: div(level + 1, 2)

  @doc "Percent chance that Glacier Fist immobilises the target."
  @spec glacier_ankle_chance(pos_integer()) :: pos_integer()
  def glacier_ankle_chance(level), do: 10 + 10 * level

  @doc """
  Glacier Fist immobilise duration in ms: `2000*lv`, a fifth of that against a
  boss, shortened by the target's AGI, never below `15 * (caster BaseLv + 100)`.
  """
  @spec glacier_ankle_duration(pos_integer(), non_neg_integer(), boolean(), pos_integer()) ::
          pos_integer()
  def glacier_ankle_duration(level, target_agi, boss?, caster_base_level) do
    base = 2_000 * level
    base = if boss?, do: div(base, 5), else: base
    max(base - div(base * target_agi, 200), 15 * (caster_base_level + 100))
  end

  @doc "Raging Palm Strike impact delay in ms after the cast."
  @spec palm_impact_delay(non_neg_integer()) :: pos_integer()
  def palm_impact_delay(attack_motion), do: 1_000 + attack_motion
end
