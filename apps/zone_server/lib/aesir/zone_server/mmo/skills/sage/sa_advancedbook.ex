defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaAdvancedbook do
  @moduledoc """
  Advanced Book (SA_ADVANCEDBOOK). Grants flat mastery ATK and flat ASPD while
  wielding a book.

  rAthena renewal: `+3` ATK per skill level (`battle.cpp:2390`) and
  `+((lv-1)/2)+1` ASPD (`status.cpp:2388`), both gated on `W_BOOK`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 274,
    name: :sa_advancedbook,
    display_name: "Advanced Book",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :book}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def aspd_bonus(level, %{weapon_type: :book}), do: div(level - 1, 2) + 1
  def aspd_bonus(_level, _ctx), do: 0
end
