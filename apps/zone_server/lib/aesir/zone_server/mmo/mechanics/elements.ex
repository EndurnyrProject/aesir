defmodule Aesir.ZoneServer.Mmo.Mechanics.Elements do
  @moduledoc """
  Contract for mode-specific element damage modifiers.
  """

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers

  @callback get_modifier(
              ElementModifiers.element(),
              ElementModifiers.element(),
              ElementModifiers.element_level(),
              number()
            ) :: float()
end
