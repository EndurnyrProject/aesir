defmodule Aesir.ZoneServer.Mmo.SkillTree.Entry do
  @moduledoc """
  A single resolved skill-tree entry for a job.

  Tree data is authored as aegis-named YAML and resolved into these structs by
  `Aesir.ZoneServer.Mmo.SkillTree`: skill names become numeric ids and the
  job-specific cap, level minimums and prerequisites are carried along.

  `owner_job_id` is the job that originally owns the skill (e.g. `MG_FROSTDIVER`
  stays owned by Mage even when inherited into the Wizard tree), resolved from the
  entry's originating job during inheritance flattening.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :skill_id, non_neg_integer()
    field :owner_job_id, non_neg_integer()
    field :max_level, pos_integer()
    field :base_level, non_neg_integer(), default: 0
    field :job_level, non_neg_integer(), default: 0
    field :requires, [{non_neg_integer(), pos_integer()}], default: []
  end
end
