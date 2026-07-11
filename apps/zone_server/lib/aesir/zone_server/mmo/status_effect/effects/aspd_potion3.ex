defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AspdPotion3 do
  @moduledoc """
  Attack-speed potion, infinity tier (SC_ASPDPOTION3).

  Grants flat ASPD points by `val1` for the duration (renewal
  `status.cpp:8285-8286`).

  Deviation from rAthena: rAthena keeps all four ASPD potions active and honours
  only the highest tier's value. Aesir's modifier merge sums shared keys, so the
  four potions list each other in `end_on_start` (replace-on-drink) to prevent
  stacking — the cheapest behaviour that avoids the merge-sum inflating ASPD.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_aspdpotion3,
    properties: [:buff],
    calc_flags: [:aspd],
    icon: :atthaste_infinity,
    end_on_start: [:sc_aspdpotion0, :sc_aspdpotion1, :sc_aspdpotion2]

  @impl true
  def modifiers(instance, _context), do: %{aspd: instance.val1}
end
