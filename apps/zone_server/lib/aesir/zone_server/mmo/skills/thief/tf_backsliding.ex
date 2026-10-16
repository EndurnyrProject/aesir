defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfBacksliding do
  @moduledoc """
  Back Slide (TF_BACKSLIDING). Blows the caster 5 cells backward, no damage.

  self-targeted, SP 7. Synthesizes the knockback "from" cell as one
  step in front of the caster (its facing direction), so
  `Combat.knockback/5` slides it 5 cells opposite the direction it faces,
  wall-clamped by the existing `blow_path` logic.

  Renewal and pre-renewal agree: the caster slides five cells straight back from the facing direction, ignoring knockback immunity; only the client animation differs between modes.

  Before sliding, a caster that does not already show endure becomes
  unstoppable by damage for 200 ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 150,
    name: :tf_backsliding,
    requires: [:player_state],
    display_name: "Back Slide",
    max_level: 1,
    target_type: :self,
    knockback: 5,
    sp_cost: [7],
    quest_skill: true,
    quest_owner_job: :thief

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Endure
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @endure_ms 200

  @impl Active
  def cast(%{character_id: caster_id, x: x, y: y, dir: dir} = caster, :self, _level, definition) do
    unless Endure.endure?(:player, caster_id, caster, true),
      do: Endure.put_tick(:player, caster_id, @endure_ms)

    {dx, dy} = Geometry.facing_delta(dir)
    Combat.knockback(:player, caster_id, x + dx, y + dy, definition.knockback)
    {:ok, caster}
  end
end
