defmodule Aesir.ZoneServer.Integration.FameIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.FameUpdate
  alias Aesir.Net.ProductionResult
  alias Aesir.Net.RankingRequest
  alias Aesir.Net.RankingResponse
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Fame.Store
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  test "production fame is private persisted queryable and loaded by a new session" do
    stub(Application, :get_env, fn
      :zone_server, :forge_rng, _default -> fn _upper -> 1 end
      app, key, default -> Mimic.call_original(Application, :get_env, [app, key, default])
    end)

    character = character(18)
    insert_items(character.id, [{7134, 3}, {7133, 1}, {501, 3}, {1092, 3}, {952, 3}])
    maker = start_session(character)
    Mimic.allow(Application, self(), maker.pid)

    test_pid = self()
    connection = spawn_link(fn -> observer_connection(test_pid) end)

    observer =
      start_player_session(
        character: character(0),
        connection_pid: connection,
        position: {151, 150}
      )

    on_exit(fn -> end_player_session(observer) end)
    flush_packets()

    for _ <- 1..3 do
      simulate_incoming_message(maker.pid, %SkillCast{
        skill_id: 228,
        level: 10,
        target_id: character.id
      })

      assert_receive {:packet_sent, %SkillMenu{src_skill_id: 228, entry_ids: entries}, _}, 1_000
      assert 545 in entries
      simulate_incoming_message(maker.pid, %SkillMenuReply{src_skill_id: 228, selected_id: 545})
      assert_receive {:packet_sent, %ProductionResult{success: true, item_id: 545}, _}, 1_000
    end

    assert_receive {:packet_sent,
                    %FameUpdate{category: :RANKING_ALCHEMIST, awarded_points: 1, total_fame: 1},
                    :gameplay}

    refute_receive {:observer_packet, %FameUpdate{}}
    assert Inventory.held_amount(get_player_state(maker.pid).inventory, 545) == 3
    assert get_player_state(maker.pid).potion_success_counter == 3
    assert get_player_state(maker.pid).pending_fame_awards == []

    simulate_incoming_message(maker.pid, %RankingRequest{category: :RANKING_ALCHEMIST})

    assert_receive {:packet_sent,
                    %RankingResponse{
                      category: :RANKING_ALCHEMIST,
                      result: :OK,
                      own_fame: 1,
                      entries: [entry]
                    }, :gameplay}

    assert entry.character_id == character.id
    assert entry.name == character.name
    assert entry.fame == 1
    refute_receive {:observer_packet, %RankingResponse{}}

    persisted = Repo.get!(Character, character.id)
    assert persisted.fame == 1
    assert persisted.fame_order > 0
    GenServer.stop(maker.pid, :normal)
    refute Process.alive?(maker.pid)
    restarted = start_session(persisted)

    assert %{fame: 1, potion_success_counter: 0, pending_fame_awards: []} =
             get_player_state(restarted.pid)
  end

  test "script refinement fame reaches the ranking through the real script boundary" do
    character = character(10)

    {:ok, item} =
      Persistence.insert_item(character.id, %{
        nameid: 1101,
        amount: 1,
        identify: 1,
        equip: 2,
        refine: 9,
        craft: ItemCraft.to_map(ItemCraft.forged(:neutral, 0, character.id))
      })

    maker = start_session(character)

    {index, _item} =
      Enum.find(get_player_state(maker.pid).inventory, fn {_index, held} -> held.id == item.id end)

    assert {:ok, _snapshot} =
             GenServer.call(maker.pid, {:npc, {:script_apply, {:successrefitem, index, 1101, 1}}})

    assert_receive {:packet_sent,
                    %FameUpdate{category: :RANKING_BLACKSMITH, awarded_points: 1, total_fame: 1},
                    :gameplay}

    assert get_player_state(maker.pid).inventory[index].refine == 10

    simulate_incoming_message(maker.pid, %RankingRequest{category: :RANKING_BLACKSMITH})

    assert_receive {:packet_sent, %RankingResponse{result: :OK, own_fame: 1, entries: [entry]},
                    :gameplay}

    assert entry.character_id == character.id
    assert entry.fame == 1
    assert Repo.get!(Character, character.id).fame == 1
  end

  test "ranking packet ingress rejects unknown categories and exposes storage errors" do
    session = start_session(character(18))

    for category <- [:RANKING_UNSPECIFIED, 999] do
      simulate_incoming_message(session.pid, %RankingRequest{category: category})

      assert_receive {:packet_sent,
                      %RankingResponse{
                        category: ^category,
                        result: :INVALID_CATEGORY,
                        entries: []
                      }, :gameplay}
    end

    stub(Store, :ranking, fn :alchemist -> {:error, :unavailable} end)
    Mimic.allow(Store, self(), session.pid)
    simulate_incoming_message(session.pid, %RankingRequest{category: :RANKING_ALCHEMIST})
    assert_receive {:packet_sent, %RankingResponse{result: :UNAVAILABLE, entries: []}, :gameplay}
    assert Process.alive?(session.pid)
  end

  defp start_session(character) do
    session = start_player_session(character: character, position: {150, 150})
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp insert_items(character_id, items) do
    Enum.each(items, fn {id, amount} ->
      assert {:ok, _item} =
               Persistence.insert_item(character_id, %{nameid: id, amount: amount, identify: 1})
    end)
  end

  defp character(class) do
    unique = System.unique_integer([:positive])

    account =
      Repo.insert!(%Account{
        userid: "fame#{unique}",
        user_pass: "unused",
        email: "fame@test.local"
      })

    Repo.insert!(%Character{
      account_id: account.id,
      char_num: 0,
      name: "Maker#{unique}",
      class: class,
      base_level: 99,
      job_level: 70,
      str: 99,
      int: 99,
      dex: 99,
      luk: 99,
      hp: 500,
      max_hp: 500,
      sp: 500,
      max_sp: 500,
      learned_skills: %{"228" => 10},
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
  end

  defp observer_connection(test_pid) do
    receive do
      {:send, _channel, {_tag, packet}} ->
        send(test_pid, {:observer_packet, packet})
        observer_connection(test_pid)

      :stop ->
        :ok
    end
  end
end
