defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncFlee2 do
  @moduledoc """
  Perfect-dodge buff (SC_INCFLEE2).

  Raises perfect dodge (flee2) by `val1` (`db/re/status.yml`: `bonus bFlee2,
  getstatus(SC_INCFLEE2,1)`).

  ## Unit scaling (architecture 11)

  Unlike `SC_INCCRI`, Aesir's perfect-dodge stat **does** live in rAthena's
  0.1-point (tenths-of-percent) unit: `combat_stats.perfect_dodge` is `trunc(LUK/5)`
  (`combat_calculations.ex`) and is consumed as `rnd(1000) < perfect_dodge`
  (`hit_calculations.ex:138-146`), the same 0-1000 scale as rAthena's
  `rnd()%1000 < flee2`. rAthena's `SC_INCFLEE2` adds `val1*10` to `flee2`
  (`bonus bFlee2` -> `flee2 += val*10`, pc.cpp:3832). To grant `val1` percentage
  points of perfect dodge, `val1` is therefore scaled by **10** into Aesir's
  tenths unit. (`SC_INCCRI` stays raw because its stat is whole-percent; the two
  differ because Aesir's crit and perfect-dodge stats use different units.)
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_incflee2,
    properties: [:buff],
    calc_flags: [:perfect_dodge],
    icon: :plusavoidvalue

  @impl true
  def modifiers(instance, _context), do: %{perfect_dodge: instance.val1 * 10}
end
