defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Silence do
  @moduledoc """
  Silence (SC_SILENCE).

  Prevents skill casting and ends a Battle Chant in progress.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_silence,
    immunity: [:boss],
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff, :prevents_skills],
    flags: [:no_magic],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    end_on_start: [:sc_gospel],
    opt2: :silence
end
