defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GdLeadership do
  @moduledoc """
  Great Leadership guild aura (sc_gd_leadership).

  Flat +str equal to the guild's aura skill level, granted to guildmates
  within 2 cells of the guild master by the ticking aura source
  (`:sc_guild_aura_source`). Short-lived and continuously refreshed while in
  radius; expiry alone removes it once the member leaves.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_gd_leadership,
    properties: [:buff],
    no_dispel: true,
    no_save: true,
    calc_flags: [:str]

  @impl true
  def modifiers(instance, _context), do: %{str: instance.val1}
end
