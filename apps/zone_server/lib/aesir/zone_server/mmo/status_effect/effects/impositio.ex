defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Impositio do
  @moduledoc """
  Impositio Manus (SC_IMPOSITIO).

  Raises weapon attack by `val2` (5 per skill level); renewal raises magic attack
  by the same amount, pre-renewal does not. Reapplying refreshes the effect.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_impositio,
    no_dispel: false,
    properties: [:buff],
    calc_flags: [:watk, :matk],
    end_on_start: [:sc_impositio],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :impositio

  alias Aesir.Commons.GameMode

  @impl true
  def modifiers(instance, _context) do
    case GameMode.mode() do
      :renewal -> %{watk: instance.val2, matk: instance.val2}
      :pre_renewal -> %{watk: instance.val2}
    end
  end
end
