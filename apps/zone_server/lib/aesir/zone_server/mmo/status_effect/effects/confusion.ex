defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Confusion do
  @moduledoc """
  Confusion (SC_CONFUSION).

  Randomizes the target's movement direction.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_confusion,
    no_dispel: false,
    properties: [:debuff],
    flags: [:confused_movement],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    opt2: :confusion
end
