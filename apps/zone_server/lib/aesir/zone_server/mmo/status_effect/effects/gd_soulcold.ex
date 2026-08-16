defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GdSoulcold do
  @moduledoc """
  Cold Heart guild aura (sc_gd_soulcold).

  Flat +agi equal to the guild's aura skill level, granted to guildmates
  within 2 cells of the guild master by the ticking aura source
  (`:sc_guild_aura_source`). Short-lived and continuously refreshed while in
  radius; expiry alone removes it once the member leaves.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gd_soulcold,
    properties: [:buff],
    no_dispel: true,
    no_save: true,
    calc_flags: [:agi]

  @impl true
  def modifiers(instance, _context), do: %{agi: instance.val1}
end
