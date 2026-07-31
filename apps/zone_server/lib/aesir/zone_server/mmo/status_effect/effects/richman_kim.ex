defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim do
  @moduledoc "Finite Mr. Kim a Rich Man experience snapshot."

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_richmankim,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:exp_rate],
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
    icon: :richmankim

  @impl true
  def modifiers(instance, _context), do: %{exp_rate: 10 + 10 * instance.val1}
end
