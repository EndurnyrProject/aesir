defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.FullSwingK do
  @moduledoc """
  Full-swing buff (SC_FULL_SWING_K).

  Raises flat ATK by `val1` (`db/re/status.yml`: `bBaseAtk,
  getstatus(SC_FULL_SWING_K,1)`). Magnitude and duration come from the consumed
  item's `sc_start`.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_full_swing_k,
    properties: [:buff],
    calc_flags: [:atk],
    icon: :full_swing_k

  @impl true
  def modifiers(instance, _context), do: %{atk: instance.val1}
end
