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
  def denied?(skill_id), do: reason_for(skill_id) != nil

  @doc "The one-line reason `skill_id` is denylisted, or `nil` if it is not."
  @spec reason_for(integer()) :: String.t() | nil
  # Enum.find_value instead of Map.get: the seeded-empty @denied map makes
  # Map.get a type-checker "always nil" warning until the sweep populates it.
  def reason_for(skill_id) do
    Enum.find_value(@denied, fn {id, reason} -> if id == skill_id, do: reason end)
  end
end
