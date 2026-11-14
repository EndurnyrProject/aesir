defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.MagicalbulletCasterTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsMagicalbullet
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  defp definition, do: GsMagicalbullet.definition()

  @tag game_mode: :renewal
  test "a renewal mob caster buffs itself instead of striking" do
    mob = mob_state(77)
    :ok = UnitRegistry.register_unit(:mob, 77, MobState, mob, self())
    reject(&Combat.execute_skill_attack/3)

    assert {:ok, ^mob} = GsMagicalbullet.mob_cast(mob, :self, 1, definition(), %{})

    assert StatusStorage.has_status?(:mob, 77, :sc_magicalbullet)
  end

  @tag game_mode: :pre_renewal
  test "a pre-renewal mob caster fires the Ghost hit" do
    mob = mob_state(77)

    expect(Combat, :execute_skill_attack, fn ^mob, {:mob, 2}, opts ->
      assert opts[:element] == :ghost
      assert opts[:skill_ratio] == 100
      :ok
    end)

    assert :ok = GsMagicalbullet.mob_cast(mob, {:unit, :mob, 2}, 1, definition(), %{})
  end

  @tag game_mode: :renewal
  test "a renewal player caster buffs itself and deals no damage" do
    caster = player_state(55)
    :ok = UnitRegistry.register_unit(:player, 55, PlayerState, caster, self())
    reject(&Combat.execute_skill_attack/3)

    assert {:ok, ^caster} = GsMagicalbullet.cast(caster, :self, 1, definition())

    assert StatusStorage.has_status?(:player, 55, :sc_magicalbullet)
  end

  @tag game_mode: :pre_renewal
  test "a pre-renewal player caster resolves the unit target" do
    caster = player_state(55)

    expect(Combat, :execute_skill_attack, fn ^caster, {:mob, 2}, opts ->
      assert opts[:element] == :ghost
      :ok
    end)

    assert {:ok, ^caster} = GsMagicalbullet.cast(caster, {:unit, {:mob, 2}}, 1, definition())
  end

  defp player_state(character_id) do
    PlayerStateFixture.build(%{
      character_id: character_id,
      map_name: "prontera",
      x: 10,
      y: 10,
      stats: %{combat_stats: %CombatStats{}}
    })
  end

  defp mob_state(instance_id) do
    %MobState{
      instance_id: instance_id,
      mob_id: 1_002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: nil,
      map_name: "prontera",
      x: 10,
      y: 10,
      hp: 100,
      sp: 50,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 50)
  end
end
