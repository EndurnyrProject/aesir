defmodule Aesir.ZoneServer.Mmo.Mechanics.Sizes do
  @moduledoc """
  Contract for mode-specific weapon-size damage modifiers.
  """

  alias Aesir.ZoneServer.Mmo.Combat.SizeModifiers

  @callback get_modifier(
              SizeModifiers.weapon_type(),
              SizeModifiers.size(),
              boolean()
            ) :: integer()
end
