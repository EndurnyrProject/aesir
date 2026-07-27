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

  @enforce_keys [:skill_id, :owner_job_id, :max_level]
  defstruct skill_id: nil,
            owner_job_id: nil,
            max_level: nil,
            base_level: 0,
            job_level: 0,
            requires: []

  @type t() :: %__MODULE__{
          skill_id: non_neg_integer(),
          owner_job_id: non_neg_integer(),
          max_level: pos_integer(),
          base_level: non_neg_integer(),
          job_level: non_neg_integer(),
          requires: [{non_neg_integer(), pos_integer()}]
        }
end
