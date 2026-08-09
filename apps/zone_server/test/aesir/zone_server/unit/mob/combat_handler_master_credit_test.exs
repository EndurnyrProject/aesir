defmodule Aesir.ZoneServer.Unit.Mob.CombatHandlerMasterCreditTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    :ok
  end

  test "owned summon damage is credited to its owner" do
    owner_id = 42
    summon_id = 9_001
    register_mob(summon_id, owner_id)

    {:noreply, victim} = CombatHandler.handle_apply_damage(100, summon_id, mob_state(1))

    assert MobState.damage_log(victim) == [{owner_id, 100}]
    refute Map.has_key?(victim.aggro_list, summon_id)
  end

  test "loot ownership makes the summon owner eligible when the victim is killed" do
    owner_id = 42
    summon_id = 9_001
    register_player(owner_id)
    register_mob(summon_id, owner_id)
    stub(Coordinator, :mob_died, fn _map, _instance_id, _attacker_id -> :ok end)
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{owner_id}")

    victim = %{mob_state(1) | no_exp: true}
    {:noreply, damaged} = CombatHandler.handle_apply_damage(100, summon_id, victim)

    assert %LootOwnership{first: ^owner_id} = LootOwnership.determine(damaged)

    {:noreply, killed} = CombatHandler.handle_apply_damage(900, summon_id, damaged)

    assert killed.is_dead

    assert_receive {:loot,
                    {:mob_killed,
                     %{
                       ownership: %LootOwnership{first: ^owner_id},
                       final_source: {:mob, ^summon_id}
                     }}}
  end

  test "a rootless mob lethal source still distributes prior player EXP without local rewards" do
    player_id = 42
    rootless_mob_id = 9_001
    register_player(player_id)
    register_mob(rootless_mob_id, nil)
    stub(Coordinator, :mob_died, fn _map, _instance_id, _attacker_id -> :ok end)
    Phoenix.PubSub.subscribe(Aesir.PubSub, "player:#{player_id}")

    victim = mob_state(1)
    mob_data = %{victim.mob_data | base_exp: 1_000, job_exp: 500, level: 1}
    victim = %{victim | mob_data: mob_data}

    {:noreply, damaged} =
      CombatHandler.handle_apply_damage(100, {:player, player_id}, victim)

    {:noreply, killed} =
      CombatHandler.handle_apply_damage(900, {:mob, rootless_mob_id}, damaged)

    assert killed.is_dead
    assert_receive {:progression, {:mob_kill_exp, 100, 50, :formless, _mob_class}}
    refute_receive {:loot, _event}, 50
  end

  test "unowned mob damage is retained only as an ownerless typed contributor" do
    attacker_id = 9_001
    register_mob(attacker_id, nil)

    {:noreply, victim} = CombatHandler.handle_apply_damage(100, attacker_id, mob_state(1))

    assert MobState.damage_log(victim) == []

    assert [%{contributor: {:mob, ^attacker_id}, reward_owner_id: nil, damage: 100}] =
             MobState.typed_damage_log(victim)
  end

  test "player damage remains credited to the player" do
    player_id = 42
    register_player(player_id)

    {:noreply, victim} = CombatHandler.handle_apply_damage(100, player_id, mob_state(1))

    assert MobState.damage_log(victim) == [{player_id, 100}]
  end

  defp register_mob(instance_id, owner_player_id) do
    state =
      instance_id
      |> mob_state()
      |> MobState.configure_summon(owner_player_id: owner_player_id)

    UnitRegistry.register_unit(:mob, instance_id, MobState, state, nil)
  end

  defp register_player(character_id) do
    character = %Character{
      id: character_id,
      account_id: character_id,
      name: "Owner",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }

    state = PlayerState.new(character)
    UnitRegistry.register_player(state, self())
  end

  defp mob_state(instance_id) do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      hp: 1_000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 25,
      mdef: 10,
      attack_range: 1,
      chase_range: 12,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(instance_id, mob_data, spawn_ref, "prontera", 100, 100)
  end
end
