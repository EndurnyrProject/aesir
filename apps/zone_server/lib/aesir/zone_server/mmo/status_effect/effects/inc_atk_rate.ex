defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncAtkRate do
  @moduledoc """
  Physical-damage rate buff (SC_INCATKRATE).

  Adds `val1` percent to physical damage (`db/re/status.yml`: `bonus bAtkRate,
  getstatus(SC_INCATKRATE,1)`). Berserk-pill style, val1-driven; rAthena defines
  no icon. Consumed as an additive percent delta in
  `combat/damage_calculator.ex`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incatkrate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:atk_rate]

  @impl true
  def modifiers(instance, _context), do: %{atk_rate: instance.val1}
end
