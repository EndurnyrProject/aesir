defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsCrackerDustTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsCracker
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDust
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :verify_on_exit!

  test "Cracker scales stun chance with cast-end distance and retains cost on resistance" do
    caster = %PlayerState{character_id: 1, x: 0, y: 0}

    for {distance, rate} <- Enum.with_index([65, 60, 55, 50, 45, 40, 35, 30, 30]) do
      expect(TargetResolver, :resolve_target_position, fn {:mob, 2} ->
        {:ok, :mob, {rate, 0, "map"}}
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, 2, :sc_stun, opts ->
        assert opts[:success_rate] == distance
        {:error, :resisted}
      end)

      assert {:ok, ^caster} =
               GsCracker.cast(caster, {:unit, {:mob, 2}}, 1, GsCracker.definition(:renewal))
    end
  end

  test "Dust passes its ratio and surviving-target knockback to combat" do
    caster = %PlayerState{character_id: 1, x: 1, y: 2}

    expect(Combat, :execute_skill_attack, fn ^caster, {:mob, 2}, opts ->
      assert opts[:skill_ratio] == 350
      assert opts[:base_distance] == 5
      assert opts[:native_requires_survival]
      :ok
    end)

    assert {:ok, ^caster} =
             GsDust.cast(caster, {:unit, {:mob, 2}}, 5, GsDust.definition(:renewal))
  end

  test "Cracker skips non-player casters and homunculus targets" do
    caster = %PlayerState{character_id: 1, x: 0, y: 0}
    mob = mob()
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^mob} =
             GsCracker.cast(mob, {:unit, {:mob, 2}}, 1, GsCracker.definition(:renewal))

    expect(TargetResolver, :resolve_target_position, fn {:homunculus, 2} ->
      {:ok, :homunculus, {1, 1, "map"}}
    end)

    assert {:ok, ^caster} =
             GsCracker.cast(caster, {:unit, {:homunculus, 2}}, 1, GsCracker.definition(:renewal))
  end

  test "Dust allows a mob caster" do
    mob = mob()

    expect(Combat, :execute_skill_attack, fn ^mob, {:player, 2}, opts ->
      assert opts[:skill_ratio] == 150
      :ok
    end)

    assert :ok = GsDust.mob_cast(mob, {:unit, :player, 2}, 1, GsDust.definition(:renewal), %{})
  end

  defp mob do
    %MobState{
      instance_id: 3,
      mob_id: 12705,
      mob_data: %{},
      spawn_ref: :test,
      x: 1,
      y: 2,
      map_name: "map",
      hp: 100,
      sp: 100,
      spawned_at: 0
    }
  end
end
