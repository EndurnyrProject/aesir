defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Providence do
  @moduledoc """
  Resistant Souls (SC_PROVIDENCE).

  Raises holy-element and demon-race damage resistance by 5% per skill level
  (`val1`), read by `EquipmentBonuses.damage_taken_rates/4` via the
  `:subele_holy`/`:subrace_demon` status-modifier keys.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_providence,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:subele_holy, :subrace_demon],
    icon: :providence

  @impl true
  def modifiers(instance, _context) do
    %{
      subele_holy: instance.val1 * 5,
      subrace_demon: instance.val1 * 5
    }
  end
end
