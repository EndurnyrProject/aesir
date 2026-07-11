defmodule Aesir.ZoneServer.Mmo.JobManagement.SkillStatuses do
  @moduledoc """
  Maps a self-cast buff skill to the status effect it grants its caster, used to
  end statuses tied to skills that were just dropped from a player's tree (job
  change) or refunded (skill reset), matching rAthena's `pc_jobchange` /
  `resetskill` status cleanup.

  Only self-applied buffs the caster carries on themselves are listed; the cart
  status (`SC_PUSHCART`) is handled by the cart-removal path, not here.

  NOTE: this mapping is hand-maintained against the currently implemented skill
  modules. It should become catalog-driven once `Skill.Definition` (or the skill
  modules) declare their granted status, so new self-buff skills are covered
  automatically instead of needing an entry here.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @skill_statuses %{
    sm_endure: :sc_endure,
    sm_autoberserk: :sc_autoberserk,
    mg_energycoat: :sc_energycoat,
    tf_hiding: :sc_hiding,
    ac_concentration: :sc_concentrate,
    al_angelus: :sc_angelus,
    al_incagi: :sc_increaseagi,
    al_blessing: :sc_blessing,
    mc_loud: :sc_loud
  }

  @doc """
  The status effect ids granted by the given `skill_ids`, resolving each mapped
  skill name to its numeric id via `Skill.Catalog`. Skills with no status
  mapping (or not present in the catalog) contribute nothing.
  """
  @spec statuses_for([non_neg_integer()]) :: [atom()]
  def statuses_for(skill_ids) do
    mapping = mapping()

    Enum.flat_map(skill_ids, fn skill_id ->
      case Map.fetch(mapping, skill_id) do
        {:ok, status_id} -> [status_id]
        :error -> []
      end
    end)
  end

  @spec mapping() :: %{non_neg_integer() => atom()}
  defp mapping do
    for {name, status_id} <- @skill_statuses,
        {:ok, %{id: id}} <- [Catalog.by_name(name)],
        into: %{},
        do: {id, status_id}
  end
end
