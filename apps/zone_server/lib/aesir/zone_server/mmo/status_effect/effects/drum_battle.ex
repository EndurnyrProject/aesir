defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DrumBattle do
  @moduledoc """
  Drum of the Battlefield (SC_DRUMBATTLE), keyed by the skill level in `val1`.

  Renewal: ATK `15 + 5 * level` and DEF `15 * level`; the status ends the other
  ensembles' statuses. Pre-renewal: the ensemble field grants weapon ATK
  `(level + 1) * 25` and DEF `(level + 1) * 2`, ends no other status and lasts
  60 seconds.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_drumbattle,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:atk, :watk, :def],
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
    icon: :drumbattlefield

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(%{val1: level}, _context) do
    case GameMode.mode() do
      :renewal -> %{atk: 15 + 5 * level, def: 15 * level}
      :pre_renewal -> %{watk: (level + 1) * 25, def: (level + 1) * 2}
    end
  end
end
