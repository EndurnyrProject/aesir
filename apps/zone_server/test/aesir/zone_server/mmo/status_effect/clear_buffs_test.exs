defmodule Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffsTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Interpreter.init()
    unit_id = :rand.uniform(100_000)

    player =
      PlayerStateFixture.build(%{
        character_id: unit_id,
        account_id: unit_id,
        stats: %{combat_stats: %CombatStats{}, modifiers: %{equipment: %{}}}
      })

    UnitRegistry.register_unit(:player, unit_id, PlayerState, player, self())
    {:ok, unit_id: unit_id}
  end

  test "clearing buffs ends every status without the Debuff flag, ailments included", %{
    unit_id: id
  } do
    apply_all(id, [:sc_blessing, :sc_poison, :sc_decreaseagi])

    assert :ok = ClearBuffs.clear({:player, id}, [:buffs])

    assert held(id) == [:sc_decreaseagi]
  end

  test "clearing debuffs ends only Debuff-flagged statuses", %{unit_id: id} do
    apply_all(id, [:sc_blessing, :sc_poison, :sc_decreaseagi])

    assert :ok = ClearBuffs.clear({:player, id}, [:debuffs, :refresh])

    assert held(id) == [:sc_blessing, :sc_poison]
  end

  test "a NoClearbuff status survives every family", %{unit_id: id} do
    apply_all(id, [:sc_cp_weapon])

    ClearBuffs.clear({:player, id}, [:buffs, :debuffs, :chem_protect, :refresh, :hermode])

    assert held(id) == [:sc_cp_weapon]
  end

  test "Hermode's clearing ends its flagged statuses and disarms a kept Berserk", %{unit_id: id} do
    apply_all(id, [:sc_blessing, :sc_poison])

    :ok =
      StatusStorage.apply_status(:player, id, :sc_berserk,
        state: %{penalty_armed: true},
        duration: 300_000
      )

    ClearBuffs.clear({:player, id}, [:hermode])

    assert held(id) == [:sc_berserk, :sc_poison]
    refute StatusStorage.get_status(:player, id, :sc_berserk).state.penalty_armed
  end

  describe "the classic Storm Gust counter" do
    test "resets for a unit that holds a status", %{unit_id: id} do
      apply_all(id, [:sc_poison])
      StatusStorage.increment_storm_gust_counter(:player, id)

      ClearBuffs.clear({:player, id}, [:debuffs])

      assert StatusStorage.storm_gust_counter(:player, id) == 0
    end

    test "stays for a unit without any status", %{unit_id: id} do
      StatusStorage.increment_storm_gust_counter(:player, id)

      ClearBuffs.clear({:player, id}, [:buffs])

      assert StatusStorage.storm_gust_counter(:player, id) == 1
    end

    test "stays for a unit holding only a status the reference has no entry for", %{
      unit_id: id
    } do
      apply_all(id, [:sc_falcon])
      StatusStorage.increment_storm_gust_counter(:player, id)

      ClearBuffs.clear({:player, id}, [:buffs])

      assert StatusStorage.storm_gust_counter(:player, id) == 1
    end
  end

  test "no clearing ever ends a status the reference has no entry for" do
    for module <- Effects.all(), module.metadata().engine_only do
      assert module.metadata().no_clear_buff, "#{inspect(module)} is engine-only but clearable"
    end
  end

  defp apply_all(id, status_ids) do
    Enum.each(status_ids, fn status_id ->
      :ok = StatusStorage.apply_status(:player, id, status_id, val1: 1, duration: 60_000)
    end)
  end

  defp held(id) do
    :player
    |> StatusStorage.get_unit_statuses(id)
    |> Enum.map(& &1.type)
    |> Enum.sort()
  end
end
