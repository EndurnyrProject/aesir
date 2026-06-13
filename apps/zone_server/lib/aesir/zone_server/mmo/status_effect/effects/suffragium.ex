defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Suffragium do
  @moduledoc """
  Suffragium (SC_SUFFRAGIUM).

  Reduces cast time of the next spell by 15% per skill level (val1).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_suffragium,
    properties: [:buff],
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :cast_time_reduction, instance.val1 * 15)}
  end
end
