defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.LifeInsurance do
  @moduledoc """
  Life Insurance buff (SC_LIFEINSURANCE).

  Waives the renewal death EXP penalty while active (`db/re/status.yml`:
  `bNoDeathPenalty`). Fixed magnitude — the consumed item passes `val1 = 0`, so
  the flag is hardcoded rather than val1-driven. Consumed in
  `unit/player/handlers/health_handler.ex` `handle_death/2`, which skips the
  penalty when the merged `no_death_penalty` modifier is greater than 0.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_lifeinsurance,
    properties: [:buff],
    calc_flags: [:no_death_penalty],
    icon: :cash_deathpenalty

  @modifiers %{no_death_penalty: 1}

  @impl true
  def modifiers(_instance, _context), do: @modifiers
end
