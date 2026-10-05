defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Confusion do
  @moduledoc """
  Confusion (SC_CONFUSION).

  Randomizes the target's movement direction. Applying it to a confused target
  cures the confusion instead.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_confusion,
    no_dispel: false,
    properties: [:debuff],
    flags: [:confused_movement],
    prevented_by: [
      renewal: [:sc_refresh, :sc_inspiration, :sc_protection],
      pre_renewal: [:sc_refresh, :sc_inspiration]
    ],
    end_return: [:sc_confusion],
    opt2: :confusion
end
