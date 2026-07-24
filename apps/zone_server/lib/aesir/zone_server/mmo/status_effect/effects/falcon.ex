defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Falcon do
  @moduledoc """
  Falcon (SC_FALCON).

  Permanent display mirror of the durable `:falcon` option bit set when a
  Hunter equips a Falcon. `Character.option` is the ownership authority; this
  status exists only so the generic `StatusDisplay` path folds the Falcon into
  the unit's `effect_state` for spawn and observer updates.

  `no_save` because the option bit is the durable source: the status is
  recreated from it on spawn and must never be persisted as its own row.
  `no_dispel` and `permanent` keep it aligned with the option bit through
  Dispel and death (permanent statuses survive death cleanup). It grants no
  combat modifiers; learned skill levels are read from progression state
  wherever Falcon damage or gating matters.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_falcon,
    no_dispel: true,
    properties: [:buff],
    permanent: true,
    no_save: true,
    option: :falcon
end
