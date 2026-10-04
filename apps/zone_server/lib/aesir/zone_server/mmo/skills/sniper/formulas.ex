defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas do
  @moduledoc "Deterministic calculations shared by renewal and pre-renewal Sniper skills."

  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Formulas, as: HunterFormulas

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
