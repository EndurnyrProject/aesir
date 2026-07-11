defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.JexpBoost do
  @moduledoc """
  Job experience boost (SC_JEXPBOOST, Job Battle Manual).

  Adds `val1` percent to job experience gained only (`db/re/status.yml`;
  `pc.cpp:8393-8417`). Modelled as an additive `job_exp_rate` percent delta
  consumed in `unit/player/handlers/experience_handler.ex`, where it stacks onto
  any active `exp_rate`. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_jexpboost,
    properties: [:buff],
    calc_flags: [:job_exp_rate],
    icon: :cash_plusonlyjobexp

  @impl true
  def modifiers(instance, _context), do: %{job_exp_rate: instance.val1}
end
