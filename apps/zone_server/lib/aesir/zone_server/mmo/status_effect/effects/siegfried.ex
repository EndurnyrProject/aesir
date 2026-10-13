defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Siegfried do
  @moduledoc """
  Acoustic Rhythm (SC_SIEGFRIED) elemental and ailment resistance.

  `val1` is the elemental resistance and `val2` the ailment resistance that the
  status defense adds to an inflicted status's `sc_def` share. Renewal resists
  Water, Earth, Fire and Wind and ends the other ensembles' statuses.
  Pre-renewal resists every element but Neutral, ends no other status and lasts
  60 seconds.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_siegfried,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [
      :subele_water,
      :subele_earth,
      :subele_fire,
      :subele_wind,
      :subele_poison,
      :subele_holy,
      :subele_shadow,
      :subele_ghost,
      :subele_undead
    ],
    end_on_start: [
      renewal: [
        :sc_richmankim,
        :sc_eternalchaos,
        :sc_drumbattle,
        :sc_nibelungen,
        :sc_rokisweil,
        :sc_intoabyss,
        :sc_siegfried
      ],
      pre_renewal: []
    ],
    duration: [renewal: 180_000, pre_renewal: 60_000],
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :siegfried

  alias Aesir.Commons.GameMode

  @renewal_keys [:subele_water, :subele_earth, :subele_fire, :subele_wind]
  @classic_keys @renewal_keys ++
                  [:subele_poison, :subele_holy, :subele_shadow, :subele_ghost, :subele_undead]

  @impl true
  def modifiers(%{val1: resist}, _context) do
    keys = if GameMode.mode() == :renewal, do: @renewal_keys, else: @classic_keys
    Map.new(keys, &{&1, resist})
  end
end
