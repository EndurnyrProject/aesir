defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWebTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.ClearBuffs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Manager)
    Mimic.copy(UnitRegistry)
    # Ending the hold builds the holder's status context.
    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)
    register_holder(:alive)
    :ok
  end

  defp register_holder(life) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1_872,
      attack_motion: 672,
      client_attack_motion: 672,
      damage_motion: 480,
      class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([]),
      modes: []
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 150, y: 150}
    }

    mob = MobState.new(9_701, mob_data, spawn_ref, "prontera", 150, 150)
    mob = if life == :dead, do: %{mob | hp: 0, is_dead: true}, else: mob
    :ok = UnitRegistry.register_unit(:mob, 9_701, MobState, mob, self())
  end

  defp web(gid, expires_at) do
    :ok =
      Storage.insert(%Group{
        group_id: gid,
        skill_id: 405,
        skill_name: :pf_spiderweb,
        level: 1,
        caster_id: 1,
        caster_type: :player,
        map_name: "prontera",
        center: {gid, 100},
        cells: [{gid, 100}],
        next_tick_at: nil,
        expires_at: expires_at,
        interval: 1_000,
        state: %{}
      })
  end

  defp record_destroys do
    test_pid = self()
    stub(Manager, :destroy_async, fn gid -> send(test_pid, {:destroyed, gid}) end)
  end

  test "halves the holder's FLEE" do
    assert SpiderWeb.modifiers(%{state: %{slots: [51, nil, nil]}}, %{}) == %{flee_rate: -50}
  end

  defp mode_value(renewal, pre_renewal),
    do: %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]

  defp hold(slots) do
    :ok =
      StatusStorage.apply_status(:mob, 9_701, :sc_spiderweb,
        val1: Enum.count(slots, & &1),
        duration: 60_000,
        state: %{slots: slots}
      )
  end

  defp slots, do: StatusStorage.get_status(:mob, 9_701, :sc_spiderweb).state.slots

  @defender %{unit_type: :mob, unit_id: 9_701, element: {:earth, 1}}

  test "a fire attribute step against a webbed unit gains 100 ratio points" do
    assert DamageShared.apply_element_step(100, :fire, nil, @defender) == 150

    hold([51, nil, nil])

    assert DamageShared.apply_element_step(100, :fire, nil, @defender) == mode_value(250, 300)
  end

  test "a fire step burns the web closest to running out and keeps the hold" do
    web(51, 9_000)
    web(52, 5_000)
    hold([51, 52, nil])
    expect(Manager, :destroy_async, fn 52 -> :ok end)

    assert SpiderWeb.consume(:mob, 9_701)
    assert slots() == [51, nil, nil]
  end

  test "a fire step on the last web ends the hold" do
    web(51, 9_000)
    hold([51, nil, nil])
    stub(Manager, :destroy_async, fn 51 -> :ok end)

    assert SpiderWeb.consume(:mob, 9_701)
    refute StatusStorage.has_status?(:mob, 9_701, :sc_spiderweb)
  end

  test "other elements neither gain the bonus nor burn a web" do
    hold([51, nil, nil])

    assert DamageShared.apply_element_step(100, :water, nil, @defender) == 100
    assert slots() == [51, nil, nil]
  end

  test "a step that loses its claim to a concurrent burn reads the hold again" do
    web(51, 9_000)
    web(52, 5_000)
    web(53, 7_000)
    hold([51, 52, 53])
    record_destroys()

    # A concurrent step burns web 52 between this step's read and its claim.
    expect(StatusStorage, :replace_status_if_current, fn type, id, status, _read, _replacement ->
      StatusStorage.update_status(type, id, status, &put_in(&1.state.slots, [51, nil, 53]))
      false
    end)

    assert SpiderWeb.consume(:mob, 9_701)
    assert_received {:destroyed, 53}
    refute_received {:destroyed, 52}
    assert slots() == [51, nil, nil]
  end

  test "an unwebbed unit has nothing to consume" do
    refute SpiderWeb.consume(:mob, 9_701)
  end

  test "an early end frees slots whose web is gone and burns the earliest slot on a tie" do
    web(51, 5_000)
    web(53, 5_000)
    hold([52, 53, 51])
    record_destroys()

    Interpreter.remove_status(:mob, 9_701, :sc_spiderweb)

    assert_received {:destroyed, 53}
    refute_received {:destroyed, _other}
    assert slots() == [nil, nil, 51]
  end

  test "a cleanse burns one web and keeps the hold while another holds it" do
    web(51, 9_000)
    web(52, 5_000)
    hold([51, 52, nil])
    record_destroys()

    ClearBuffs.clear({:mob, 9_701}, [:debuffs])

    assert_received {:destroyed, 52}
    assert slots() == [51, nil, nil]
  end

  test "a dead holder's early end burns one web and ends the hold" do
    register_holder(:dead)
    web(51, 9_000)
    web(52, 5_000)
    hold([51, 52, nil])
    record_destroys()

    Interpreter.remove_status(:mob, 9_701, :sc_spiderweb)

    assert_received {:destroyed, 52}
    refute_received {:destroyed, 51}
    refute StatusStorage.has_status?(:mob, 9_701, :sc_spiderweb)
  end

  test "a living holder leaving the world burns one web and loses the hold" do
    web(51, 9_000)
    web(52, 5_000)
    hold([51, 52, nil])
    record_destroys()

    :ok = Interpreter.end_removed_unit_statuses(:mob, 9_701)

    assert_received {:destroyed, 52}
    refute_received {:destroyed, 51}
    refute StatusStorage.has_status?(:mob, 9_701, :sc_spiderweb)
  end

  test "a holder already gone from the registry burns one web on its removal" do
    UnitRegistry.unregister_unit(:mob, 9_701)
    web(51, 9_000)
    web(52, 5_000)
    hold([51, 52, nil])
    record_destroys()

    :ok = Interpreter.end_removed_unit_statuses(:mob, 9_701)

    assert_received {:destroyed, 52}
    refute_received {:destroyed, 51}
    refute StatusStorage.has_status?(:mob, 9_701, :sc_spiderweb)
  end

  test "running out leaves the webs standing" do
    web(51, 9_000)
    hold([51, nil, nil])
    reject(&Manager.destroy_async/1)
    entry = StatusStorage.get_status(:mob, 9_701, :sc_spiderweb)

    assert Interpreter.expire_status_if_current(:mob, 9_701, :sc_spiderweb, entry)
    refute StatusStorage.has_status?(:mob, 9_701, :sc_spiderweb)
  end
end
