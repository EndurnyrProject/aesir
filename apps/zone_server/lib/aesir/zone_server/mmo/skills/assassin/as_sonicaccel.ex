defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicaccel do
  @moduledoc """
  Sonic Acceleration (AS_SONICACCEL). The Assassin quest passive that sharpens Sonic
  Blow.

  Renewal: 90% more HIT and 90% more damage on Sonic Blow. Pre-renewal: 50% more HIT
  and a tenth more damage.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1003,
    name: :as_sonicaccel,
    display_name: "Sonic Acceleration",
    max_level: 1,
    target_type: :passive,
    quest_skill: true,
    quest_owner_job: :assassin

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
