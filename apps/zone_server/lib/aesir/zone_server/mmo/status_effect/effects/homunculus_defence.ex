defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.HomunculusDefence do
  @moduledoc "Amistr's Defence status, granting owner VIT or Homunculus hard DEF."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_defence,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:vit, :def],
    no_save: true,
    remove_on_map_change: true

  @impl true
  def modifiers(instance, %{unit_type: :player}), do: %{vit: instance.val2}
  def modifiers(instance, %{unit_type: :homunculus}), do: %{def: instance.val2}
  def modifiers(_instance, _context), do: %{}
end
