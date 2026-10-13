defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline do
  @moduledoc """
  Adrenaline Rush (SC_ADRENALINE).

  Renewal: a flat +7 attack speed at every level plus 5 plus 3 per level HIT.
  Pre-renewal: a 30 percent attack speed rate for the Blacksmith's own cast (`val2`)
  and 20 percent otherwise, with no HIT. Ends the moment its holder wields
  anything other than a one- or two-handed axe or a mace.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :hit],
    require_weapon: [:one_handed_axe, :two_handed_axe, :mace],
    icon: :adrenaline

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{aspd: 7, hit: 5 + 3 * instance.val1}
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
