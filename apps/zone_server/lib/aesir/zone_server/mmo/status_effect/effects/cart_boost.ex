defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.CartBoost do
  @moduledoc """
  Cart Boost (SC_CARTBOOST). Supplies 20-point strongest movement haste.

  Survives death and Dispel but is not saved in either mode. Decrease AGI
  ends instead of granting the buff; Quagmire prevents it in both modes and
  Don't Forget Me prevents it only in pre-renewal.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_cartboost,
    no_dispel: true,
    no_clear_buff: false,
    no_save: true,
    remove_on_death: false,
    properties: [:buff],
    calc_flags: [:speed],
    end_return: [:sc_decreaseagi],
    prevented_by: [
      renewal: [:sc_quagmire],
      pre_renewal: [:sc_quagmire, :sc_dontforgetme]
    ],
    icon: :cartboost

  @impl true
  def modifiers(_instance, _context), do: %{haste_rate: 20}
end
