defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DefSet do
  @moduledoc """
  Timed numeric DEF replacement (SC_DEFSET).

  While active, both hard and soft physical defense use `val1`; ordinary
  defense status modifiers do not alter the replacement. A second application
  is rejected until the current one expires.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_defset,
    no_dispel: false,
    bypass_resistance: true,
    properties: [:debuff],
    calc_flags: [:def],
    prevented_by: [:sc_defset],
    target_types: [:player],
    icon: :set_num_def
end
