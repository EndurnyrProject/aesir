defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzHeavendrive do
  @moduledoc """
  Heaven's Drive (WZ_HEAVENDRIVE). Ground-targeted 5x5 Earth magic splash.

  A level `n` cast immediately dispatches `n` independent 125% MATK hits through
  the shared magic splash pipeline. The cast interpreter validates ground range,
  map bounds, and walkability before calling this module; no persistent skill
  unit is created.

  Renewal values come from rAthena `db/re/skill_db.yml:3730-3790`; the 125%
  MATK ratio comes from `src/map/skills/mage/heavensdrive.cpp:20-24`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 91,
    name: :wz_heavendrive,
    display_name: "Heaven's Drive",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :earth,
    splash_radius: 2,
    cast_time: [1_100, 1_300, 1_500, 1_700, 1_900],
    fixed_cast_time: List.duplicate(800, 5),
    after_cast_delay: List.duplicate(500, 5),
    cooldown: List.duplicate(1_000, 5),
    sp_cost: [28, 32, 36, 40, 44]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def cast(caster, {:ground, x, y}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 125,
      element: definition.element,
      split: false
    ]

    Enum.each(1..level, fn _hit ->
      caster
      |> Combat.execute_magic_splash({x, y}, definition.splash_radius, opts)
      |> Enum.each(&remove_root_twist/1)
    end)

    {:ok, caster}
  end

  @spec remove_root_twist({:mob | :player, integer()}) :: :ok
  defp remove_root_twist({unit_type, target_id}) do
    StatusInterpreter.remove_status(unit_type, target_id, :sc_sv_roottwist)
  end
end
