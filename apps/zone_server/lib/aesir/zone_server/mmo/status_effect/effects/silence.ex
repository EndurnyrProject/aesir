defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Silence do
  @moduledoc """
  Silence (SC_SILENCE).

  Prevents skill casting.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_silence,
    properties: [:debuff, :prevents_skills],
    flags: [:no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    opt2: :silence
end
