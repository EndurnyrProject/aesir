defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsKatar do
  @moduledoc "Katar Mastery (AS_KATAR). Adds ATK while wielding a Katar."
  use Aesir.ZoneServer.Mmo.Skill,
    id: 134,
    name: :as_katar,
    display_name: "Katar Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :katar}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0
end
