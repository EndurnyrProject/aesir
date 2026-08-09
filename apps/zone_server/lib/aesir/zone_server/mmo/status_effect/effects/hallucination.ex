defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Hallucination do
  @moduledoc """
  Hallucination (SC_HALLUCINATION).

  A debuff that scrambles the damage numbers shown over the afflicted unit on
  every nearby client. It never touches the server's authoritative damage,
  stats, or combat outcome — only the on-screen numbers are randomized, and a
  displayed value of `0` (miss, guard, perfect dodge) is left alone. Survives
  Dispel. The garbling is applied at the combat broadcast layer
  (`Aesir.ZoneServer.Mmo.Combat.Hallucination`); this module only declares the
  status metadata and icon.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_hallucination,
    no_dispel: true,
    properties: [:debuff],
    prevented_by: [:sc_inspiration],
    icon: :illusion
end
