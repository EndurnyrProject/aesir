defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.TrickDead do
  @moduledoc """
  Play Dead (SC_TRICKDEAD).

  The caster feigns death: cannot move, attack or use skills, and monsters
  ignore them. Applied by NV_TRICKDEAD as a persistent toggle (no duration) -
  re-casting NV_TRICKDEAD removes it. Provoke also cancels it (see Provoke's
  `end_on_start`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_trickdead,
    properties: [:prevents_movement, :prevents_skills, :prevents_attack, :untargetable],
    flags: [:no_move, :no_attack, :no_skill],
    permanent: true,
    icon: :trickdead,
    # NV_TRICKDEAD (143) is the only skill usable while feigning death: recasting
    # it toggles SC_TRICKDEAD off so the player stands back up.
    allow_skills: [143]
end
