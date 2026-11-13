defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Increasing do
  @moduledoc """
  Increasing Accuracy (SC_INCREASING). Lasts 60 s and grants AGI +4, DEX +4
  and HIT +20; Clearance does not remove it. Same in both modes.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_increasing,
    no_dispel: true,
    no_clear_buff: false,
    properties: [:buff],
    calc_flags: [:agi, :dex, :hit],
    flags: [:no_banishing_buster, :no_clearance],
    duration: 60_000,
    icon: :gs_accuracy

  @impl true
  def modifiers(_instance, _context), do: %{agi: 4, dex: 4, hit: 20}
end
