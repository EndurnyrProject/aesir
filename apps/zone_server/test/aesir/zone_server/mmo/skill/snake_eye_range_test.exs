defmodule Aesir.ZoneServer.Mmo.Skill.SnakeEyeRangeTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.TestMob
  alias Aesir.ZoneServer.Mmo.Combat.SkillRange
  alias Aesir.ZoneServer.Mmo.Skill.Audit
  alias Aesir.ZoneServer.Mmo.Skill.CastConditions
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  test "snake_eye_cast_range: only players gain Snake Eye cells, without a weapon gate" do
    definition = %Definition{
      id: 999_999,
      name: :range_seam,
      display_name: "Range Seam",
      max_level: 1,
      range: 9,
      snake_eye_range: true
    }

    stub(Catalog, :by_id, fn 999_999 -> {:ok, definition} end)
    player = player(%{510 => 5, 44 => 7})
    combatant = PlayerState.to_combatant(player)

    assert combatant.weapon.type == :fist
    assert SkillRange.server_range(combatant, definition.id, 1) == 14
    assert CastConditions.effective_range(definition, player, 1) == 14
    assert SkillRange.server_range(PlayerState.to_combatant(player(%{})), definition.id, 1) == 9
    assert CastConditions.effective_range(definition, player(%{}), 1) == 9
    assert SkillRange.server_range(%{combatant | unit_type: :mob}, definition.id, 1) == 9
    mob = struct(MobState, instance_id: 5000, mob_data: TestMob.definition(skill_range: 9))
    assert CastConditions.effective_range(definition, mob, 1) == 9
  end

  test "snake_eye_range_cap: the learned bonus is added after the 14-cell cap" do
    definition = %Definition{
      id: 999_999,
      name: :range_seam,
      display_name: "Range Seam",
      max_level: 1,
      range: 18,
      snake_eye_range: true
    }

    stub(Catalog, :by_id, fn 999_999 -> {:ok, definition} end)
    player = player(%{510 => 5})

    assert SkillRange.server_range(PlayerState.to_combatant(player), definition.id, 1) == 19
    assert CastConditions.effective_range(definition, player, 1) == 19

    both_flags = %{definition | vulture_range: true}
    stub(Catalog, :by_id, fn 999_999 -> {:ok, both_flags} end)
    player = player(%{44 => 7, 510 => 5})

    assert SkillRange.server_range(PlayerState.to_combatant(player), definition.id, 1) == 26
    assert CastConditions.effective_range(both_flags, player, 1) == 26
  end

  test "vulture_range_unchanged: Double Strafe ignores Snake Eye" do
    {:ok, definition} = Catalog.by_id(46)
    archer = player(%{44 => 7})
    both_learned = player(%{44 => 7, 510 => 5})
    snake_only = player(%{510 => 5})

    for caster <- [archer, both_learned] do
      assert SkillRange.server_range(PlayerState.to_combatant(caster), 46, 1) == 16
      assert CastConditions.effective_range(definition, caster, 1) == 16
    end

    assert SkillRange.server_range(PlayerState.to_combatant(snake_only), 46, 1) == 9
    assert CastConditions.effective_range(definition, snake_only, 1) == 9
  end

  test "audit_snake_eye: the source flag is compared independently of Vulture" do
    definition = %Definition{
      id: 999_999,
      name: :range_seam,
      display_name: "Range Seam",
      max_level: 1,
      range: 9,
      snake_eye_range: true
    }

    row = %{"MaxLevel" => 1, "Range" => 9, "Flags" => %{"AlterRangeSnakeEye" => true}}

    for mode <- [:renewal, :pre_renewal] do
      assert Audit.compare(definition, row, mode) == []

      assert Audit.compare(%{definition | snake_eye_range: false}, row, mode) == [
               %{field: :snake_eye_range, aesir: false, source: true}
             ]

      assert Audit.compare(definition, Map.delete(row, "Flags"), mode) == [
               %{field: :snake_eye_range, aesir: true, source: false}
             ]
    end
  end

  defp player(learned) do
    character = %Character{
      id: 1,
      name: "RangeSeam",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      base_level: 1,
      job_level: 1,
      class: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      status_point: 0,
      skill_point: 0,
      account_id: 1
    }

    state = PlayerState.new(character)
    put_in(state.stats.progression.learned_skills, learned)
  end
end
