defmodule Aesir.ZoneServer.Integration.InteractiveTeleportItemsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MapMove
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @moduletag :capture_log

  setup do
    if GameMode.mode() == :renewal do
      Mimic.copy(Items)

      fixtures =
        Map.new(
          [
            {14527, ~s|callfunc "F_CashDungeon",1;|},
            {14582, ~s|callfunc "F_CashCity",1;|},
            {12977, ~s|callfunc "F_CashTele",1;|}
          ],
          fn {id, script} ->
            {:ok, item} = Items.by_id(id)
            {:ok, source} = Transpiler.transpile(script)
            {id, %{item | on_use: source}}
          end
        )

      stub(Items, :by_id, fn id ->
        case Map.fetch(fixtures, id) do
          {:ok, item} -> {:ok, item}
          :error -> call_original(Items, :by_id, [id])
        end
      end)

      ScriptCompiler.compile_all!(Enum.map(Items.all(), &Map.get(fixtures, &1.id, &1)))
    else
      ScriptCompiler.compile_all!()
    end

    on_exit(fn -> ScriptCompiler.compile_all!() end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "consumption precedes a responsive menu and logical selection warps the owning session" do
    start_per_test_map("ein_dun01")
    character = character()
    insert_item(character.id, 14527, 1)
    insert_item(character.id, 12977, 1)
    session = start_player_session(character: character)
    on_exit(fn -> stop_session(session) end)
    flush_packets()

    use_item(session, 14527)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    dialog = assert_packet_sent(NpcDialog)
    assert dialog.expect == :MENU
    refute "" in dialog.options
    assert amount(session, 14527) == 0
    assert Enum.all?(Persistence.load_inventory(character.id), &(&1.nameid != 14527))
    assert get_player_state(session.pid).map_name == "prontera"

    choice = if GameMode.mode() == :renewal, do: 3, else: 4
    assert Enum.at(dialog.options, choice - 1) == "Einbroch Mine Dungeon"
    reply(session, dialog.npc_id, {:choice, choice})
    assert %MapMove{map_name: "ein_dun01", x: 261, y: 262} = assert_packet_sent(MapMove)

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)
      state.interaction_lock == nil and state.game_state.map_name == "ein_dun01"
    end)

    assert get_player_state(session.pid).temp_vars["menu"] == 4
    simulate_incoming_message(session.pid, %MapLoaded{})
    flush_packets()
    use_item(session, 12977)
    save_dialog = assert_packet_sent(NpcDialog)
    assert save_dialog.npc_id != dialog.npc_id
    reply(session, save_dialog.npc_id, {:choice, 5})
    assert %MapMove{map_name: "prontera", x: 160, y: 170} = assert_packet_sent(MapMove)
    assert Persistence.load_inventory(character.id) == []
  end

  test "overlap spends nothing, ordinary potions keep mode rules and cancelled gids cannot answer a new menu" do
    character = character()
    insert_item(character.id, 14582, 3)
    insert_item(character.id, 12977, 1)
    insert_item(character.id, 501, 1)
    session = start_player_session(character: character)
    on_exit(fn -> stop_session(session) end)
    flush_packets()
    use_item(session, 14582)
    first = assert_packet_sent(NpcDialog)
    {interaction, _, _} = PlayerSession.get_state(session.pid).interaction_lock

    flush_packets()
    use_item(session, 12977)
    assert %ItemUseResult{ok: false, reason: 4} = assert_packet_sent(ItemUseResult)
    assert amount(session, 12977) == 1
    assert {^interaction, _, _} = PlayerSession.get_state(session.pid).interaction_lock

    flush_packets()
    use_item(session, 501)
    result = assert_packet_sent(ItemUseResult)

    if GameMode.mode() == :pre_renewal do
      assert result.ok
      assert amount(session, 501) == 0
      assert get_player_state(session.pid).stats.current_state.hp > 1
    else
      refute result.ok
      assert amount(session, 501) == 1
    end

    reply(session, first.npc_id, {:cancel, true})
    assert_eventually(fn -> PlayerSession.get_state(session.pid).interaction_lock == nil end)
    assert amount(session, 14582) == 2
    refute Process.alive?(interaction)
    flush_packets()

    use_item(session, 14582)
    second = assert_packet_sent(NpcDialog)
    assert second.npc_id != first.npc_id
    reply(session, first.npc_id, {:choice, 1})
    assert collect_packets_of_type(MapMove) == []
    assert get_player_state(session.pid).x == 150
    reply(session, second.npc_id, {:cancel, true})
    assert_eventually(fn -> PlayerSession.get_state(session.pid).interaction_lock == nil end)
    assert amount(session, 14582) == 1

    use_item(session, 14582)
    assert_packet_sent(NpcDialog)
    {waiting, _, _} = PlayerSession.get_state(session.pid).interaction_lock
    ref = Process.monitor(waiting)
    stop_session(session)
    assert_receive {:DOWN, ^ref, :process, ^waiting, :normal}, 1_000
    assert Enum.all?(Persistence.load_inventory(character.id), &(&1.nameid != 14582))
  end

  test "a failed save-point warp still spends the item and releases the interaction" do
    character = character("not_a_map")
    insert_item(character.id, 12977, 1)
    session = start_player_session(character: character)
    on_exit(fn -> stop_session(session) end)
    flush_packets()
    use_item(session, 12977)
    dialog = assert_packet_sent(NpcDialog)
    reply(session, dialog.npc_id, {:choice, 5})
    assert_eventually(fn -> PlayerSession.get_state(session.pid).interaction_lock == nil end)
    assert get_player_state(session.pid).map_name == "prontera"
    assert amount(session, 12977) == 0
    assert Persistence.load_inventory(character.id) == []
    assert collect_packets_of_type(MapMove) == []
  end

  defp reply(session, gid, response) do
    simulate_incoming_message(session.pid, %NpcInteract{npc_id: gid, response: response})
    PlayerSession.get_state(session.pid)
  end

  defp use_item(session, nameid) do
    {index, _item} =
      Enum.find(get_player_state(session.pid).inventory, fn {_, item} -> item.nameid == nameid end)

    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(session.pid)
  end

  defp amount(session, nameid) do
    session.pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Enum.reduce(0, fn
      {_, %{nameid: ^nameid, amount: amount}}, total -> total + amount
      _, total -> total
    end)
  end

  defp insert_item(char_id, nameid, amount) do
    {:ok, _} = Persistence.insert_item(char_id, %{nameid: nameid, amount: amount, identify: 1})
  end

  defp stop_session(session) do
    if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal)
  end

  defp character(save_map \\ "prontera") do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "tele#{unique}",
        user_pass: "password",
        email: "tele#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Tele#{unique}",
      class: 0,
      base_level: 50,
      job_level: 1,
      hp: 1,
      sp: 1,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: save_map,
      save_x: 160,
      save_y: 170
    })
    |> Repo.insert!()
  end
end
