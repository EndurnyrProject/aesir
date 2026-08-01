defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsUnfairlytrick do
  @moduledoc """
  Unfair Trick (BS_UNFAIRLYTRICK). Reduces the zeny cost of zeny-consuming
  skills by 20%.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1012,
    name: :bs_unfairlytrick,
    display_name: "Unfair Trick",
    max_level: 1,
    target_type: :passive,
    quest_skill: true,
    quest_owner_job: :blacksmith

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def zeny_cost_reduction(_level, _ctx), do: 20
end
