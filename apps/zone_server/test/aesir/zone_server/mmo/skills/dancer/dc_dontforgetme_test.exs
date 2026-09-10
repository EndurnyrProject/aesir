defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDontforgetmeTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcDontforgetme
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  Mimic.copy(Snapshot)

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Catalog.reload()
    :ok
  end

  @tag game_mode: :renewal
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

  @tag game_mode: :renewal
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

  @tag game_mode: :pre_renewal
  test "classic carries the source's instant cast and SP" do
    definition = DcDontforgetme.definition()
    assert definition.sp_cost == Enum.to_list(28..55//3)
    assert definition.duration == List.duplicate(180_000, 10)
    assert definition.cast_time == []
    assert definition.cooldown == []
  end

  @tag game_mode: :pre_renewal
  test "classic snapshots stat-scaled Slow Grace percents to enemies" do
    caster = %PlayerState{character_id: 1}

    for level <- [1, 10] do
      expect(Snapshot, :snapshot, fn ^caster,
                                     _definition,
                                     ^level,
                                     :sc_dontforgetme,
                                     params,
                                     opts ->
        assert params[:val1] == level
        assert params[:val2] == 5 + 3 * level
        assert params[:val3] == 5 + 3 * level
        assert opts == [scope: :enemy]
        {:ok, caster}
      end)

      assert {:ok, ^caster} =
               DcDontforgetme.cast(caster, :self, level, DcDontforgetme.definition())
    end
  end

  @tag game_mode: :pre_renewal
  test "classic snapshots scale with DEX, AGI, and Dancing Lesson" do
    caster = %PlayerState{
      character_id: 1,
      stats: %Stats{
        base_stats: %{str: 1, agi: 50, vit: 1, int: 1, dex: 30, luk: 1},
        progression: %PlayerProgression{learned_skills: %{323 => 4}}
      }
    }

    expect(Snapshot, :snapshot, fn ^caster, _definition, 2, :sc_dontforgetme, params, _opts ->
      assert params[:val2] == 5 + 6 + 3 + 4
      assert params[:val3] == 5 + 6 + 5 + 4
      {:ok, caster}
    end)

    assert {:ok, ^caster} =
             DcDontforgetme.cast(caster, :self, 2, DcDontforgetme.definition())
  end
end
