defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmBioethics do
  @moduledoc "Bioethics, the grant-only Homunculus prerequisite."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 238,
    name: :am_bioethics,
    display_name: "Bioethics",
    max_level: 1,
    target_type: :passive,
    quest_skill: true,
    quest_owner_job: :alchemist

  @behaviour Aesir.ZoneServer.Mmo.Skill.Passive
end
