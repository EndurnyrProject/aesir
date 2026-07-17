defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Suffragium do
  @moduledoc """
  Suffragium (SC_SUFFRAGIUM).

  Reduces variable cast time by `5 + 5*val1`% (10/15/20% at lv1/2/3), verified vs
  rAthena status.cpp:11789 (RENEWAL branch). The pre-RE `15*val1` is dead under
  renewal. The buff persists for its duration and is NOT consumed on cast
  (rAthena ends `SC_SUFFRAGIUM` on cast only `#ifndef RENEWAL`, skill.cpp:10325).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_suffragium,
    no_dispel: false,
    properties: [:buff],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :suffragium

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, put_state(instance, :cast_time_reduction, 5 + instance.val1 * 5)}
  end
end
