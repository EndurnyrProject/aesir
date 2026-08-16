defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdExtension do
  @moduledoc """
  Guild Extension (GD_EXTENSION). Raises guild member capacity by 6 per level (16 base, 76 at level 10). Enforced by the guild state's capacity check.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_004,
    name: :gd_extension,
    display_name: "Guild Extension",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
