defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMacemastery do
  @moduledoc """
  Mace Mastery (PR_MACEMASTERY) grants 3 weapon ATK per level with either mace type.

  Renewal also grants 10 critical tenths per level. Classic grants no critical bonus.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 65,
    name: :pr_macemastery,
    display_name: "Mace Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in [:mace, :two_handed_mace],
    do: 3 * level

  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def critical_bonus(level, %{weapon_type: weapon}) when weapon in [:mace, :two_handed_mace] do
    case GameMode.mode() do
      :renewal -> 10 * level
      :pre_renewal -> 0
    end
  end

  def critical_bonus(_level, _ctx), do: 0
end
