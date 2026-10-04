defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas do
  @moduledoc "Deterministic calculations shared by renewal and pre-renewal Sniper skills."

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Formulas, as: HunterFormulas

  @doc "Player Sharpshooting ratio, base-level scaled in renewal and flat in pre-renewal."
  @spec sharpshooting_ratio(pos_integer(), pos_integer()) :: pos_integer()
  def sharpshooting_ratio(level, base_level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(300 + 300 * level, base_level)
      :pre_renewal -> 200 + 50 * level
    end
  end

  @doc "Mob Sharpshooting ratio, with a separate pre-renewal lane-target ratio."
  @spec sharpshooting_mob_ratio(pos_integer(), boolean()) :: pos_integer()
  def sharpshooting_mob_ratio(level, path_target?) do
    if path_target? and GameMode.mode() == :pre_renewal, do: 140 * level, else: 200 + 50 * level
  end

  @doc "Additional critical percentage points: 30 in renewal, 20 in pre-renewal."
  @spec sharpshooting_crit_bonus() :: pos_integer()
  def sharpshooting_crit_bonus do
    case GameMode.mode() do
      :renewal -> 30
      :pre_renewal -> 20
    end
  end

  @doc "Five Blitz Beat hits scaled by Falcon Assault's level, using the active mode's base."
  @spec falcon_assault_damage(pos_integer(), non_neg_integer(), map()) :: non_neg_integer()
  def falcon_assault_damage(level, steel_crow_level, stats) do
    div(
      HunterFormulas.blitz_beat_base_damage(level, steel_crow_level, stats) * 5 *
        (150 + 70 * level),
      100
    )
  end
end
