defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncMatkRate do
  @moduledoc """
  Magic-damage rate buff (SC_INCMATKRATE).

  Adds `val1` percent to magic damage (`db/re/status.yml`: `bonus bMatkRate,
  getstatus(SC_INCMATKRATE,1)`). val1-driven; rAthena defines no icon. Consumed
  as an additive percent delta in `combat/magic_damage_calculator.ex`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incmatkrate,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:matk_rate]

  @impl true
  def modifiers(instance, _context), do: %{matk_rate: instance.val1}
end
