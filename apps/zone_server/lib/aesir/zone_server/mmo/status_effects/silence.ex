defmodule Aesir.ZoneServer.Mmo.StatusEffects.Silence do
  @moduledoc """
  Silence (SC_SILENCE).

  Prevents skill casting.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_silence,
    properties: [:debuff, :prevents_skills],
    flags: [:no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection]
end
