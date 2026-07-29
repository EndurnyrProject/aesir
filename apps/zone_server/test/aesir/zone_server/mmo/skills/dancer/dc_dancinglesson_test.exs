defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcDancinglessonTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.JobManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  @player_id 32_300
  @lesson_id 323
  @whip_id 93_230
  @musical_id 93_231
  @right_hand 2

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(JobManagement)

    whip = weapon(@whip_id, :whip)
    musical = weapon(@musical_id, :musical)

    stub(ItemManagement, :get_item_by_id, fn
      @whip_id -> {:ok, whip}
      @musical_id -> {:ok, musical}
      id -> Mimic.call_original(ItemManagement, :get_item_by_id, [id])
    end)

    stub(JobManagement, :get_base_aspd, fn
      :dancer, :musical ->
        {:ok, 45}

      job_name, weapon_type ->
        Mimic.call_original(JobManagement, :get_base_aspd, [job_name, weapon_type])
    end)

    :ok = Catalog.reload()
  end

  test "grants weapon ATK only with a whip" do
    whip_base = calculate(%{}, equipped(@whip_id))
    whip_lesson = calculate(%{@lesson_id => 5}, equipped(@whip_id))
    musical_base = calculate(%{}, equipped(@musical_id))
    musical_lesson = calculate(%{@lesson_id => 5}, equipped(@musical_id))

    assert whip_lesson.combat_stats.atk == whip_base.combat_stats.atk + 15
    assert musical_lesson.combat_stats.atk == musical_base.combat_stats.atk
  end

  test "grants critical and SP regeneration with every weapon" do
    whip_base = calculate(%{}, equipped(@whip_id))
    whip_lesson = calculate(%{@lesson_id => 10}, equipped(@whip_id))
    musical_base = calculate(%{}, equipped(@musical_id))
    musical_lesson = calculate(%{@lesson_id => 10}, equipped(@musical_id))

    assert whip_lesson.combat_stats.critical == whip_base.combat_stats.critical + 1
    assert musical_lesson.combat_stats.critical == musical_base.combat_stats.critical + 1
    assert Passives.critical_bonus(whip_lesson) == 10
    assert Passives.critical_bonus(musical_lesson) == 10
    assert Passives.regen(whip_lesson).skill_sp_regen == 10
    assert Passives.regen(musical_lesson).skill_sp_regen == 10
    assert sp_regen(whip_lesson) == sp_regen(whip_base) + 10
    assert sp_regen(musical_lesson) == sp_regen(musical_base) + 10
  end

  test "does not contribute ASPD with an active status" do
    weapon = equipped(@whip_id)

    without_status = calculate(%{}, weapon)
    with_lesson_without_status = calculate(%{@lesson_id => 10}, weapon)

    :ok = StatusStorage.apply_status(:player, @player_id, :sc_task8_modifierless)

    with_status = calculate(%{}, weapon)
    with_lesson_with_status = calculate(%{@lesson_id => 10}, weapon)

    assert with_lesson_without_status.derived_stats.aspd == without_status.derived_stats.aspd
    assert with_lesson_with_status.derived_stats.aspd == with_status.derived_stats.aspd
  end

  defp calculate(learned_skills, weapon) do
    %Stats{
      base_stats: %{str: 10, agi: 100, vit: 25, int: 30, dex: 20, luk: 10},
      progression: %{
        base_level: 50,
        job_level: 25,
        base_exp: 0,
        job_exp: 0,
        job_id: 20,
        learned_skills: learned_skills
      },
      current_state: %{hp: 1, sp: 1},
      equipment: %Equipment{}
    }
    |> Stats.calculate_stats(@player_id, [weapon])
  end

  defp sp_regen(stats) do
    {_hp, sp, _accumulators} =
      NaturalHeal.compute(
        stats,
        :idle,
        :idle,
        %{},
        Passives.regen(stats),
        %{sitting_hp_regen: 0, sitting_sp_regen: 0},
        %{elapsed_ms: 10_000, hp_acc: 0, sp_acc: 0, skill_hp_acc: 0, skill_sp_acc: 0}
      )

    sp
  end

  defp weapon(id, subtype) do
    %ItemDefinition{
      id: id,
      aegis_name: "task8_#{subtype}",
      name: "Task 8 #{subtype}",
      type: :weapon,
      subtype: subtype,
      weapon_level: 1
    }
  end

  defp equipped(nameid) do
    %InventoryItem{nameid: nameid, amount: 1, equip: @right_hand, identify: 1}
  end
end
