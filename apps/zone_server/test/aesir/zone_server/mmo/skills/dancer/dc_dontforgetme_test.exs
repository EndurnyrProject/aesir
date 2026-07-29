defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDontforgetmeTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcDontforgetme
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  Mimic.copy(Snapshot)

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Catalog.reload()
    :ok
  end

  test "definition matches the pinned Slow Grace table" do
    assert {:ok, DcDontforgetme} = Catalog.active_module_for(:dc_dontforgetme)
    assert {:ok, definition} = Catalog.by_id(328)

    assert definition.name == :dc_dontforgetme
    assert definition.display_name == "Slow Grace"
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.splash_radius == 4
    assert definition.require_weapon == [:musical, :whip]
    assert definition.duration == List.duplicate(60_000, 10)
    assert definition.sp_cost == Enum.to_list(38..65//3)
    assert definition.cast_time == List.duplicate(1_000, 10)
    assert definition.fixed_cast_time == List.duplicate(300, 10)
    assert definition.after_cast_delay == List.duplicate(300, 10)
    assert definition.cooldown == List.duplicate(20_000, 10)
  end

  test "completion snapshots raw Slow Grace values to enemies" do
    caster = %PlayerState{character_id: 1}

    for level <- [1, 10] do
      expect(Snapshot, :snapshot, fn ^caster,
                                     definition,
                                     ^level,
                                     :sc_dontforgetme,
                                     params,
                                     opts ->
        assert definition.id == 328
        assert params[:val1] == level
        assert params[:val2] == 1 + 30 * level
        assert params[:val3] == 5 + 2 * level
        assert opts == [scope: :enemy]
        {:ok, caster}
      end)

      assert {:ok, ^caster} =
               DcDontforgetme.cast(caster, :self, level, DcDontforgetme.definition())
    end
  end
end
