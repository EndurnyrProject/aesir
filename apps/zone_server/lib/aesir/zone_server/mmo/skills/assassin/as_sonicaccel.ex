defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicaccel do
  @moduledoc "Sonic Acceleration (AS_SONICACCEL), the Assassin Sonic Blow quest passive."

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
