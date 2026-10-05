defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWebTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.SpiderWeb
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Manager)
    Mimic.copy(UnitRegistry)
    # Ending the hold builds the holder's status context.
    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)
    :ok
  end

  @target {:mob, 9_701}

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

  test "halves the holder's FLEE" do
    assert SpiderWeb.modifiers(%{state: %{groups: [51]}}, %{}) == %{flee_rate: -50}
  end

  defp mode_value(renewal, pre_renewal),
    do: %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]

  defp hold(groups),
    do: :ok = StatusStorage.apply_status(:mob, 9_701, :sc_spiderweb, state: %{groups: groups})

  @defender %{unit_type: :mob, unit_id: 9_701, element: {:earth, 1}}

  test "a fire attribute step against a webbed unit gains 100 ratio points" do
    assert DamageShared.apply_element_step(100, :fire, nil, @defender) == 150

    hold([51])

    assert DamageShared.apply_element_step(100, :fire, nil, @defender) == mode_value(250, 300)
  end

  test "a fire step burns the web closest to running out and keeps the hold" do
    web(51, 9_000)
    web(52, 5_000)
    hold([51, 52])
    expect(Manager, :destroy_async, fn 52 -> :ok end)

    assert SpiderWeb.consume(:mob, 9_701)
    assert %{state: %{groups: [51]}} = StatusStorage.get_status(:mob, 9_701, :sc_spiderweb)
  end

  test "a fire step on the last web ends the hold" do
    web(51, 9_000)
    hold([51])
    stub(Manager, :destroy_async, fn 51 -> :ok end)

    assert SpiderWeb.consume(:mob, 9_701)
    refute StatusStorage.has_status?(:mob, 9_701, :sc_spiderweb)
  end

  test "other elements neither gain the bonus nor burn a web" do
    hold([51])

    assert DamageShared.apply_element_step(100, :water, nil, @defender) == 100
    assert %{state: %{groups: [51]}} = StatusStorage.get_status(:mob, 9_701, :sc_spiderweb)
  end

  test "a step that loses its claim to a concurrent burn reads the hold again" do
    web(51, 9_000)
    web(52, 5_000)
    web(53, 7_000)
    hold([51, 52, 53])
    test_pid = self()
    stub(Manager, :destroy_async, fn gid -> send(test_pid, {:destroyed, gid}) end)

    # A concurrent step burns web 52 between this step's read and its claim.
    expect(StatusStorage, :replace_status_if_current, fn type, id, status, _read, _replacement ->
      StatusStorage.update_status(type, id, status, &put_in(&1.state.groups, [51, 53]))
      false
    end)

    assert SpiderWeb.consume(:mob, 9_701)
    assert_received {:destroyed, 53}
    refute_received {:destroyed, 52}
    assert %{state: %{groups: [51]}} = StatusStorage.get_status(:mob, 9_701, :sc_spiderweb)
  end

  test "an unwebbed unit has nothing to consume" do
    refute SpiderWeb.consume(:mob, 9_701)
  end

  test "ending the hold tears down every web" do
    test_pid = self()
    stub(Manager, :destroy_async, fn gid -> send(test_pid, {:destroyed, gid}) end)

    assert SpiderWeb.on_expire(@target, %{state: %{groups: [51, 52]}}, %{}) == :ok
    assert_received {:destroyed, 51}
    assert_received {:destroyed, 52}
  end
end
