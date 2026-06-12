defmodule Aesir.ZoneServer.Mmo.StatusEffects.SlowPoison do
  @moduledoc """
  Slow Poison (SC_SLOWPOISON).

  Suppresses poison damage and improves HP regeneration while active.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_slowpoison,
    properties: [:buff],
    calc_flags: [:regen],
    prevented_by: [:sc_refresh, :sc_inspiration]

  @impl true
  def modifiers(_instance, _context), do: %{hp_regen: 100}
end
