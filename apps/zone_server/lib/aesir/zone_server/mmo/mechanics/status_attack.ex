defmodule Aesir.ZoneServer.Mmo.Mechanics.StatusAttack do
  @moduledoc """
  The status-change stages of a unit's status ATK, shared by players, monsters
  and homunculi in both modes.

  Flat status ATK (`:batk`) joins the base first; the status ATK rate
  (`:batk_rate`) then adds its share of the running value, truncated toward
  zero. The source applies every percentage status as its own truncating step
  in a fixed order, so a second percentage emitter must become its own step
  here rather than a summed rate, and a flat status the source adds after a
  percentage must also be its own step rather than joining `:batk`.
  """

  @typedoc "A unit's aggregated status modifiers."
  @type modifiers :: %{optional(atom()) => number()}

  @doc "Applies the flat status ATK and then the status ATK rate to a base status ATK."
  @spec modify(integer(), modifiers()) :: integer()
  def modify(base, modifiers) do
    flat = base + Map.get(modifiers, :batk, 0)
    flat + div(flat * Map.get(modifiers, :batk_rate, 0), 100)
  end
end
