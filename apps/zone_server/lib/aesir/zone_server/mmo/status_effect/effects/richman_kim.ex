defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim do
  @moduledoc """
  Mr. Kim a Rich Man (SC_RICHMANKIM), keyed by the effective skill level in `val1`.

  Renewal places the status on the party and raises each holder's EXP rate by
  `10 + 10 * level` percent and ends the other ensembles' statuses. Pre-renewal
  places it on enemies inside the field instead, for 60 seconds and ending no
  other status: the holder gains nothing, and killing a mob that carries the
  status raises that kill's base and job EXP by `kill_exp_bonus/1` percent
  before it is shared among attackers. A status-immune target resists it.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_richmankim,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    immunity: [:boss],
    calc_flags: [:exp_rate],
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
    remove_on_death: true,
    remove_on_map_change: false,
    icon: :richmankim

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{exp_rate: 10 + 10 * instance.val1}
      :pre_renewal -> %{}
    end
  end

  @doc "Pre-renewal percent EXP bonus for killing a mob that carries the status at `level`."
  @spec kill_exp_bonus(pos_integer()) :: pos_integer()
  def kill_exp_bonus(level) when is_integer(level) and level > 0, do: 25 + 11 * level
end
