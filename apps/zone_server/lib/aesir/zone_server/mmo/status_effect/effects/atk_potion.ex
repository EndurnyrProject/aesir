defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AtkPotion do
  @moduledoc """
  ATK Potion buff (SC_ATKPOTION).

  Raises flat ATK by `val1` (`db/re/status.yml`: `bBaseAtk, getstatus(SC_ATKPOTION,1)`).
  Magnitude and duration come from the consumed item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_atkpotion,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:atk],
    icon: :plusattackpower

  @impl true
  def modifiers(instance, _context), do: %{atk: instance.val1}
end
