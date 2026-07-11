defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExpBoost do
  @moduledoc """
  Base + job experience boost (SC_EXPBOOST, Battle Manual).

  Adds `val1` percent to base experience gained; rAthena carries the base bonus
  into job experience as well (`pc.cpp:8393-8417`). Modelled as an additive
  `exp_rate` percent delta consumed in
  `unit/player/handlers/experience_handler.ex`. val1-driven (Battle Manual passes
  50).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_expboost,
    properties: [:buff],
    calc_flags: [:exp_rate],
    icon: :cash_plusexp

  @impl true
  def modifiers(instance, _context), do: %{exp_rate: instance.val1}
end
