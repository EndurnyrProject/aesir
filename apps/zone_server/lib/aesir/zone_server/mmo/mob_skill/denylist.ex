defmodule Aesir.ZoneServer.Mmo.MobSkill.Denylist do
  @moduledoc """
  Explicit denylist of rAthena skill ids that resolve in the real skill
  catalog (`Skill.Catalog.by_id/1` with an active module) but are known-broken
  when the caster is a mob rather than a player.

  Seeded empty: nothing has been swept yet, so nothing is confirmed broken.
  The mob-skill sweep test (mob-skill-convergence epic) is what populates this
  list as it exercises every catalog-resolvable mob-skill row against a real
  mob caster; entries land here instead of a `try/rescue` in the Executor.
  """

  @denied %{}

  @doc "Whether `skill_id` is denylisted for mob casting."
  @spec denied?(integer()) :: boolean()
  def denied?(skill_id), do: Map.has_key?(@denied, skill_id)
end
