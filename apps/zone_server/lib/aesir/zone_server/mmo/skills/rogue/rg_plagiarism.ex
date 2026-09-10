defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgPlagiarism do
  @moduledoc """
  Both modes copy the last copyable skill that hit the Rogue, capped at the
  Plagiarism level; the copyable set is the same in both modes.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 225,
    name: :rg_plagiarism,
    display_name: "Intimidate",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
