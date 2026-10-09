defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WindWalk do
  @moduledoc """
  Wind Walker grants ceil(level/2) FLEE and twice level percent movement haste
  in renewal and pre-renewal. Haste keeps only the strongest active haste buff.
  Quagmire prevents this status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_windwalk,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:flee, :speed],
    prevented_by: [:sc_quagmire],
    no_save: true,
    icon: :windwalk

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  @spec modifiers(StatusEntry.t(), map()) :: map()
  def modifiers(%{val1: level}, _context), do: %{flee: div(level + 1, 2), haste_rate: 2 * level}
end
