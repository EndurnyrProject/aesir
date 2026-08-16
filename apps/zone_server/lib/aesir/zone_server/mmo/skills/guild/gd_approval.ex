defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdApproval do
  @moduledoc """
  Official Guild Approval (GD_APPROVAL). Gating passive: required before the guild can damage an Emperium. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_000,
    name: :gd_approval,
    display_name: "Official Guild Approval",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
