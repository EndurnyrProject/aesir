defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoemBragi do
  @moduledoc """
  Poem of Bragi (SC_POEMBRAGI).

  A Bard ensemble buff that reduces both variable cast time and the after-cast
  act delay. On apply it stores `:cast_time_reduction` (summed by the cast-time
  interpreter to cut variable cast) and `:delay_reduction` (read by the
  after-cast act-delay path) in instance state, so both reducers pick it up
  generically with no extra wiring.

  Values verified vs rAthena status.cpp:11105-11106: `val2 = 2*val1` (variable
  cast reduction %), `val3 = 3*val1` (after-cast delay reduction %).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poembragi,
    properties: [:buff],
    icon: :poembragi

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  # Variable-cast (val2=2*val1) and after-cast-delay (val3=3*val1) reduction
  # percent per skill level. Verified vs rAthena status.cpp:11105-11106.
  @cast_reduction_per_level 2
  @delay_reduction_per_level 3

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok,
     put_state(instance, %{
       cast_time_reduction: instance.val1 * @cast_reduction_per_level,
       delay_reduction: instance.val1 * @delay_reduction_per_level
     })}
  end
end
