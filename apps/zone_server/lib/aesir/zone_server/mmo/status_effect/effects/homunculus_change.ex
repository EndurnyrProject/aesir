defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HomunculusChange do
  @moduledoc "Lif's Mental Change VIT and INT status."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_change,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:vit, :int],
    prevented_by: [:sc_change],
    no_save: true,
    remove_on_map_change: true,
    icon: :hlif_change

  @impl true
  def modifiers(instance, _context), do: %{vit: instance.val2, int: instance.val3}
end
