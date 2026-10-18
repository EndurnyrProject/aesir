defmodule Aesir.ZoneServer.Mmo.StatusEffect.CloseConfineLinkTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgCloseconfine
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    {:ok, form} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: form.id, amount: 1, respawn_time: 0, spawn_area: nil}
    mob = MobState.new(801, form, spawn, "prontera", 100, 100)
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
    %{id: mob.instance_id, mob: mob}
  end

  test "link bookkeeping cannot resurrect a missing entry and refreshes silently without changing FLEE",
       %{id: id} do
    increment = fn entry ->
      %{entry | val2: entry.val2 + 1, expires_at: entry.expires_at + 1_000}
    end

    assert is_nil(Interpreter.update_link_status(:mob, id, :sc_closeconfine, increment))

    assert :ok =
             Interpreter.apply_status(:mob, id, :sc_closeconfine,
               val1: 1,
               val2: 1,
               val3: 50,
               duration: 11_000,
               bypass_resistance: true
             )

    assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_closeconfine, :apply}}}
    prior = StatusStorage.get_status(:mob, id, :sc_closeconfine)
    updated = Interpreter.update_link_status(:mob, id, :sc_closeconfine, increment)

    assert {updated.val2, updated.val3, updated.started_at} == {2, 50, prior.started_at}
    assert updated.expires_at == prior.expires_at + 1_000
    assert updated.generation > prior.generation
    refute_receive {:"$gen_cast", {:casting, {:status_changed, :sc_closeconfine, _}}}, 20
    assert updated == StatusStorage.get_status(:mob, id, :sc_closeconfine)
  end

  test "additional recipients refresh silently and one expiry releases the ordinary hold's nearby links",
       %{id: id, mob: mob} do
    {:ok, definition} = Catalog.by_name(:rg_closeconfine)
    for target_id <- [802, 803, 804], do: register_mob(%{mob | instance_id: target_id})
    assert {:ok, ^mob} = RgCloseconfine.cast(mob, {:unit, {:mob, 802}}, 1, definition)
    held = StatusStorage.get_status(:mob, id, :sc_closeconfine)

    assert {held.val1, held.val2, held.val3} ==
             {1, 1, if(GameMode.mode() == :renewal, do: 50, else: 10)}

    assert_received {:"$gen_cast", {:casting, {:status_changed, :sc_closeconfine, :apply}}}

    assert {:ok, ^mob} = RgCloseconfine.cast(mob, {:unit, {:mob, 802}}, 1, definition)
    assert StatusStorage.get_status(:mob, id, :sc_closeconfine) == held
    before = System.monotonic_time(:millisecond)
    assert {:ok, ^mob} = RgCloseconfine.cast(mob, {:unit, {:mob, 803}}, 1, definition)
    after_start = System.monotonic_time(:millisecond)
    refreshed = StatusStorage.get_status(:mob, id, :sc_closeconfine)

    assert {refreshed.val1, refreshed.val2, refreshed.val3, refreshed.started_at} ==
             {1, 2, held.val3, held.started_at}

    assert refreshed.expires_at >= before + 11_000
    assert refreshed.expires_at <= after_start + 11_000
    refute_receive {:"$gen_cast", {:casting, {:status_changed, :sc_closeconfine, :apply}}}, 20

    assert {:ok, ^mob} = RgCloseconfine.cast(mob, {:unit, {:mob, 804}}, 1, definition)
    displaced = %{mob | instance_id: 804, x: 112}
    :ok = UnitRegistry.update_unit_state(:mob, 804, displaced)

    :ok =
      SpatialIndex.update_unit_position(:mob, 804, displaced.x, displaced.y, displaced.map_name)

    recipient = StatusStorage.get_status(:mob, 802, :sc_closeconfine2)
    assert Interpreter.expire_status_if_current(:mob, 802, :sc_closeconfine2, recipient)
    refute StatusStorage.has_status?(:mob, id, :sc_closeconfine)
    refute StatusStorage.has_status?(:mob, 803, :sc_closeconfine2)
    assert StatusStorage.has_status?(:mob, 804, :sc_closeconfine2)
    assert Interpreter.can_move?(:mob, id)
  end

  test "a missing caster fails an ordinary recipient but loaded values do not create a link", %{
    id: id,
    mob: mob
  } do
    params = [val1: 1, val2: 999, caster_id: 999, source_type: :mob, duration: 10_000]

    assert {:error, :caster_not_found} =
             Interpreter.apply_status(:mob, id, :sc_closeconfine2, params)

    refute StatusStorage.has_status?(:mob, id, :sc_closeconfine2)
    register_mob(%{mob | instance_id: 999})

    assert :ok =
             Interpreter.apply_status(
               :mob,
               id,
               :sc_closeconfine2,
               Keyword.put(params, :loaded, true)
             )

    assert %{val2: 999, val3: 0} = StatusStorage.get_status(:mob, id, :sc_closeconfine2)
    refute StatusStorage.has_status?(:mob, 999, :sc_closeconfine)
  end

  test "the caster's sweep preserves a dead recipient's root through resurrection until its own expiry",
       %{id: id, mob: mob} do
    {:ok, definition} = Catalog.by_name(:rg_closeconfine)
    for target_id <- [802, 803], do: register_mob(%{mob | instance_id: target_id})
    assert {:ok, ^mob} = RgCloseconfine.cast(mob, {:unit, {:mob, 802}}, 1, definition)
    assert {:ok, ^mob} = RgCloseconfine.cast(mob, {:unit, {:mob, 803}}, 1, definition)
    corpse = %{mob | instance_id: 803, hp: 0, is_dead: true}
    :ok = UnitRegistry.update_unit_state(:mob, 803, corpse)
    assert :ok = Interpreter.remove_on_death(:mob, 803)
    live = StatusStorage.get_status(:mob, 802, :sc_closeconfine2)
    assert Interpreter.expire_status_if_current(:mob, 802, :sc_closeconfine2, live)
    refute StatusStorage.has_status?(:mob, id, :sc_closeconfine)
    assert %{val2: ^id} = StatusStorage.get_status(:mob, 803, :sc_closeconfine2)
    :ok = UnitRegistry.update_unit_state(:mob, 803, %{corpse | hp: 1, is_dead: false})
    refute Interpreter.can_move?(:mob, 803)
    retained = StatusStorage.get_status(:mob, 803, :sc_closeconfine2)
    assert Interpreter.expire_status_if_current(:mob, 803, :sc_closeconfine2, retained)
    assert Interpreter.can_move?(:mob, 803)
  end

  test "a rejected caster self-status does not reject the recipient", %{id: id, mob: mob} do
    form = %{mob.mob_data | class: :boss, modes: [:status_immune, :detector, :knockback_immune]}
    caster = MobState.new(805, form, mob.spawn_ref, mob.map_name, mob.x, mob.y)
    register_mob(caster)

    assert :ok =
             Interpreter.apply_status(:mob, id, :sc_closeconfine2,
               val1: 1,
               val2: 805,
               caster_id: 805,
               source_type: :mob,
               duration: 10_000
             )

    assert StatusStorage.has_status?(:mob, id, :sc_closeconfine2)
    refute StatusStorage.has_status?(:mob, 805, :sc_closeconfine)
  end

  defp register_mob(mob) do
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, mob.instance_id, mob.x, mob.y, mob.map_name)
  end
end
