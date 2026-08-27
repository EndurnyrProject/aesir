defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.NoRecoverState do
  @moduledoc """
  Timed recovery lock (SC_NORECOVER_STATE).

  Natural and equipment regeneration, skill healing, item/script healing, and
  SP restoration are blocked while the status is active. Forced gains,
  resurrection, and on-kill resource grants remain separate mechanics.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_norecover_state,
    no_dispel: false,
    bypass_resistance: true,
    properties: [:debuff],
    calc_flags: [:regen],
    target_types: [:player],
    icon: :handicapstate_norecover
end
