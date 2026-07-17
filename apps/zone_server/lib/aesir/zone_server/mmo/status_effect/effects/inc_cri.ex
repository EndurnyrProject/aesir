defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.IncCri do
  @moduledoc """
  Critical-rate buff (SC_INCCRI).

  Raises the critical rate by `val1` (`db/re/status.yml`: `bonus bCritical,
  getstatus(SC_INCCRI,1)`).

  ## Unit scaling (architecture 11)

  rAthena stores `cri` in 0.1-point units and `bonus bCritical,n` adds `n*10`
  (pc.cpp:3838), with the crit roll `rnd()%1000 < cri` (battle.cpp:3152).
  Aesir does **not** mirror that unit: `combat_stats.critical` is a whole-percent
  display value (`trunc(LUK/3)`, `stats.ex:551-556`) that the `:critical`
  status modifier adds to raw (`stats.ex:525`) and that is pushed to the client
  stat window verbatim (`stats.ex:170`, matching rAthena's `SP_CRITICAL = cri/10`
  getter). The existing `SC_CRIFOOD` module also emits `%{critical: val1}` raw.
  So `val1` is used **raw**, consistent with Aesir's whole-percent critical stat.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_inccri,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [:critical],
    icon: :criticalpercent

  @impl true
  def modifiers(instance, _context), do: %{critical: instance.val1}
end
