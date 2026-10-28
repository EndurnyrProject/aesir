defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDancinglesson do
  @moduledoc """
  Dancing Lesson (DC_DANCINGLESSON). A passive granting 3 whip weapon ATK per
  level.

  Renewal adds 1 critical and 1% max SP per level; pre-renewal grants neither.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 323,
    name: :dc_dancinglesson,
    display_name: "Dancing Lesson",
    max_level: 10,
    target_type: :passive,
    damage_type: :damage

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: :whip}), do: 3 * level
  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def critical_bonus(level, _ctx) do
    case GameMode.mode() do
      :renewal -> level
      :pre_renewal -> 0
    end
  end

  @impl Passive
  def max_sp_rate_bonus(level, _ctx) do
    case GameMode.mode() do
      :renewal -> level
      :pre_renewal -> 0
    end
  end
end
