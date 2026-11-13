defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Fleet do
  @moduledoc """
  Filir's Fleeting Move attack-speed and ATK status.

  The player quicken group uses a fixed 5 in renewal and the captured per-mille
  rate converted to percent in pre-renewal. Homunculus timing retains its
  existing per-mille channel.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_fleet,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:aspd, :atk],
    icon: :hfli_fleet

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    group =
      case GameMode.mode() do
        :renewal -> %{aspd_fixed_max: 5}
        :pre_renewal -> %{aspd_rate_max: div(instance.val2, 10)}
      end

    Map.merge(%{hom_aspd_rate: instance.val2, atk_rate: instance.val3}, group)
  end
end
