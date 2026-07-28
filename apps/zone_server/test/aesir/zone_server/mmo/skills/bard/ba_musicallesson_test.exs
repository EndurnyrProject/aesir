defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BaMusicallessonTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  @player_id 31_500
  @lesson_id 315
  @instrument_id 93_150
  @bow_id 1701
  @right_hand 2
  @both_hands 34

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    instrument = %ItemDefinition{
      id: @instrument_id,
      aegis_name: "task12_instrument",
      name: "Task 12 Instrument",
      type: :weapon,
      subtype: :musical,
      weapon_level: 1
    }

    stub(ItemManagement, :get_item_by_id, fn
      @instrument_id -> {:ok, instrument}
      id -> Mimic.call_original(ItemManagement, :get_item_by_id, [id])
    end)

    :ok = Catalog.reload()
  end

  test "each level grants three weapon ATK only with an instrument" do
    instrument_base = calculate(%{}, equipped(@instrument_id, @right_hand))
    instrument_lesson = calculate(%{@lesson_id => 5}, equipped(@instrument_id, @right_hand))
    bow_base = calculate(%{}, equipped(@bow_id, @both_hands))
    bow_lesson = calculate(%{@lesson_id => 5}, equipped(@bow_id, @both_hands))

    assert instrument_lesson.combat_stats.atk == instrument_base.combat_stats.atk + 15
    assert bow_lesson.combat_stats.atk == bow_base.combat_stats.atk
  end

  test "each level grants one percent MaxSP with every weapon" do
    instrument_base = calculate(%{}, equipped(@instrument_id, @right_hand))
    instrument_lesson = calculate(%{@lesson_id => 5}, equipped(@instrument_id, @right_hand))
    bow_base = calculate(%{}, equipped(@bow_id, @both_hands))
    bow_lesson = calculate(%{@lesson_id => 5}, equipped(@bow_id, @both_hands))

    assert instrument_lesson.derived_stats.max_sp ==
             trunc(instrument_base.derived_stats.max_sp * 1.05)

    assert bow_lesson.derived_stats.max_sp == trunc(bow_base.derived_stats.max_sp * 1.05)
  end

  test "status presence is counted once during a stat calculation" do
    expect(StatusStorage, :count_unit_statuses, fn :player, @player_id ->
      Mimic.call_original(StatusStorage, :count_unit_statuses, [:player, @player_id])
    end)

    calculate(%{@lesson_id => 10}, equipped(@instrument_id, @right_hand))
  end

  test "ASPD applies for a modifier-less status and disappears after the last status" do
    learned = %{@lesson_id => 10}
    weapon = equipped(@instrument_id, @right_hand)
    without_status = calculate(learned, weapon)

    :ok = StatusStorage.apply_status(:player, @player_id, :sc_task12_modifierless)
    with_status = calculate(learned, weapon)

    assert with_status.modifiers.status_effects == %{}
    assert with_status.modifiers.statuses_active?
    assert with_status.derived_stats.aspd > without_status.derived_stats.aspd

    :ok = StatusStorage.remove_status(:player, @player_id, :sc_task12_modifierless)
    after_removal = calculate(learned, weapon)

    refute after_removal.modifiers.statuses_active?
    assert after_removal.derived_stats.aspd == without_status.derived_stats.aspd
  end

  defp calculate(learned_skills, weapon) do
    %Stats{
      base_stats: %{str: 10, agi: 100, vit: 25, int: 30, dex: 20, luk: 10},
      progression: %{
        base_level: 50,
        job_level: 25,
        base_exp: 0,
        job_exp: 0,
        job_id: 19,
        learned_skills: learned_skills
      },
      current_state: %{hp: 1, sp: 1},
      equipment: %Equipment{}
    }
    |> Stats.calculate_stats(@player_id, [weapon])
  end

  defp equipped(nameid, equip) do
    %InventoryItem{nameid: nameid, amount: 1, equip: equip, identify: 1}
  end
end
