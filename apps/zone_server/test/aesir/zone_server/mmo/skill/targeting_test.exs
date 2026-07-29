defmodule Aesir.ZoneServer.Mmo.Skill.TargetingTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Targeting

  defp player(id, attrs \\ %{}) do
    Map.merge(
      %{
        character_id: id,
        party_id: 0,
        guild_id: 0,
        action_state: :idle,
        stats: %{current_state: %{hp: 100}}
      },
      attrs
    )
  end

  defp mob(id, attrs \\ %{}) do
    Map.merge(%{instance_id: id, hp: 100, is_dead: false}, attrs)
  end

  test "versus maps are disabled until map modes exist" do
    refute Targeting.versus_map?(:prontera)
  end

  test "another player is not a valid target until PvP map modes exist" do
    assert {:error, :invalid_target} = Targeting.validate_enemy(player(1000), player(2000))
  end

  test "self is never an enemy" do
    assert {:error, :invalid_target} = Targeting.validate_enemy(player(1000), player(1000))
  end

  test "members of the same nonzero party are not enemies" do
    assert {:error, :invalid_target} =
             Targeting.validate_enemy(
               player(1000, %{party_id: 10}),
               player(2000, %{party_id: 10})
             )
  end

  test "members of the same nonzero guild are not enemies" do
    assert {:error, :invalid_target} =
             Targeting.validate_enemy(
               player(1000, %{guild_id: 20}),
               player(2000, %{guild_id: 20})
             )
  end

  test "a living mob is an enemy of a player" do
    assert :ok = Targeting.validate_enemy(player(1000), mob(2000))
  end

  test "a mob may still target a living player" do
    assert :ok = Targeting.validate_enemy(mob(1000), player(2000))
  end

  test "a mob is never a valid target for another mob" do
    assert {:error, :invalid_target} = Targeting.validate_enemy(mob(1000), mob(2000))
  end

  test "dead players and mobs are not enemies" do
    assert {:error, :target_dead} =
             Targeting.validate_enemy(player(1000), player(2000, %{action_state: :dead}))

    assert {:error, :target_dead} =
             Targeting.validate_enemy(player(1000), mob(2000, %{hp: 0, is_dead: true}))
  end
end
