defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SkfCast do
  @moduledoc """
  Eden-group cast-speed food (SC_SKF_CAST).

  Adds `val1` percent to the additive variable-cast channel (`db/re/status.yml`:
  `bVariableCastrate, getstatus(SC_SKF_CAST,1)`); items pass a negative `val1`
  (-5) so the cast gets faster. Consumed in `skill/interpreter.ex` /
  `skill/cast_time.ex` as a `varcast_rate` delta. val1-driven.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_skf_cast,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:varcast_rate],
    icon: :skf_cast

  @impl true
  def modifiers(instance, _context), do: %{varcast_rate: instance.val1}
end
