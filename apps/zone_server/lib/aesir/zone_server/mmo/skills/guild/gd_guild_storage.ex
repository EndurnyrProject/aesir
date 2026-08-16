defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdGuildStorage do
  @moduledoc """
  Guild Storage Expansion (GD_GUILD_STORAGE). Unlocks and expands guild storage (200-600 slots by level). Inert until guild storage lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_016,
    name: :gd_guild_storage,
    display_name: "Guild Storage Expansion",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
