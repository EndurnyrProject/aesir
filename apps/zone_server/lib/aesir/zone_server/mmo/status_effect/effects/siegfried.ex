defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Siegfried do
  @moduledoc "Finite Acoustic Rhythm elemental and ailment resistance snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_siegfried,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [
      :subele_water,
      :subele_earth,
      :subele_fire,
      :subele_wind,
      :ailment_resist_rate
    ],
    end_on_start: [
      :sc_richmankim,
      :sc_eternalchaos,
      :sc_drumbattle,
      :sc_nibelungen,
      :sc_rokisweil,
      :sc_intoabyss,
      :sc_siegfried
    ],
    duration: 180_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :siegfried

  @impl true
  def modifiers(instance, _context) do
    %{
      subele_water: instance.val1,
      subele_earth: instance.val1,
      subele_fire: instance.val1,
      subele_wind: instance.val1,
      ailment_resist_rate: instance.val2
    }
  end
end
