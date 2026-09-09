defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrTrust do
  @moduledoc """
  Faith (CR_TRUST). An always-on passive granting 200 max HP per level and 5% holy
  damage resistance per level, physical and magic alike.

  Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 248,
    name: :cr_trust,
    display_name: "Faith",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def max_hp_bonus(level, _ctx), do: 200 * level
end
