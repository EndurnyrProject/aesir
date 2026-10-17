defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAxemastery do
  @moduledoc """
  Axe Mastery (AM_AXEMASTERY). Grants 3 flat weapon ATK per level while
  wielding a one-handed or two-handed axe, and in renewal also a one-handed
  sword.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 226,
    name: :am_axemastery,
    display_name: "Axe Mastery",
    max_level: 10,
    target_type: :passive,
    damage_type: :damage

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in [:one_handed_axe, :two_handed_axe],
    do: 3 * level

  def atk_bonus(level, %{weapon_type: :one_handed_sword}) do
    if GameMode.mode() == :renewal, do: 3 * level, else: 0
  end

  def atk_bonus(_level, _ctx), do: 0
end
