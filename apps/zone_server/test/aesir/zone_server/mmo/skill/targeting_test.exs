defmodule Aesir.ZoneServer.Mmo.Skill.TargetingTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok = MapFlags.reload()
  end

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

  defp homunculus(world_gid, owner_id, attrs \\ %{}) do
    Map.merge(
      %{
        owner_character_id: owner_id,
        world_gid: world_gid,
        map_name: "prontera",
        hp: 100,
        action_state: :idle
      },
      attrs
    )
  end

  defp combatant_homunculus(world_gid, owner_id, attrs \\ %{}) do
    Combatant.new!(
      Map.merge(
        %{
          unit_type: :homunculus,
          unit_id: world_gid,
          social_root: {:player, owner_id},
          reward_root: {:player, owner_id},
          map_name: "prontera",
          party_id: 0,
          guild_id: 0
        },
        attrs
      )
    )
  end

  defp register_owner(owner_id, party_id, guild_id) do
    state = %PlayerState{character_id: owner_id, party_id: party_id, guild_id: guild_id}
    :ok = UnitRegistry.register_unit(:player, owner_id, PlayerState, state, self())
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

  describe "versus context resolution" do
    test "two unrelated players are enemies on a :pvp map" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      assert :ok =
               Targeting.validate_enemy(
                 player(1000, %{map_name: "prontera"}),
                 player(2000, %{map_name: "prontera"})
               )
    end

    test "same-party players are protected on :pvp until :pvp_noparty" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      attacker = player(1000, %{map_name: "prontera", party_id: 10})
      target = player(2000, %{map_name: "prontera", party_id: 10})

      assert {:error, :invalid_target} = Targeting.validate_enemy(attacker, target)

      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, true)
      assert :ok = Targeting.validate_enemy(attacker, target)
    end

    test "same-guild players are protected on :pvp until :pvp_noguild" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      attacker = player(1000, %{map_name: "prontera", guild_id: 20})
      target = player(2000, %{map_name: "prontera", guild_id: 20})

      assert {:error, :invalid_target} = Targeting.validate_enemy(attacker, target)

      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, true)
      assert :ok = Targeting.validate_enemy(attacker, target)
    end

    test ":gvg takes precedence over :pvp and protects same party/guild unconditionally" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      :ok = MapFlags.set_runtime("prontera", :gvg, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noparty, true)
      :ok = MapFlags.set_runtime("prontera", :pvp_noguild, true)

      assert {:error, :invalid_target} =
               Targeting.validate_enemy(
                 player(1000, %{map_name: "prontera", party_id: 10}),
                 player(2000, %{map_name: "prontera", party_id: 10})
               )

      assert {:error, :invalid_target} =
               Targeting.validate_enemy(
                 player(3000, %{map_name: "prontera", guild_id: 20}),
                 player(4000, %{map_name: "prontera", guild_id: 20})
               )

      assert :ok =
               Targeting.validate_enemy(
                 player(5000, %{map_name: "prontera", guild_id: 20}),
                 player(6000, %{map_name: "prontera", guild_id: 30})
               )
    end

    test "non-binary or missing map names resolve to :off" do
      for map_name <- [nil, :prontera] do
        assert {:error, :invalid_target} =
                 Targeting.validate_enemy(
                   player(1000, %{map_name: map_name}),
                   player(2000, %{map_name: map_name})
                 )
      end
    end
  end

  describe "homunculus owner enrichment" do
    test "a homunculus inherits its owner's party and guild" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      register_owner(900, 10, 20)

      party_ally = player(1000, %{map_name: "prontera", party_id: 10})
      guild_ally = player(1100, %{map_name: "prontera", guild_id: 20})
      stranger = player(2000, %{map_name: "prontera"})
      companion = homunculus(500, 900)

      assert {:error, :invalid_target} = Targeting.validate_enemy(party_ally, companion)
      assert {:error, :invalid_target} = Targeting.validate_enemy(guild_ally, companion)
      assert :ok = Targeting.validate_enemy(stranger, companion)
    end

    test "a homunculus whose owner vanished is treated as unaffiliated" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      party_member = player(1000, %{map_name: "prontera", party_id: 10})
      companion = homunculus(500, 900)

      assert :ok = Targeting.validate_enemy(party_member, companion)
    end

    test "an owner and their own homunculus are never enemies, even on a versus map" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      owner = player(900, %{map_name: "prontera"})
      companion = homunculus(500, 900)

      assert {:error, :invalid_target} = Targeting.validate_enemy(owner, companion)
    end

    test "a production-shaped %Combatant{} homunculus inherits its owner's party and guild" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)
      register_owner(900, 10, 20)

      party_ally = player(1000, %{map_name: "prontera", party_id: 10})
      guild_ally = player(1100, %{map_name: "prontera", guild_id: 20})
      stranger = player(2000, %{map_name: "prontera"})
      companion = combatant_homunculus(500, 900)

      assert {:error, :invalid_target} = Targeting.validate_enemy(party_ally, companion)
      assert {:error, :invalid_target} = Targeting.validate_enemy(guild_ally, companion)
      assert :ok = Targeting.validate_enemy(stranger, companion)
    end

    test "a production-shaped homunculus whose owner vanished is forced to 0/0 affiliation" do
      :ok = MapFlags.set_runtime("prontera", :pvp, true)

      party_member = player(1000, %{map_name: "prontera", party_id: 10})
      companion = combatant_homunculus(500, 900, %{party_id: 10, guild_id: 20})

      assert :ok = Targeting.validate_enemy(party_member, companion)
    end
  end
end
