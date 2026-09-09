defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHiltbinding do
  @moduledoc """
  Hilt Binding (BS_HILTBINDING). A passive granting 1 STR and 4 ATK and extending
  the owner's Adrenaline Rush, Weapon Perfection, and Power-Thrust casts by 10%.

  Renewal and pre-renewal agree.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 105,
    name: :bs_hiltbinding,
    display_name: "Hilt Binding",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  @spec str_bonus(pos_integer(), Passive.ctx()) :: 1
  def str_bonus(_level, _ctx), do: 1

  @impl Passive
  @spec atk_bonus(pos_integer(), Passive.ctx()) :: 4
  def atk_bonus(_level, _ctx), do: 4
end
