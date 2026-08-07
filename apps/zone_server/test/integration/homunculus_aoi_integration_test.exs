defmodule Aesir.ZoneServer.Integration.HomunculusAoiIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Homunculus

  alias Aesir.Net.CastCancel
  alias Aesir.Net.ChatMessage
  alias Aesir.Net.DamageDealt
  alias Aesir.Net.Emotion
  alias Aesir.Net.EstimationResult
  alias Aesir.Net.GroundSkill
  alias Aesir.Net.HomunculusAttackCommand
  alias Aesir.Net.HomunculusCastSkillCommand
  alias Aesir.Net.HomunculusMoveCommand
  alias Aesir.Net.HomunculusPrivateState
  alias Aesir.Net.HomunculusRenameCommand
  alias Aesir.Net.HomunculusRequest
  alias Aesir.Net.HomunculusRestCommand
  alias Aesir.Net.HomunculusResult
  alias Aesir.Net.Knockback
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.MoveStop
  alias Aesir.Net.NameResponse
  alias Aesir.Net.Resurrect
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.Snapshot, as: NetSnapshot
  alias Aesir.Net.SpecialEffect
  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.Net.SpriteChange
  alias Aesir.Net.StatusChange
  alias Aesir.Net.UnitDespawn
  alias Aesir.Net.UnitHp
  alias Aesir.Net.UnitSpawn
  alias Aesir.Net.UnitStateChange
  alias Aesir.Net.UseItem
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown

  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "hom_aoi_e2e"
  @warp_map "hom_aoi_warp_e2e"
  @stone 12_040
  @seed 7_140

  setup do
    put_map(@map)
    put_map(@warp_map)
    start_per_test_map(@map)
    start_per_test_map(@warp_map)

    :ok
  end

  test "a real moving observer gets spawn before deltas and despawn after leaving, never private packets" do
    owner = owner_session()
    hom = PlayerSession.get_state(owner.pid).homunculus
    observer = observer_session(:moving, {hom.x + 21, hom.y})
    simulate_incoming_message(observer.pid, %MapLoaded{})
    flush_observer(:moving)

    simulate_incoming_message(observer.pid, %MoveRequest{dest_x: hom.x + 20, dest_y: hom.y})

    gid = hom.world_gid

    spawn_packets =
      collect_observer_packets_until(:moving, fn packet ->
        match?(%UnitSpawn{gid: ^gid}, packet)
      end)

    assert %UnitSpawn{gid: ^gid} = List.last(spawn_packets)
    refute Enum.any?(Enum.drop(spawn_packets, -1), &hom_delta_mentions?(&1, gid))

    request(owner.pid, 1, {
      :cast_skill,
      %HomunculusCastSkillCommand{skill_id: 8_002, level: 1, target: {:self, true}}
    })

    assert_receive {:packet_sent, %HomunculusResult{request_id: 1, success: true}, _}, 1_000

    request(owner.pid, 2, {:move, %HomunculusMoveCommand{x: hom.x + 1, y: hom.y}})
    assert_receive {:packet_sent, %HomunculusResult{request_id: 2, success: true}, _}, 1_000

    delta_packets =
      collect_observer_packets_until(:moving, fn packet ->
        snapshot_mentions_hom?(packet, gid)
      end)

    assert Enum.any?(delta_packets, &status_mentions_hom?(&1, gid))
    assert snapshot_mentions_hom?(List.last(delta_packets), gid)

    moved = eventually_hom(owner.pid, &(&1.x == hom.x + 1))
    refute_observer_private(:moving)

    simulate_incoming_message(observer.pid, %MoveRequest{dest_x: moved.x + 21, dest_y: moved.y})
    assert_receive {:observer_packet, :moving, %UnitDespawn{gid: ^gid}, _}, 2_000
    refute_observer_private(:moving)
  end

  test "a stationary observer crossed by the Homunculus sees spawn before movement and combat" do
    owner = owner_session()
    hom = PlayerSession.get_state(owner.pid).homunculus
    observer = observer_session(:stationary, {hom.x + 22, hom.y})
    simulate_incoming_message(observer.pid, %MapLoaded{})
    flush_observer(:stationary)

    request(owner.pid, 10, {:move, %HomunculusMoveCommand{x: hom.x + 3, y: hom.y}})
    assert_receive {:packet_sent, %HomunculusResult{request_id: 10, success: true}, _}, 1_000
    eventually_hom(owner.pid, &(&1.x == hom.x + 3))
    gid = hom.world_gid

    assert_receive {:observer_packet, :stationary, %UnitSpawn{gid: ^gid, moving: true}, _},
                   2_000

    moved = eventually_hom(owner.pid, &(&1.x == hom.x + 3))

    mob =
      start_mob_session(
        map_name: @map,
        position: {moved.x + 1, moved.y},
        hp: 5_000,
        max_hp: 5_000,
        awake: false
      )

    request(owner.pid, 11, {:attack, %HomunculusAttackCommand{target_id: mob.unit_id}})
    assert_receive {:packet_sent, %HomunculusResult{request_id: 11, success: true}, _}, 1_000

    assert_receive {:observer_packet, :stationary,
                    %DamageDealt{src_id: ^gid, target_id: target_id}, _},
                   2_000

    assert target_id == mob.unit_id
    refute_observer_private(:stationary)
  end

  test "a pending range entry receives one evolved spawn after a Stone evolution" do
    owner = owner_session(stone?: true, intimacy_hundredths: 91_100)
    hom = PlayerSession.get_state(owner.pid).homunculus
    observer = observer_session(:pending_evolution, {hom.x + 22, hom.y})
    observer_id = PlayerSession.get_state(observer.pid).game_state.character_id
    stone_index = inventory_client_index(owner.pid, @stone)
    gid = hom.world_gid

    simulate_incoming_message(observer.pid, %MapLoaded{})
    flush_observer(:pending_evolution)

    true = :erlang.suspend_process(observer.pid)
    on_exit(fn -> resume_if_suspended(observer.pid) end)

    try do
      request(owner.pid, 12, {:move, %HomunculusMoveCommand{x: hom.x + 3, y: hom.y}})
      assert_receive {:packet_sent, %HomunculusResult{request_id: 12, success: true}, _}, 1_000
      eventually_hom(owner.pid, &(&1.x == hom.x + 3))

      assert {:ok, {_module, pending_state, _pid}} = UnitRegistry.get_unit(:player, observer_id)
      refute MapSet.member?(pending_state.visible_homunculi, gid)

      assert {:messages, messages} = Process.info(observer.pid, :messages)

      assert Enum.member?(
               messages,
               {:"$gen_cast", {:visibility, {:homunculus_entered_view, gid}}}
             )

      simulate_incoming_message(owner.pid, %UseItem{index: stone_index})
      eventually_hom(owner.pid, &(&1.class_id == 6_009))

      true = :erlang.resume_process(observer.pid)

      packets =
        collect_observer_packets_until(:pending_evolution, fn
          %UnitSpawn{gid: ^gid, job: 6_009} -> true
          _packet -> false
        end)

      assert [%UnitSpawn{gid: ^gid, job: 6_009}] =
               Enum.filter(packets, &hom_delta_mentions?(&1, gid))

      refute_receive {:observer_packet, :pending_evolution, %UnitDespawn{gid: ^gid}, _}, 100
      refute_receive {:observer_packet, :pending_evolution, %UnitSpawn{gid: ^gid}, _}, 100

      assert_eventually(fn ->
        MapSet.member?(PlayerSession.get_state(observer.pid).game_state.visible_homunculi, gid)
      end)
    after
      resume_if_suspended(observer.pid)
    end
  end

  test "rename, evolution, Rest, warp, and reconnect use ordered despawn and refreshed spawn" do
    owner = owner_session(stone?: true, intimacy_hundredths: 91_100)
    hom = PlayerSession.get_state(owner.pid).homunculus
    observer = observer_session(:lifecycle, {hom.x + 1, hom.y})
    simulate_incoming_message(observer.pid, %MapLoaded{})
    assert_receive {:observer_packet, :lifecycle, %UnitSpawn{gid: gid, name: "Lif"}, _}, 1_000
    flush_observer(:lifecycle)

    request(owner.pid, 20, {:rename, %HomunculusRenameCommand{name: "Eir"}})
    assert_receive {:packet_sent, %HomunculusResult{request_id: 20, success: true}, _}, 1_000
    assert_refresh(:lifecycle, gid, &(&1.name == "Eir"))

    stone_index = inventory_client_index(owner.pid, @stone)
    simulate_incoming_message(owner.pid, %UseItem{index: stone_index})

    evolution_packets =
      collect_observer_packets_until(:lifecycle, fn
        %UnitSpawn{gid: ^gid, job: 6_009} -> true
        _packet -> false
      end)

    assert [
             %UnitDespawn{gid: ^gid},
             %UnitSpawn{gid: ^gid, job: 6_009, max_hp: evolved_max_hp}
           ] = Enum.filter(evolution_packets, &hom_delta_mentions?(&1, gid))

    assert evolved_max_hp > hom.max_hp
    refute_observer_private(:lifecycle)

    :ok = DamageApplication.apply_heal(:homunculus, gid, 100_000, nil)

    assert_eventually(fn ->
      current = PlayerSession.get_state(owner.pid).homunculus
      current.hp == current.max_hp
    end)

    assert MapSet.member?(PlayerSession.get_state(observer.pid).game_state.visible_homunculi, gid)
    request(owner.pid, 21, {:rest, %HomunculusRestCommand{}})
    assert_receive {:packet_sent, %HomunculusResult{request_id: 21, success: true}, _}, 1_000
    assert_receive {:observer_packet, :lifecycle, %UnitDespawn{gid: ^gid}, _}, 1_000

    cast(owner.pid, 243, 1)
    recalled = eventually_hom(owner.pid, &(&1.lifecycle == :active))

    assert_receive {:observer_packet, :lifecycle, %UnitSpawn{gid: recalled_gid, job: 6_009}, _},
                   1_000

    assert recalled_gid == recalled.world_gid

    assert MapSet.member?(
             PlayerSession.get_state(observer.pid).game_state.visible_homunculi,
             recalled_gid
           )

    :ok = PlayerSession.disconnect(owner.pid)

    assert_receive {:observer_packet, :lifecycle, %UnitDespawn{gid: ^recalled_gid}, _}, 1_000

    assert_eventually(fn ->
      not MapSet.member?(
        PlayerSession.get_state(observer.pid).game_state.visible_homunculi,
        recalled_gid
      )
    end)

    reloaded = owner.character |> Repo.reload!() |> Repo.preload(:homunculus)
    returned = start_player_session(character: reloaded, map_name: @map, position: {50, 50})
    on_exit(fn -> if Process.alive?(returned.pid), do: end_player_session(returned) end)
    restored = eventually_hom(returned.pid, & &1)
    assert_receive {:observer_packet, :lifecycle, %UnitSpawn{gid: new_gid, job: 6_009}, _}, 1_000
    assert new_gid == restored.world_gid

    assert MapSet.member?(
             PlayerSession.get_state(observer.pid).game_state.visible_homunculi,
             new_gid
           )

    refute_receive {:observer_packet, :lifecycle, %UnitDespawn{gid: ^new_gid}, _}, 100
    refute_receive {:observer_packet, :lifecycle, %UnitSpawn{gid: ^new_gid}, _}, 100

    PlayerSession.warp(returned.pid, @warp_map, 40, 40)
    assert_receive {:observer_packet, :lifecycle, %UnitDespawn{gid: ^new_gid}, _}, 1_000

    destination_observer = observer_session(:destination, {41, 40}, @warp_map)
    simulate_incoming_message(destination_observer.pid, %MapLoaded{})
    flush_observer(:destination)
    simulate_incoming_message(returned.pid, %MapLoaded{})

    assert_eventually(fn ->
      PlayerSession.get_state(returned.pid).homunculus.map_name == @warp_map
    end)

    assert_receive {:observer_packet, :destination, %UnitSpawn{gid: ^new_gid}, _}, 1_000

    current = PlayerSession.get_state(returned.pid).homunculus

    assert :ok =
             DamageApplication.apply_unit_damage(
               :homunculus,
               returned.pid,
               current.world_gid,
               current.hp,
               %{skill_id: 0},
               nil
             )

    assert_receive {:observer_packet, :destination, %UnitDespawn{gid: ^new_gid}, _}, 1_000
    refute_observer_private(:lifecycle)
    refute_observer_private(:destination)
  end

  defp assert_refresh(label, gid, predicate) do
    assert_receive {:observer_packet, ^label, %UnitDespawn{gid: ^gid}, _}, 1_000
    assert_receive {:observer_packet, ^label, %UnitSpawn{gid: ^gid} = spawn, _}, 1_000
    assert predicate.(spawn)
  end

  defp owner_session(opts \\ []) do
    character = character_fixture("Owner")

    if Keyword.get(opts, :stone?, false) do
      for item_id <- [@stone, @seed] do
        {:ok, _} =
          InventoryPersistence.insert_item(character.id, %{
            nameid: item_id,
            amount: 1,
            identify: 1
          })
      end
    end

    insert_homunculus(character.id, opts)

    session =
      start_player_session(
        character: Repo.preload(character, :homunculus),
        map_name: @map,
        position: {50, 50}
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp observer_session(label, position, map_name \\ @map) do
    character = character_fixture(Atom.to_string(label), position, map_name)
    test_pid = self()
    connection = spawn_link(fn -> connection_loop(test_pid, label) end)

    session =
      start_player_session(
        character: character,
        connection_pid: connection,
        map_name: map_name,
        position: position
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp connection_loop(test_pid, label) do
    receive do
      {:send, channel, {_tag, packet}} ->
        send(test_pid, {:observer_packet, label, packet, channel})
        connection_loop(test_pid, label)

      :stop ->
        :ok

      _other ->
        connection_loop(test_pid, label)
    end
  end

  defp flush_observer(label) do
    receive do
      {:observer_packet, ^label, _, _} -> flush_observer(label)
    after
      50 -> :ok
    end
  end

  defp collect_observer_packets_until(label, predicate, timeout_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    collect_observer_packets_until(label, predicate, deadline, [])
  end

  defp collect_observer_packets_until(label, predicate, deadline, packets) do
    timeout_ms = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:observer_packet, ^label, packet, _channel} ->
        packets = [packet | packets]

        if predicate.(packet) do
          Enum.reverse(packets)
        else
          collect_observer_packets_until(label, predicate, deadline, packets)
        end
    after
      timeout_ms ->
        flunk("observer packet did not arrive before timeout")
    end
  end

  defp hom_delta_mentions?(%UnitSpawn{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%UnitDespawn{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%MoveStop{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%SpiritSphereUpdate{unit_id: gid}, gid), do: true
  defp hom_delta_mentions?(%StatusChange{unit_id: gid}, gid), do: true
  defp hom_delta_mentions?(%UnitStateChange{unit_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SpecialEffect{source_id: gid}, gid), do: true
  defp hom_delta_mentions?(%NameResponse{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%ChatMessage{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%Emotion{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%DamageDealt{src_id: gid}, gid), do: true
  defp hom_delta_mentions?(%DamageDealt{target_id: gid}, gid), do: true
  defp hom_delta_mentions?(%Knockback{unit_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SkillDamage{src_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SkillDamage{target_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SkillEffect{src_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SkillEffect{target_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SkillCasting{src_id: gid}, gid), do: true
  defp hom_delta_mentions?(%SkillCasting{target_id: gid}, gid), do: true
  defp hom_delta_mentions?(%CastCancel{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%GroundSkill{src_id: gid}, gid), do: true
  defp hom_delta_mentions?(%UnitHp{id: gid}, gid), do: true
  defp hom_delta_mentions?(%SpriteChange{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%Resurrect{gid: gid}, gid), do: true
  defp hom_delta_mentions?(%EstimationResult{target_id: gid}, gid), do: true
  defp hom_delta_mentions?(%VendingBoardShown{unit_id: gid}, gid), do: true
  defp hom_delta_mentions?(%VendingBoardRemoved{unit_id: gid}, gid), do: true
  defp hom_delta_mentions?(%NetSnapshot{} = packet, gid), do: snapshot_mentions_hom?(packet, gid)
  defp hom_delta_mentions?(_packet, _gid), do: false

  defp status_mentions_hom?(%StatusChange{unit_id: gid}, gid), do: true
  defp status_mentions_hom?(_packet, _gid), do: false

  defp snapshot_mentions_hom?(%NetSnapshot{entities: entities}, gid),
    do: Enum.any?(entities, &(&1.id == gid))

  defp snapshot_mentions_hom?(_packet, _gid), do: false

  defp refute_observer_private(label) do
    refute_receive {:observer_packet, ^label, %HomunculusPrivateState{}, _}, 100
    refute_receive {:observer_packet, ^label, %HomunculusResult{}, _}, 100
  end

  defp request(pid, id, command) do
    simulate_incoming_message(pid, %HomunculusRequest{request_id: id, command: command})
  end

  defp cast(pid, skill_id, level) do
    target_id = PlayerSession.get_state(pid).game_state.character_id

    simulate_incoming_message(pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })
  end

  defp eventually_hom(pid, predicate) do
    assert_eventually(fn ->
      case PlayerSession.get_state(pid).homunculus do
        nil -> false
        homunculus -> predicate.(homunculus)
      end
    end)

    PlayerSession.get_state(pid).homunculus
  end

  defp inventory_client_index(pid, item_id) do
    {server_index, _item} =
      Enum.find(PlayerSession.get_state(pid).game_state.inventory, fn {_index, item} ->
        item.nameid == item_id
      end)

    server_index + 2
  end

  defp character_fixture(prefix, position \\ {50, 50}, map_name \\ @map) do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "aoi#{suffix}",
        user_pass: "password",
        email: "aoi#{suffix}@example.com"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: String.slice("#{prefix}#{suffix}", 0, 24),
      class: 18,
      base_level: 50,
      job_level: 50,
      hp: 2_000,
      max_hp: 2_000,
      sp: 500,
      max_sp: 500,
      learned_skills: %{"238" => 1, "243" => 1, "244" => 1},
      last_map: map_name,
      last_x: elem(position, 0),
      last_y: elem(position, 1)
    })
    |> Repo.insert!()
  end

  defp insert_homunculus(character_id, opts) do
    %Homunculus{}
    |> Homunculus.changeset(%{
      character_id: character_id,
      class_id: 6_001,
      name: "Lif",
      lifecycle: "active",
      level: 50,
      hp: 1_000,
      max_hp: 1_000,
      sp: 300,
      max_sp: 300,
      intimacy_hundredths: Keyword.get(opts, :intimacy_hundredths, 75_100),
      active_remaining_ms: 1_800_000,
      learned_skills: %{"8001" => 3, "8002" => 1}
    })
    |> Repo.insert!()
  end

  defp resume_if_suspended(pid) do
    case Process.info(pid, :status) do
      {:status, :suspended} -> :erlang.resume_process(pid)
      _ -> :ok
    end
  end

  defp put_map(name) do
    :ets.insert(EtsTable.table_for(:map_cache), {name, MapData.new(name, 100, 100)})
  end
end
