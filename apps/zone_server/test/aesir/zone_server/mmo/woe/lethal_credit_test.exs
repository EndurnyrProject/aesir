defmodule Aesir.ZoneServer.Mmo.Woe.LethalCreditTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Lifecycle.Event
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup {Aesir.MimicMode, :global}
  setup :setup_ets_tables

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _id, _owner_id -> :ok end)
    :ok = Lifecycle.subscribe()
    :ok
  end

  test "typed mob delivery survives a colliding player id and credits the mob owner guild" do
    shared_id = 42
    owner_id = 7
    register_player(shared_id, 999)
    register_player(owner_id, 77)
    register_owned_mob(shared_id, owner_id)
    :ok = Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{owner_id}")
    victim = start_victim(501, 10)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :mob,
               victim,
               501,
               10,
               %{dmg_type: :physical, is_short: true},
               {:mob, shared_id}
             )

    assert %{is_dead: true} = MobSession.get_state(victim)

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_type: :mob,
                      unit_id: 501,
                      reason: :death,
                      old_map: "prontera",
                      kill_credit: credit
                    }}

    assert credit == %{attacker: {:mob, shared_id}, character_id: owner_id, guild_id: 77}

    assert_receive {:loot, {:kill_gain, %{kill_bf: :melee, final_source: {:mob, ^shared_id}}}}
  end

  test "a rootless typed attacker keeps its identity with nil reward owner" do
    attacker_id = 43
    register_owned_mob(attacker_id, nil)
    victim = start_victim(502, 1)

    assert :ok =
             DamageApplication.apply_unit_damage(:mob, victim, 502, 1, %{}, {:mob, attacker_id})

    assert %{is_dead: true} = MobSession.get_state(victim)

    assert_receive {:unit_lifecycle,
                    %Event{
                      kill_credit: %{
                        attacker: {:mob, ^attacker_id},
                        character_id: nil,
                        guild_id: nil
                      }
                    }}
  end

  test "a missing reward owner snapshot preserves character credit with nil guild" do
    attacker_id = 44
    owner_id = 8
    register_owned_mob(attacker_id, owner_id)
    victim = start_victim(503, 1)

    assert :ok =
             DamageApplication.apply_unit_damage(:mob, victim, 503, 1, %{}, {:mob, attacker_id})

    assert %{is_dead: true} = MobSession.get_state(victim)

    assert_receive {:unit_lifecycle,
                    %Event{
                      kill_credit: %{
                        attacker: {:mob, ^attacker_id},
                        character_id: ^owner_id,
                        guild_id: nil
                      }
                    }}
  end

  test "published guild credit is immutable after the owner logs out" do
    attacker_id = 45
    owner_id = 9
    register_player(owner_id, 77)
    register_owned_mob(attacker_id, owner_id)
    victim = start_victim(504, 1)

    assert :ok =
             DamageApplication.apply_unit_damage(:mob, victim, 504, 1, %{}, {:mob, attacker_id})

    assert %{is_dead: true} = MobSession.get_state(victim)
    assert :ok = UnitRegistry.unregister_unit(:player, owner_id)

    assert_receive {:unit_lifecycle,
                    %Event{kill_credit: %{character_id: ^owner_id, guild_id: 77}}}
  end

  test "nonlethal and duplicate damage publish no extra death events" do
    attacker_id = 10
    register_player(attacker_id, 0)
    victim = start_victim(505, 10)

    assert :ok = DamageApplication.apply_unit_damage(:mob, victim, 505, 4, %{}, attacker_id)
    assert %{hp: 6, is_dead: false} = MobSession.get_state(victim)
    refute_receive {:unit_lifecycle, %Event{reason: :death}}, 20

    assert :ok = DamageApplication.apply_unit_damage(:mob, victim, 505, 6, %{}, attacker_id)
    assert %{is_dead: true} = MobSession.get_state(victim)

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_id: 505,
                      kill_credit: %{
                        attacker: {:player, ^attacker_id},
                        character_id: ^attacker_id,
                        guild_id: nil
                      }
                    }}

    assert :ok = DamageApplication.apply_unit_damage(:mob, victim, 505, 1, %{}, attacker_id)
    assert %{is_dead: true} = MobSession.get_state(victim)
    refute_receive {:unit_lifecycle, %Event{reason: :death}}, 50
  end

  test "publish_death/3 remains compatible and emits nil credit" do
    assert :ok = Lifecycle.publish_death(:player, 1_001, "prontera")

    assert_receive {:unit_lifecycle,
                    %Event{
                      unit_type: :player,
                      unit_id: 1_001,
                      old_map: "prontera",
                      kill_credit: nil
                    }}
  end

  defp start_victim(instance_id, hp) do
    state = %{mob_state(instance_id) | hp: hp, max_hp: hp, no_exp: true, no_drops: true}
    start_supervised!({MobSession, %{state: state, awake: false}})
  end

  defp register_player(character_id, guild_id) do
    UnitRegistry.register_unit(
      :player,
      character_id,
      PlayerState,
      player_state(character_id, guild_id),
      self()
    )
  end

  defp player_state(character_id, guild_id) do
    %PlayerState{character_id: character_id, guild_id: guild_id}
  end

  defp register_owned_mob(instance_id, owner_id) do
    state = MobState.configure_summon(mob_state(instance_id), owner_player_id: owner_id)
    UnitRegistry.register_unit(:mob, instance_id, MobState, state, nil)
  end

  defp mob_state(instance_id) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 100,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      atk: 1,
      matk: 1,
      def: 0,
      mdef: 0,
      attack_range: 1,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      drops: []
    }

    spawn = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(instance_id, mob_data, spawn, "prontera", 100, 100)
  end
end
