defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Acaraje do
  @moduledoc """
  Akaraje increases attack speed by `val1` percent and HIT by `val2`.
  Identical in both modes; survives death, Dispel and buff clearing.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_acaraje,
    target_types: [:player],
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:aspd_rate, :hit],
    icon: :acaraje

  @impl true
  def modifiers(instance, _context), do: %{aspd_rate: instance.val1, hit: instance.val2}
end
