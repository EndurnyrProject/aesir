defmodule Aesir.ZoneServer.Mmo.Combat.HomunculusPlayerOnlyExclusionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  test "normal-hit passive, equipment-break, and HP-drain calls stay out of Homunculus attacks" do
    source = combat_source("auto_attack.ex")

    homunculus_path =
      function_slice(
        source,
        "def execute_homunculus_attack(",
        "defp resolve_mob_attack_or_intercept("
      )

    assert source =~ "dispatch_normal_hit_passives(player_state"
    assert source =~ "roll_equipment_breaks(player_state"
    assert source =~ "drain_hp(attacker"
    refute homunculus_path =~ "dispatch_normal_hit_passives("
    refute homunculus_path =~ "roll_equipment_breaks("
    refute homunculus_path =~ "drain_hp("
  end

  test "Shield Charge requires player equipment but remains callable by mobs" do
    player = %PlayerState{stats: %Stats{equipment: %Equipment{}}}
    mob = struct(MobState)
    definition = CrShieldcharge.definition()

    assert {:error, :requires_shield} = CrShieldcharge.validate(player, :self, 1, definition)
    assert :ok = CrShieldcharge.validate(mob, :self, 1, definition)
  end

  test "shield equipment base fallback is the exact private non-player branch" do
    source = combat_source("skill_attack.ex")

    assert source =~ "defp shield_base_opts(%{inventory: inventory, stats: stats}, opts)"
    assert source =~ "defp shield_base_opts(_caster_state, _opts), do: []"
  end

  test "Homunculus ground hits invoke the exact no-session walk-delay branch" do
    source = combat_source("magic_attack.ex")

    assert source =~ "defp apply_walk_delay(:homunculus, _target_pid, _dst_delay), do: :ok"
  end

  defp function_slice(source, start_marker, end_marker) do
    [_before, tail] = String.split(source, start_marker, parts: 2)
    [body | _] = String.split(tail, end_marker, parts: 2)
    body
  end

  defp combat_source(file) do
    "../../../../../lib/aesir/zone_server/mmo/combat/#{file}"
    |> Path.expand(__DIR__)
    |> File.read!()
  end
end
