defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Regeneration do
  @moduledoc """
  Regeneration (SC_REGENERATION). Guild area buff boosting natural recovery
  rates by level (`val1`): HP +200/+200/+300 percent and SP +100/+200/+300
  percent, mirroring the reference val2/val3 rate additions.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_regeneration,
    properties: [:buff],
    no_dispel: true,
    no_save: true,
    calc_flags: [:regen]

  @impl true
  def modifiers(instance, _context) do
    level = max(instance.val1, 1)
    hp_multiplier = if level == 1, do: 2, else: level
    %{hp_regen: hp_multiplier * 100, sp_regen: level * 100}
  end
end
