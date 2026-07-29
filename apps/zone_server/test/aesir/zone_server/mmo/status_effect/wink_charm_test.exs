defmodule Aesir.ZoneServer.Mmo.StatusEffect.WinkCharmTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WinkCharm
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.StatusTickManager

  setup :setup_ets_tables

  test "charmed_against?/3 reads the mob's status, not the candidate's" do
    StatusStorage.apply_status(:mob, 100, :sc_winkcharm, caster_id: 200)
    StatusStorage.apply_status(:player, 201, :sc_winkcharm, caster_id: 100)

    assert Interpreter.charmed_against?(:mob, 100, 200)
    refute Interpreter.charmed_against?(:mob, 100, 201)
    refute Interpreter.charmed_against?(:mob, 101, 201)
  end

  test "zero damage preserves wink of charm" do
    mob = start_mob_session()
    assert :ok = apply_charm(mob.unit_id)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :mob,
               mob.pid,
               mob.unit_id,
               0,
               %{dmg_type: :physical},
               300
             )

    assert StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm)
  end

  test "non-zero damage from any source removes wink of charm" do
    mob = start_mob_session()
    assert :ok = apply_charm(mob.unit_id)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :mob,
               mob.pid,
               mob.unit_id,
               1,
               %{dmg_type: :magic},
               300
             )

    refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm)
  end

  test "status expiry restores targeting eligibility" do
    mob = start_mob_session()
    assert :ok = apply_charm(mob.unit_id)
    assert Interpreter.charmed_against?(:mob, mob.unit_id, 200)

    :ok =
      StatusStorage.update_status(:mob, mob.unit_id, :sc_winkcharm, fn status ->
        %{status | expires_at: System.monotonic_time(:millisecond) - 1}
      end)

    assert {:noreply, %StatusTickManager.State{}} =
             StatusTickManager.handle_info(:tick, %StatusTickManager.State{})

    refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_winkcharm)
    refute Interpreter.charmed_against?(:mob, mob.unit_id, 200)
  end

  test "metadata contains only the upstream debuff and dispel disposition" do
    metadata = WinkCharm.metadata()

    assert metadata.properties == [:debuff]
    assert metadata.no_dispel == false
    assert metadata.no_save == false
    assert metadata.remove_on_map_change == false
    assert metadata.bypass_boss_immunity == false
  end

  defp apply_charm(mob_id) do
    Interpreter.apply_status(:mob, mob_id, :sc_winkcharm,
      caster_id: 200,
      duration: 30_000,
      bypass_resistance: true
    )
  end
end
