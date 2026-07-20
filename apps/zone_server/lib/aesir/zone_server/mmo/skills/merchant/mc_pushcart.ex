defmodule Aesir.ZoneServer.Mmo.Skills.Merchant.McPushcart do
  @moduledoc """
  Pushcart (MC_PUSHCART, id 39). Learned-only Merchant passive.

  Carries no combat or stat bonus; it exists solely to be learnable in the
  Merchant tree. Its learned level parameterizes the `SC_PUSHCART` walk-speed
  modifier and gates the cart mount flow, which reads the level rather than any
  passive channel here.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 39,
    name: :mc_pushcart,
    display_name: "Pushcart",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
