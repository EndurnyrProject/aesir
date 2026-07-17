defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SignumCrucis do
  @moduledoc """
  Signum Crucis (SC_SIGNUMCRUCIS).

  Reduces the target's defense by a percentage (val2). Does not stack.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_signumcrucis,
    no_dispel: false,
    properties: [:debuff],
    calc_flags: [:def],
    conflicts_with: [:sc_signumcrucis],
    prevented_by: [:sc_refresh, :sc_inspiration],
    permanent: true,
    icon: :crucis

  @impl true
  def modifiers(instance, _context), do: %{def_rate: -instance.val2}
end
