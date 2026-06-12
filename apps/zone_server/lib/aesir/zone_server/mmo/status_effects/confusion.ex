defmodule Aesir.ZoneServer.Mmo.StatusEffects.Confusion do
  @moduledoc """
  Confusion (SC_CONFUSION).

  Randomizes the target's movement direction.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_confusion,
    properties: [:debuff],
    flags: [:confused_movement],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
end
