defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline2 do
  @moduledoc """
  Advanced Adrenaline Rush (SC_ADRENALINE2).

  Renewal: a flat +6 attack speed. Pre-renewal: a 30 percent attack speed rate for
  the Blacksmith's own cast (`val2`) and 20 percent otherwise. Ends the moment its
  holder wields a weapon outside the supported list: melee weapons, instruments,
  whips and books are allowed; bows, firearms, huuma shuriken and two-handed staves
  are not.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline2,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
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

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd: 6}
      :pre_renewal -> %{aspd_rate: classic_rate(instance)}
    end
  end

  # `val2` is set when the Blacksmith cast it on themselves.
  defp classic_rate(%{val2: 1}), do: 30
  defp classic_rate(_instance), do: 20

  @impl true
  def overlap(target, held, incoming),
    do: Definition.self_cast_overlap(target, held, incoming)
end
