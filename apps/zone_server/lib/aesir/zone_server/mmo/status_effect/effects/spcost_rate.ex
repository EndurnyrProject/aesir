defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpcostRate do
  @moduledoc """
  Skill SP-cost reduction buff (SC_SPCOST_RATE).

  rAthena stores `val1` as a positive reduction percentage and subtracts it from
  `dsprate` (`status.cpp:3787`: `sd->dsprate -= sc->getSCE(SC_SPCOST_RATE)->val1`);
  items pass +10/+15. Aesir models SP cost as an additive `sp_cost_rate` delta
  where negative = cheaper, so this module NEGATES `val1`
  (`%{sp_cost_rate: -val1}`). Consumed in `skill/interpreter.ex`. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_spcost_rate,
    properties: [:buff],
    calc_flags: [:sp_cost_rate],
    icon: :atker_blood

  @impl true
  def modifiers(instance, _context), do: %{sp_cost_rate: -instance.val1}
end
