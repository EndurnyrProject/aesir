defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EternalChaos do
  @moduledoc """
  Eternal Chaos (SC_ETERNALCHAOS). Renewal zeroes both the holder's DEF and its
  soft DEF and ends the other ensembles' statuses. Pre-renewal zeroes only the
  soft DEF and ends no other status.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_eternalchaos,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:debuff],
    calc_flags: [:def, :def2],
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
    duration: 60_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :eternalchaos

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(_instance, _context) do
    case GameMode.mode() do
      :renewal -> %{def_rate: -100, def2_rate: -100}
      :pre_renewal -> %{def2_rate: -100}
    end
  end
end
