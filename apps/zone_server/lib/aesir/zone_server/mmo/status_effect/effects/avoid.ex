defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Avoid do
  @moduledoc "Lif's Avoid grants max-folded movement haste in renewal and pre-renewal."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_avoid,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:movement_speed],
    no_save: true,
    remove_on_map_change: true,
    icon: :hlif_avoid

  @impl true
  def modifiers(instance, _context), do: %{haste_rate: instance.val2}
end
