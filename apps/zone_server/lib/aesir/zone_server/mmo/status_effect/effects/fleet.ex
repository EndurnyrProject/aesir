defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fleet do
  @moduledoc "Filir's Fleeting Move attack-speed and ATK status."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fleet,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:aspd, :atk],
    icon: :hfli_fleet

  @impl true
  def modifiers(instance, _context) do
    %{hom_aspd_rate: instance.val2, atk_rate: instance.val3}
  end
end
