defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Benedictio do
  @moduledoc """
  Benedictio Sanctissimi Sacramenti (SC_BENEDICTIO).

  Changes the armor element to holy (level 1).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_benedictio,
    properties: [:buff],
    calc_flags: [:def_ele],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def modifiers(_instance, _context), do: %{def_ele: :holy1}
end
