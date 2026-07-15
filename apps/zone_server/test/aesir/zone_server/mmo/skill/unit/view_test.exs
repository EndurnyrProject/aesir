defmodule Aesir.ZoneServer.Mmo.Skill.Unit.ViewTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.SkillUnitCellState
  alias Aesir.Net.SkillUnitGroupState
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.View

  test "maps complete group state and orders cells by id" do
    group = %Group{
      group_id: 9,
      skill_id: 89,
      skill_name: :wz_stormgust,
      level: 10,
      caster_id: 42,
      caster_type: :player,
      map_name: "prontera",
      center: {100, 101},
      created_at: 1_000,
      expires_at: 5_000,
      interval: 450
    }

    cells = [
      %Cell{cell_id: 8, group_id: 9, map_name: "prontera", x: 101, y: 101, hp: 0, max_hp: 0},
      %Cell{
        cell_id: 3,
        group_id: 9,
        map_name: "prontera",
        x: 100,
        y: 101,
        hp: 60,
        max_hp: 100,
        flags: 17
      }
    ]

    assert %SkillUnitGroupState{
             group_id: 9,
             skill_id: 89,
             skill_level: 10,
             owner_type: :SKILL_UNIT_OWNER_TYPE_PLAYER,
             owner_id: 42,
             center_x: 100,
             center_y: 101,
             created_tick: 10_000,
             expires_tick: 14_000,
             cells: [
               %SkillUnitCellState{cell_id: 3, x: 100, y: 101, hp: 60, max_hp: 100, flags: 17},
               %SkillUnitCellState{cell_id: 8, x: 101, y: 101, hp: 0, max_hp: 0, flags: 0}
             ]
           } = View.group(group, cells, {1_000, 10_000})
  end
end
