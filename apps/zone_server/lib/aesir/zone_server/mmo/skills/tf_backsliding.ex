defmodule Aesir.ZoneServer.Mmo.Skills.TfBacksliding do
  @moduledoc """
  Back Slide (TF_BACKSLIDING). Blows the caster 5 cells backward, no damage.

  rAthena: self-targeted, SP 7. Synthesizes the knockback "from" cell as one
  step in front of the caster (its facing direction), so
  `Combat.knockback/5` slides it 5 cells opposite the direction it faces,
  wall-clamped by the existing `blow_path` logic.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 150,
    name: :tf_backsliding,
    display_name: "Back Slide",
    max_level: 1,
    target_type: :self,
    sp_cost: [7]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @knockback_distance 5

  # dir -> {dx, dy} unit vector the caster is facing, inverse of
  # `Geometry.calculate_direction/4`.
  @facing_delta %{
    0 => {0, -1},
    1 => {-1, -1},
    2 => {-1, 0},
    3 => {-1, 1},
    4 => {0, 1},
    5 => {1, 1},
    6 => {1, 0},
    7 => {1, -1}
  }

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id, x: x, y: y, dir: dir} = caster, :self, _level, _definition) do
    {dx, dy} = Map.fetch!(@facing_delta, dir)
    Combat.knockback(:player, caster_id, x + dx, y + dy, @knockback_distance)
    {:ok, caster}
  end
end
