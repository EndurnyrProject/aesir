defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HomunculusSpeed do
  @moduledoc "Filir's Speed flee status."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_speed,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:flee],
    icon: :hfli_speed

  @impl true
  def modifiers(instance, _context), do: %{flee: instance.val2}
end
