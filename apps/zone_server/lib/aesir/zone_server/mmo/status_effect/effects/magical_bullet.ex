defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.MagicalBullet do
  @moduledoc """
  Magical Bullet (SC_MAGICALBULLET), renewal only, `val1` the skill level.
  Lasts 30 s; saved, dispellable and ended by death (the reference row has no
  flags).

  It has no modifiers: while held, every physical hit of the holder adds
  `max(rolled MATK - target MDEF, 0)` to its weapon ATK after the card fix,
  rolled per hit (`DamageInputs.magical_bullet_atk/2`, read by
  `DamageCalculator`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_magicalbullet,
    no_dispel: false,
    no_clear_buff: false,
    properties: [:buff],
    duration: 30_000,
    icon: :gs_magical_bullet
end
