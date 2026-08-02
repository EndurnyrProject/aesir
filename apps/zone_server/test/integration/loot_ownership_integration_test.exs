defmodule Aesir.ZoneServer.Integration.LootOwnershipIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.PickupResult
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapManager
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Phoenix.PubSub

  @map "prontera"
  @potion 501
  @normal_windows {100, 60, 40}
  @boss_windows {170, 90, 50}

  setup do
    {:ok, _coordinator} = ensure_coordinator(@map)
    previous = override_loot_config()

    on_exit(fn ->
      restore_loot_config(previous)
      ClusterTestHelper.clear_all()
    end)

    :ok
  end

  test "kill stamps protection, denies a bystander, and becomes public after all windows" do
    owner = start_looter("Owner")
    bystander = start_looter("Bystander")

    ground_id = kill_and_get_drop(owner, %LootOwnership{first: owner.character.id})
    flush_packets()

    pick_up(bystander, ground_id)

    assert_receive {:packet_sent, %PickupResult{ground_id: ^ground_id, result: :LOOT_PROTECTED},
                    _},
                   1_000

    assert {:ok, %GroundItem{owners: {owner_id, nil, nil}}} =
             GroundItemStore.get(@map, ground_id)

    assert owner_id == owner.character.id

    Process.sleep(total_window(@normal_windows) + 60)
    pick_up(bystander, ground_id)

    assert_receive {:packet_sent, %ItemAdded{nameid: @potion}, _}, 1_000
    assert_receive {:packet_sent, %PickupResult{ground_id: ^ground_id, result: :OK}, _}, 1_000
    assert {:error, :gone} = GroundItemStore.get(@map, ground_id)
  end

  test "second owner unlocks after the first phase" do
    first = start_looter("First")
    second = start_looter("Second")

    ground_id =
      drop_owned(%LootOwnership{first: first.character.id, second: second.character.id})

    flush_packets()
    pick_up(second, ground_id)

    assert_receive {:packet_sent, %PickupResult{ground_id: ^ground_id, result: :LOOT_PROTECTED},
                    _},
                   1_000

    Process.sleep(elem(@normal_windows, 0) + 60)
    pick_up(second, ground_id)

    assert_receive {:packet_sent, %PickupResult{ground_id: ^ground_id, result: :OK}, _}, 1_000
    assert {:error, :gone} = GroundItemStore.get(@map, ground_id)
  end

  test "the first-attack bonus keeps a moderately out-damaged tagger first" do
    first = start_looter("Tagger")
    later = start_looter("Later")

    mob_state = %MobState{
      instance_id: 1,
      mob_id: 1002,
      mob_data: nil,
      spawn_ref: nil,
      x: 150,
      y: 150,
      map_name: @map,
      hp: 0,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0,
      aggro_list: %{first.character.id => 40, later.character.id => 60},
      aggro_order: [later.character.id, first.character.id]
    }

    ownership = LootOwnership.determine(mob_state)
    assert ownership == %LootOwnership{first: first.character.id, second: later.character.id}

    ground_id = kill_and_get_drop(first, ownership)

    assert {:ok, %GroundItem{owners: {first_id, second_id, nil}}} =
             GroundItemStore.get(@map, ground_id)

    assert first_id == first.character.id
    assert second_id == later.character.id
  end

  test "boss kills stamp the configured MVP windows" do
    owner = start_looter("BossKiller")
    ground_id = kill_and_get_drop(owner, %LootOwnership{first: owner.character.id}, boss?: true)

    assert {:ok, %GroundItem{dropped_at: dropped_at, unlock_at: {t1, t2, t3}}} =
             GroundItemStore.get(@map, ground_id)

    assert (t1 - dropped_at) in (elem(@boss_windows, 0) - 10)..elem(@boss_windows, 0)

    assert {t2 - t1, t3 - t2} ==
             {elem(@boss_windows, 1), elem(@boss_windows, 2)}

    assert elem(@boss_windows, 0) > elem(@normal_windows, 0)
  end

  test "party pickup-share grants and revokes the first owner's phase" do
    leader_character = character_fixture("Leader")
    member_character = character_fixture("Member")

    {:ok, party} = PartyManager.create("Looters#{leader_character.id}", leader_character)
    {:ok, party} = PartyManager.add_member(party.party_id, member_character)

    leader = start_looter(Repo.get!(Character, leader_character.id))
    member = start_looter(Repo.get!(Character, member_character.id))

    assert {:ok, enabled} =
             PartyManager.set_options(party.party_id, leader.character.id, false, true)

    assert enabled.item_pickup_share

    shared_id = kill_and_get_drop(leader, %LootOwnership{first: leader.character.id})
    flush_packets()
    pick_up(member, shared_id)

    assert_receive {:packet_sent, %PickupResult{ground_id: ^shared_id, result: :OK}, _}, 1_000

    assert {:ok, disabled} =
             PartyManager.set_options(party.party_id, leader.character.id, false, false)

    refute disabled.item_pickup_share

    protected_id = kill_and_get_drop(leader, %LootOwnership{first: leader.character.id})
    flush_packets()
    pick_up(member, protected_id)

    assert_receive {:packet_sent,
                    %PickupResult{ground_id: ^protected_id, result: :LOOT_PROTECTED}, _},
                   1_000

    assert {:ok, %GroundItem{}} = GroundItemStore.get(@map, protected_id)
  end

  test "Greed collects public loot and leaves a neighbor's protected loot" do
    owner = start_looter("Neighbor")
    smith = start_looter(character_fixture("Smith", class: 10, learned_skills: %{"1013" => 1}))

    protected_id = drop_owned(%LootOwnership{first: owner.character.id}, {151, 150})
    flush_packets()
    public_id = drop_public({149, 150})
    flush_packets()

    simulate_incoming_message(smith.pid, %SkillCast{
      skill_id: 1013,
      level: 1,
      target_id: smith.character.id
    })

    assert_receive {:packet_sent, %ItemAdded{nameid: @potion}, _}, 1_000
    assert {:ok, %GroundItem{}} = GroundItemStore.get(@map, protected_id)
    assert {:error, :gone} = GroundItemStore.get(@map, public_id)
  end

  defp kill_and_get_drop(player, ownership, opts \\ []) do
    payload = %{
      mob_id: 1002,
      drops: [%MobDrop{item: "Red_Potion", rate: 10_000}],
      mob_level: player.character.base_level,
      map: @map,
      x: 150,
      y: 150,
      ownership: ownership,
      boss?: Keyword.get(opts, :boss?, false)
    }

    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{player.character.id}",
      {:loot, {:mob_killed, payload}}
    )

    assert_receive {:packet_sent, %ItemOnGround{nameid: @potion, ground_id: ground_id}, _}, 1_000
    ground_id
  end

  defp drop_owned(ownership, position \\ {150, 150}) do
    {x, y} = position

    Coordinator.drop_items(
      @map,
      [{@potion, 1, x, y, true}],
      x,
      y,
      ownership: {ownership, false}
    )

    assert_receive {:packet_sent, %ItemOnGround{nameid: @potion, ground_id: ground_id}, _}, 1_000
    ground_id
  end

  defp drop_public({x, y}) do
    Coordinator.drop_items(@map, [{@potion, 1, x, y, true}], x, y)
    assert_receive {:packet_sent, %ItemOnGround{nameid: @potion, ground_id: ground_id}, _}, 1_000
    ground_id
  end

  defp pick_up(player, ground_id) do
    simulate_incoming_message(player.pid, %PickupItemRequest{ground_id: ground_id})
  end

  defp start_looter(%Character{} = character) do
    session =
      start_player_session(character: character, map_name: @map, position: {150, 150})

    on_exit(fn -> end_player_session(session) end)
    flush_packets()
    session
  end

  defp start_looter(name), do: name |> character_fixture() |> start_looter()

  defp character_fixture(prefix, attrs \\ []) do
    unique = System.unique_integer([:positive])
    userid = "loot#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    character_attrs = %{
      account_id: account.id,
      char_num: 0,
      name: "#{prefix}#{unique}",
      class: Keyword.get(attrs, :class, 0),
      base_level: 50,
      job_level: 50,
      hp: 500,
      max_hp: 500,
      sp: 500,
      max_sp: 500,
      learned_skills: Keyword.get(attrs, :learned_skills, %{}),
      last_map: @map,
      last_x: 150,
      last_y: 150,
      save_map: @map,
      save_x: 150,
      save_y: 150
    }

    {:ok, character} = character_attrs |> Character.new() |> Repo.insert()
    character
  end

  defp override_loot_config do
    overrides = [
      item_first_get_time: elem(@normal_windows, 0),
      item_second_get_time: elem(@normal_windows, 1),
      item_third_get_time: elem(@normal_windows, 2),
      mvp_item_first_get_time: elem(@boss_windows, 0),
      mvp_item_second_get_time: elem(@boss_windows, 1),
      mvp_item_third_get_time: elem(@boss_windows, 2),
      first_attack_loot_bonus: 30
    ]

    Enum.map(overrides, fn {key, value} ->
      previous = Application.get_env(:zone_server, key)
      Application.put_env(:zone_server, key, value)
      {key, previous}
    end)
  end

  defp restore_loot_config(previous) do
    Enum.each(previous, fn
      {key, nil} -> Application.delete_env(:zone_server, key)
      {key, value} -> Application.put_env(:zone_server, key, value)
    end)
  end

  defp total_window({first, second, third}), do: first + second + third

  defp ensure_coordinator(map_name), do: ensure_coordinator(map_name, 40)

  defp ensure_coordinator(map_name, 0), do: MapManager.get_coordinator(map_name)

  defp ensure_coordinator(map_name, retries) do
    case MapManager.get_coordinator(map_name) do
      {:ok, pid} ->
        {:ok, pid}

      _error ->
        Process.sleep(50)
        ensure_coordinator(map_name, retries - 1)
    end
  end
end
