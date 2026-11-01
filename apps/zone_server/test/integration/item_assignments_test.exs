defmodule Aesir.ZoneServer.Integration.ItemAssignmentsTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.ParamChange
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @item 12399
  @box 12397

  setup do
    script = """
    .@grant += 1000000;
    Zeny += .@grant;
    if (Zeny < 2147000000) end;
    Zeny = 7;
    """

    {:ok, item} = Items.by_id(@item)
    {:ok, source} = Transpiler.transpile(script)
    {:ok, box} = Items.by_id(@box)

    {:ok, box_source} =
      Transpiler.transpile("""
      .@roll = Zeny;
      if (.@roll == 5) end;
      else if (.@roll == 6) getitem 909,1;
      else specialeffect2 EF_MVP;
      """)

    fixtures = %{@item => %{item | on_use: source}, @box => %{box | on_use: box_source}}
    Mimic.copy(Items)

    stub(Items, :by_id, fn id ->
      case Map.fetch(fixtures, id) do
        {:ok, item} -> {:ok, item}
        :error -> call_original(Items, :by_id, [id])
      end
    end)

    ScriptCompiler.compile_all!(Map.values(fixtures))
    on_exit(fn -> ScriptCompiler.compile_all!() end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "item ingress commits ordered assignments and consumes an item even when its parameter write ends the script" do
    character = character()
    {:ok, row} = Persistence.insert_item(character.id, %{nameid: @item, amount: 3, identify: 1})
    session = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)

    for {expected_zeny, expected_amount} <- [{1_501_000_000, 2}, {1_502_000_000, 1}] do
      use_item(session.pid, row.id)
      player = get_player_state(session.pid)
      assert player.zeny == expected_zeny
      assert [%{amount: ^expected_amount}] = Map.values(player.inventory)

      assert %ParamChange{var_id: 20, value: ^expected_zeny} = assert_packet_sent(ParamChange)
      assert_eventually(fn -> Repo.get!(Character, character.id).zeny == expected_zeny end)
    end

    assert {:ok, _} = PlayerSession.script_apply(session.pid, {:set_zeny, 2_147_483_647})
    flush_packets()
    use_item(session.pid, row.id)

    assert get_player_state(session.pid).zeny == 2_147_483_647
    assert get_player_state(session.pid).inventory == %{}
    assert Persistence.load_inventory(character.id) == []
    assert_eventually(fn -> Repo.get!(Character, character.id).zeny == 2_147_483_647 end)
    refute_received {:send, :gameplay, {:param_change, %ParamChange{var_id: 20}}}
  end

  test "non-skill branches of a delayed choice item retain the box and commit grants" do
    character = character()
    {:ok, row} = Persistence.insert_item(character.id, %{nameid: @box, amount: 1, identify: 1})
    session = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)

    for choice <- [5, 6, 7] do
      assert {:ok, _} = PlayerSession.script_apply(session.pid, {:set_zeny, choice})
      use_item(session.pid, row.id)

      assert Enum.any?(get_player_state(session.pid).inventory, fn {_index, item} ->
               item.id == row.id and item.amount == 1
             end)

      refute_received {:send, :gameplay, {:item_removed, %ItemRemoved{}}}
      assert PlayerSession.get_state(session.pid).pending_item_skill == nil
    end

    assert Enum.any?(
             Persistence.load_inventory(character.id),
             &(&1.nameid == 909 and &1.amount == 1)
           )
  end

  defp use_item(pid, row_id) do
    {index, _item} =
      Enum.find(get_player_state(pid).inventory, fn {_, item} -> item.id == row_id end)

    flush_packets()
    simulate_incoming_message(pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(pid)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "assign#{unique}",
        user_pass: "password",
        email: "assign#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Assign#{unique}",
      class: 0,
      base_level: 50,
      job_level: 1,
      hp: 100,
      sp: 100,
      zeny: 1_500_000_000,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
