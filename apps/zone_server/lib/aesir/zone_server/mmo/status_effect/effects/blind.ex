defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Blind do
  @moduledoc """
  Blind (SC_BLIND).

  Reduces HIT and FLEE by 25% in both game modes, after ordinary accuracy
  bonuses and rates. Each reduction truncates its own contribution.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_blind,
    immunity: [:boss],
    no_dispel: false,
    no_clear_buff: false,
    properties: [:debuff],
    calc_flags: [:hit, :flee],
    prevented_by: [:sc_refresh, :sc_inspiration, :sc_protection],
    opt2: :blind

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(_instance, _context), do: %{blind_accuracy_rate: 25}
end
