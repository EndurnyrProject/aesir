defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcUglydance do
  @moduledoc """
  Hip Shaker (DC_UGLYDANCE). A dance draining SP from every enemy within 4 cells
  of the performer on versus maps, needing a whip.

  Renewal: drains 10 plus 2 per level SP, a 1 s cast plus 0.3 s fixed, a 0.3 s
  delay, and a 5 s cooldown. Pre-renewal: drains 5 plus 5 per level plus level
  times Dancing Lesson SP with an instant cast and no cooldown. The source ticks
  the drain every 3 s for 30 s from a ground unit; this module applies one drain at
  the cast in both modes until the ground-song subsystem lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 325,
    name: :dc_uglydance,
    display_name: "Hip Shaker",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 4,
    sp_cost: [23, 26, 29, 32, 35],
    cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(300, 5), pre_renewal: []],
    cooldown: [renewal: List.duplicate(5_000, 5), pre_renewal: []],
    require_weapon: [:whip]

  use Aesir.ZoneServer.Mmo.Skill.Performance

  @lesson_id 323

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource

  @impl Active
  def validate(%{map_name: map_name}, _target, _level, _definition),
    do: validate_versus_map(map_name, &Targeting.versus_map?/1)

  defp validate_versus_map(map_name, versus_map?) do
    if versus_map?.(map_name), do: :ok, else: {:error, :versus_map_only}
  end

  @impl Active
  def cast(%PlayerState{} = caster, :self, level, definition),
    do: cast_self(caster, caster.character_id, level, definition)

  def cast(%MobState{} = caster, {:unit, id}, level, definition) when id == caster.instance_id,
    do: cast_self(caster, caster.instance_id, level, definition)

  defp cast_self(%{map_name: map_name, x: x, y: y} = caster, caster_id, level, definition) do
    amount = drain_amount(caster, level)

    Combat.splash_targets(map_name, {x, y}, definition.splash_radius, caster_id)
    |> Enum.each(fn {unit_type, target_id} ->
      Resource.drain_sp(unit_type, target_id, amount)
    end)

    {:ok, remember(caster, level)}
  end

  defp drain_amount(caster, level) do
    case GameMode.mode() do
      :renewal -> 2 * level + 10
      :pre_renewal -> 5 + 5 * level + level * Caster.lesson_level(caster, @lesson_id)
    end
  end

  defp remember(%PlayerState{} = caster, level), do: Snapshot.remember(caster, 325, level)
  defp remember(caster, _level), do: caster
end
