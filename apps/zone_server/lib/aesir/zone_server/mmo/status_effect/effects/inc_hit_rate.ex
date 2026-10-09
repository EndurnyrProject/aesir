defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncHitRate do
  @moduledoc """
  HIT rate modifier (SC_INCHITRATE).

  Adds `val1` percent to HIT in renewal and pre-renewal. Negative values reduce
  it; Tarot's Sun card grants a twenty-percent reduction for thirty seconds.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_inchitrate,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:hit_rate]

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(instance, _context), do: %{hit_rate: instance.val1}
end
