defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponresearch do
  @moduledoc """
  Weaponry Research (BS_WEAPONRESEARCH). A passive granting 2 ATK per level with
  any weapon, a 2% per level hit-rate multiplier, and 1% per level to forging.

  Pre-renewal also adds a flat 2 HIT per level; renewal does not.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 107,
    name: :bs_weaponresearch,
    display_name: "Weaponry Research",
    max_level: 10,
    target_type: :passive

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, _ctx), do: 2 * level

  @impl Passive
  def hit_rate_bonus_pct(level, _ctx), do: 2 * level

  @impl Passive
  def hit_bonus(level, _ctx) do
    case GameMode.mode() do
      :renewal -> 0
      :pre_renewal -> 2 * level
    end
  end
end
