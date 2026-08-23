defmodule Aesir.ZoneServer.Unit.Mob.HomunculusRewardsTest do
  use ExUnit.Case, async: false
  use Mimic

  @moduletag :capture_log

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(ProgressionHandler)
    Mimic.copy(Broadcast)
    Mimic.copy(Coordinator)
    Mimic.copy(PartyManager)
    :ok
  end

  test "typed split uses the full log denominator and eligible actual contributor count" do
    eligible = [
      entry({:player, 1}, 1, 50, 0),
      entry({:homunculus, 20}, 1, 25, 1)
    ]

    assert [
             %{contributor: {:player, 1}, base_share: 62, job_share: 31},
             %{contributor: {:homunculus, 20}, base_share: 31, job_share: 15}
           ] = KillExp.split_typed(100, 50, eligible, 100, 25, 12)
  end

  test "typed split preserves the positive owner floor but companion ten-percent has no minimum" do
    eligible = [entry({:homunculus, 20}, 1, 1, 0)]

    assert [%{base_share: 1, job_share: 1, homunculus_share: 0}] =
             KillExp.split_typed(1, 1, eligible, 1_000_000, 0, 12)
  end

  test "owner and Homunculus split separately then aggregate owner rewards and companion ten-percent" do
    Application.put_env(:zone_server, :exp_bonus_attacker, 0)
    on_exit(fn -> Application.delete_env(:zone_server, :exp_bonus_attacker) end)

    player = player_state(1, "prontera", 100)
    homunculus = homunculus_state(20, 1, "prontera", 100)
    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    UnitRegistry.register_unit(:homunculus, 20, HomunculusState, homunculus, self())
    PubSub.subscribe(Aesir.PubSub, "player:1")
    expect(LevelPenalty, :exp, fn 100, 50 -> 50 end)

    KillExp.distribute_typed(
      [entry({:player, 1}, 1, 60, 0), entry({:homunculus, 20}, 1, 40, 1)],
      100,
      50,
      100,
      "prontera",
      :brute
    )

    assert_receive {:"$gen_cast", {:homunculus, {:gain_exp, 20, 10, "prontera"}}}
    assert_receive {:progression, {:mob_kill_exp, 50, 25, :brute, _mob_class}}
  end

  test "typed grants carry the killed boss's class" do
    Application.put_env(:zone_server, :exp_bonus_attacker, 0)
    on_exit(fn -> Application.delete_env(:zone_server, :exp_bonus_attacker) end)

    player = player_state(1, "prontera", 100)
    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    PubSub.subscribe(Aesir.PubSub, "player:1")
    expect(LevelPenalty, :exp, fn 25, 50 -> 100 end)

    state = reward_mob_state()
    state = %{state | no_exp: false, mob_data: %{state.mob_data | modes: [:boss]}}

    KillExp.distribute_typed(
      [entry({:player, 1}, 1, 100, 0)],
      100,
      50,
      25,
      "prontera",
      :brute,
      state
    )

    assert_receive {:progression, {:mob_kill_exp, 100, 50, :brute, :boss}}
  end

  test "party equal-share-only recipients grant no companion EXP" do
    Application.put_env(:zone_server, :exp_bonus_attacker, 0)
    Application.put_env(:zone_server, :party_even_share_bonus, 0)

    on_exit(fn ->
      Application.delete_env(:zone_server, :exp_bonus_attacker)
      Application.delete_env(:zone_server, :party_even_share_bonus)
    end)

    owner = %{player_state(1, "prontera", 100) | party_id: 10}
    recipient = %{player_state(2, "prontera", 100) | party_id: 10}
    recipient_homunculus = homunculus_state(20, 2, "prontera", 100)
    UnitRegistry.register_unit(:player, 1, PlayerState, owner, self())
    UnitRegistry.register_unit(:player, 2, PlayerState, recipient, self())
    UnitRegistry.register_unit(:homunculus, 20, HomunculusState, recipient_homunculus, self())

    party = %PartyState{
      party_id: 10,
      name: "Party",
      leader_char_id: 1,
      exp_share: true,
      item_pickup_share: false,
      members: %{
        1 => Member.new(1, "Owner1", 50, true, "prontera"),
        2 => Member.new(2, "Owner2", 50, true, "prontera")
      }
    }

    stub(PartyManager, :get, fn 10 -> {:ok, party} end)
    PubSub.subscribe(Aesir.PubSub, "player:1")
    PubSub.subscribe(Aesir.PubSub, "player:2")

    KillExp.distribute_typed(
      [entry({:player, 1}, 1, 100, 0)],
      100,
      50,
      100,
      "prontera",
      :brute
    )

    assert_receive {:progression, {:mob_kill_exp, 20, 10, :brute, _mob_class}}
    assert_receive {:progression, {:mob_kill_exp, 20, 10, :brute, _mob_class}}
    refute_receive {:"$gen_cast", {:homunculus, {:gain_exp, 20, _amount, "prontera"}}}, 50
  end

  test "typed loot aggregates colliding owner and Homunculus damage before one root bonus" do
    state =
      mob_state()
      |> MobState.add_typed_aggro({:player, 7}, 7, 40)
      |> MobState.add_typed_aggro({:homunculus, 7}, 7, 10)
      |> MobState.add_typed_aggro({:player, 8}, 8, 75)

    eligible? = fn %{reward_owner_id: owner_id}, "prontera" -> is_integer(owner_id) end

    assert %LootOwnership{first: 7, second: 8, third: nil} =
             LootOwnership.determine_typed(state, eligible?)
  end

  test "typed loot keeps earliest owner order when aggregated damage ties" do
    Application.put_env(:zone_server, :first_attack_loot_bonus, 0)
    on_exit(fn -> Application.delete_env(:zone_server, :first_attack_loot_bonus) end)

    state =
      mob_state()
      |> MobState.add_typed_aggro({:homunculus, 20}, 1, 25)
      |> MobState.add_typed_aggro({:player, 2}, 2, 50)
      |> MobState.add_typed_aggro({:player, 1}, 1, 25)

    eligible? = fn %{reward_owner_id: owner_id}, "prontera" -> is_integer(owner_id) end

    assert %LootOwnership{first: 1, second: 2} =
             LootOwnership.determine_typed(state, eligible?)
  end

  test "an owned mob keeps EXP and loot weight after leaving the registry" do
    Application.put_env(:zone_server, :exp_bonus_attacker, 0)
    on_exit(fn -> Application.delete_env(:zone_server, :exp_bonus_attacker) end)

    player = player_state(1, "prontera", 100)
    owned_mob = %{MobState.configure_summon(mob_state(), owner_player_id: 1) | instance_id: 20}
    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    UnitRegistry.register_unit(:mob, 20, MobState, owned_mob, self())

    victim = MobState.add_typed_aggro(mob_state(), {:mob, 20}, 1, 100)
    UnitRegistry.unregister_unit(:mob, 20)

    assert %LootOwnership{first: 1} = LootOwnership.determine_typed(victim)

    PubSub.subscribe(Aesir.PubSub, "player:1")
    expect(LevelPenalty, :exp, fn 100, 50 -> 50 end)

    KillExp.distribute_typed(
      MobState.typed_damage_log(victim),
      100,
      50,
      100,
      "prontera",
      :brute
    )

    assert_receive {:progression, {:mob_kill_exp, 50, 25, :brute, _mob_class}}
  end

  test "a Homunculus lethal hit broadcasts ordinary root-owned loot with its exact final source" do
    player = player_state(1, "prontera", 100)
    homunculus = homunculus_state(20, 1, "prontera", 100)
    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    UnitRegistry.register_unit(:homunculus, 20, HomunculusState, homunculus, self())
    PubSub.subscribe(Aesir.PubSub, "player:1")
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Coordinator, :mob_died, fn _map, _gid, _owner_id -> :ok end)

    assert {:noreply, %{is_dead: true}} =
             CombatHandler.handle_apply_damage(1, {:homunculus, 20}, reward_mob_state())

    assert_receive {:loot,
                    {:mob_killed,
                     %{
                       ownership: %LootOwnership{first: 1},
                       final_source: {:homunculus, 20}
                     }}}
  end

  test "the owner writer validates exact active gid and map before persisting companion EXP" do
    player = player_state(1, "prontera", 100)
    homunculus = homunculus_state(20, 1, "prontera", 100)
    session = %SessionState{game_state: player, connection_pid: self(), homunculus: homunculus}

    expect(ProgressionHandler, :gain_exp, fn ^homunculus, 10 ->
      {:ok, %{homunculus | exp: homunculus.exp + 10}}
    end)

    assert {:noreply, progressed} = CommandHandler.cast({:gain_exp, 20, 10, "prontera"}, session)
    assert progressed.homunculus.exp == homunculus.exp + 10

    assert {:noreply, ^progressed} =
             CommandHandler.cast({:gain_exp, 21, 10, "prontera"}, progressed)
  end

  test "inactive Homunculus damage grants neither owner nor companion EXP" do
    player = player_state(1, "prontera", 100)
    homunculus = %{homunculus_state(20, 1, "prontera", 100) | lifecycle: :rested}
    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    UnitRegistry.register_unit(:homunculus, 20, HomunculusState, homunculus, self())
    PubSub.subscribe(Aesir.PubSub, "player:1")

    KillExp.distribute_typed(
      [entry({:homunculus, 20}, 1, 100, 0)],
      100,
      50,
      100,
      "prontera",
      :brute
    )

    refute_receive {:progression, _grant}, 50
    refute_receive {:"$gen_cast", _event}, 50
  end

  test "persistence failure leaves the Homunculus reward state unchanged" do
    player = player_state(1, "prontera", 100)
    homunculus = homunculus_state(20, 1, "prontera", 100)
    session = %SessionState{game_state: player, connection_pid: self(), homunculus: homunculus}
    expect(ProgressionHandler, :gain_exp, fn ^homunculus, 10 -> {:error, :database_down} end)

    assert {:noreply, ^session} =
             CommandHandler.cast({:gain_exp, 20, 10, "prontera"}, session)
  end

  defp reward_mob_state do
    mob_data = %MobDefinition{
      id: 1001,
      aegis_name: "test_mob",
      name: "Test Mob",
      level: 25,
      base_exp: 100,
      job_exp: 50,
      drops: [],
      hp: 1,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      atk: 1,
      matk: 1,
      def: 0,
      mdef: 0,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn = %MobSpawn{
      mob: 1001,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    %{MobState.new(1, mob_data, spawn, "prontera", 100, 100) | no_exp: true}
  end

  defp mob_state do
    %MobState{
      instance_id: 1,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 0,
      y: 0,
      map_name: "prontera",
      hp: 1,
      max_hp: 1,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  defp player_state(id, map, hp) do
    character = %Character{
      id: id,
      account_id: id,
      name: "Owner#{id}",
      last_map: map,
      last_x: 50,
      last_y: 50,
      class: 5,
      base_level: 50,
      job_level: 50,
      hp: hp,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      sex: "M"
    }

    PlayerState.new(character)
  end

  defp homunculus_state(gid, owner_id, map, hp) do
    %HomunculusState{
      id: gid + 1_000,
      owner_character_id: owner_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      action_state: :idle,
      hp: hp,
      max_hp: 100,
      world_gid: gid,
      owner_session_pid: self(),
      map_name: map,
      x: 50,
      y: 50
    }
  end

  defp entry({source_type, _id} = contributor, owner_id, damage, order) do
    %{
      contributor: contributor,
      source_type: source_type,
      reward_owner_id: owner_id,
      damage: damage,
      first_hit_order: order
    }
  end
end
