defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim do
  @moduledoc """
  Mr. Kim a Rich Man (SC_RICHMANKIM), keyed by the effective skill level in `val1`.

  Renewal places the status on the party and raises each holder's EXP rate by
  `10 + 10 * level` percent. Pre-renewal places it on enemy mobs inside the
  field instead: the holder gains nothing, and killing a mob that carries the
  status raises that kill's base and job EXP by `kill_exp_bonus/1` percent
  before it is shared among attackers.
  """

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
