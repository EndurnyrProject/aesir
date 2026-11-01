defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncAgi do
  @moduledoc """
  Flat AGI item buff (SC_INCAGI), identical in both game modes.

  Adds `val1` to AGI without granting movement haste or a spell status.
  Only players can receive it. It survives death, Dispel and buff clearing;
  a weaker application leaves the held amount and duration unchanged.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incagi,
    target_types: [:player],
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:agi]

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(instance, _context), do: %{agi: instance.val1}
end
