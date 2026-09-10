defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaAdvancedbook do
  @moduledoc """
  Advanced Book (SA_ADVANCEDBOOK). A passive for book wielders: 3 ATK per level in
  both modes.

  Renewal adds a flat attack speed bonus of (level minus 1)/2 plus 1; pre-renewal
  adds an attack speed rate of half a percent per level instead, carried as whole
  percents (level/2) because the rate channel is integer.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 274,
    name: :sa_advancedbook,
    display_name: "Advanced Book",
    max_level: 10,
    target_type: :passive

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :book}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def aspd_bonus(level, %{weapon_type: :book}) do
    if GameMode.mode() == :renewal, do: div(level - 1, 2) + 1, else: 0
  end

  def aspd_bonus(_level, _ctx), do: 0

  @impl Passive
  def aspd_rate_bonus(level, %{weapon_type: :book}) do
    if GameMode.mode() == :pre_renewal, do: div(level, 2), else: 0
  end

  def aspd_rate_bonus(_level, _ctx), do: 0
end
