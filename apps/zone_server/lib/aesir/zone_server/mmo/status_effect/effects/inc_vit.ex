defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncVit do
  @moduledoc """
  Flat VIT item buff (SC_INCVIT), identical in both game modes.

  Adds `val1` to VIT, contributing to maximum HP and the other derived stats.
  Only players can receive it. It survives death, Dispel and buff clearing;
  a weaker application leaves the held amount and duration unchanged.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incvit,
    target_types: [:player],
    remove_on_death: false,
    no_dispel: true,
    no_clear_buff: true,
    properties: [:buff],
    calc_flags: [:vit]

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), Definition.context()) :: map()
  def modifiers(instance, _context), do: %{vit: instance.val1}
end
