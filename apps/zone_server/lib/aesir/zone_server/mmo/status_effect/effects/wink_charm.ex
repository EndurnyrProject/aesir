defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WinkCharm do
  @moduledoc """
  Wink of Charm (SC_WINKCHARM).

  Prevents a monster from targeting the Dancer who charmed it until the
  monster takes damage.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_winkcharm,
    no_dispel: false,
    properties: [:debuff],
    icon: :dc_winkcharm

  @impl true
  def absorb_damage(_target, _instance, %{damage: damage}, _context) when damage != 0,
    do: :remove

  def absorb_damage(_target, instance, %{damage: damage}, _context),
    do: {:ok, damage, instance}
end
