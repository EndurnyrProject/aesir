defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpMeditatio do
  @moduledoc """
  Meditatio (HP_MEDITATIO). High Priest passive that deepens spiritual focus.

  Per learned level it adds 1% max SP and multiplies the base natural SP
  regeneration amount by `(100 + 3 * level) / 100`, as its own multiplier
  applied before the status and equipment SP recovery rates.

  It also strengthens Heal by 2% per level. That bonus is read by the Heal
  formula, not exposed as a passive channel, and combines differently per mode:
  renewal adds it to Heal's single additive bonus pool (with equipment heal
  power and the target's Assumptio bonus); pre-renewal applies it as a separate
  multiplier before equipment heal power.

  The max SP and SP regeneration effects are identical in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 363,
    name: :hp_meditatio,
    display_name: "Meditatio",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def max_sp_rate_bonus(level, _ctx), do: level

  @impl Passive
  def sp_regen_rate(level, _ctx), do: 3 * level
end
