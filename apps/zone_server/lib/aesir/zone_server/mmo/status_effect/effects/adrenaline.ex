defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Adrenaline do
  @moduledoc """
  Adrenaline Rush (SC_ADRENALINE).

  Renewal: a flat +7 attack speed at every level plus 5 plus 3 per level HIT.
  Pre-renewal: a 30 percent attack speed rate when the holder is the caster and 20
  percent for party recipients, with no HIT. Ends the moment its holder wields
  anything other than a one- or two-handed axe or a mace.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_adrenaline,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:aspd, :aspd_rate, :hit],
    require_weapon: [:one_handed_axe, :two_handed_axe, :mace],
    icon: :adrenaline

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, context) do
    case GameMode.mode() do
      :renewal -> %{aspd: 7, hit: 5 + 3 * instance.val1}
      :pre_renewal -> %{aspd_rate: classic_rate(context)}
    end
  end

  defp classic_rate(%{caster_id: caster_id, target_id: caster_id}), do: 30
  defp classic_rate(_context), do: 20
end
