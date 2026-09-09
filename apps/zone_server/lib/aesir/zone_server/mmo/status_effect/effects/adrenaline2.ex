defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline2 do
  @moduledoc """
  Advanced Adrenaline Rush (SC_ADRENALINE2).

  Renewal: a flat +6 attack speed. Pre-renewal: a 30 percent attack speed rate when
  the holder is the caster and 20 percent for party recipients. Ends the moment its
  holder wields a weapon outside the supported list: melee weapons, instruments,
  whips and books are allowed; bows, firearms, huuma shuriken and two-handed staves
  are not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline2,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate],
    require_weapon: [
      :fist,
      :dagger,
      :one_handed_sword,
      :two_handed_sword,
      :one_handed_spear,
      :two_handed_spear,
      :one_handed_axe,
      :two_handed_axe,
      :mace,
      :two_handed_mace,
      :staff,
      :knuckle,
      :musical,
      :whip,
      :book,
      :katar
    ],
    icon: :adrenaline2

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(_instance, context) do
    case GameMode.mode() do
      :renewal -> %{aspd: 6}
      :pre_renewal -> %{aspd_rate: classic_rate(context)}
    end
  end

  defp classic_rate(%{caster_id: caster_id, target_id: caster_id}), do: 30
  defp classic_rate(_context), do: 20
end
