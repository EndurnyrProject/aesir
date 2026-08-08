defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgPlagiarism do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 225,
    name: :rg_plagiarism,
    display_name: "Intimidate",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
