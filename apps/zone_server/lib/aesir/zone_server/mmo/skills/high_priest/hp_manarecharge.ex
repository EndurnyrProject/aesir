defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpManarecharge do
  @moduledoc """
  Mana Recharge (HP_MANARECHARGE). High Priest passive that lowers the SP cost
  of every skill by 4% per learned level (20% at level 5).

  The reduction joins the status and equipment SP cost rates in one additive
  percent step. Skills cast by status procs or equipment procs pay their listed
  cost and are unaffected, as with every other caster SP cost rate.

  Renewal and pre-renewal are identical.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 481,
    name: :hp_manarecharge,
    display_name: "Mana Recharge",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def sp_cost_rate(level, _ctx), do: -4 * level
end
