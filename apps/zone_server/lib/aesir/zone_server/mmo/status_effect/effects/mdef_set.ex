defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MdefSet do
  @moduledoc """
  Timed numeric MDEF replacement (SC_MDEFSET).

  While active, both hard and soft magic defense use `val1`; ordinary magic
  defense status modifiers do not alter the replacement. A second application
  is rejected until the current one expires. The `:mdef_set` modifier carries the
  replacement to the status window.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_mdefset,
    no_dispel: false,
    no_clear_buff: false,
    bypass_resistance: true,
    properties: [:debuff],
    calc_flags: [:mdef],
    prevented_by: [:sc_mdefset],
    target_types: [:player],
    icon: :set_num_mdef

  @impl true
  def modifiers(%{val1: value}, _context) when is_integer(value), do: %{mdef_set: value}
  def modifiers(_instance, _context), do: %{}
end
