defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicallesson do
  @moduledoc """
  Musical Lesson (BA_MUSICALLESSON). A passive granting 3 instrument weapon ATK per
  level and the performance-linked attack speed contribution.

  Renewal adds 1% max SP per level and a flat attack speed of 1 per level while
  any status is active; pre-renewal grants neither.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 315,
    name: :ba_musicallesson,
    display_name: "Musical Lesson",
    max_level: 10,
    target_type: :passive

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :musical}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def max_sp_rate_bonus(level, _ctx) do
    case GameMode.mode() do
      :renewal -> level
      :pre_renewal -> 0
    end
  end

  @impl Passive
  def aspd_bonus(level, %{statuses_active?: true}) do
    case GameMode.mode() do
      :renewal -> level
      :pre_renewal -> 0
    end
  end

  def aspd_bonus(_level, _ctx), do: 0
end
