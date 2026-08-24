defmodule Aesir.ZoneServer.Integration.GuildStorageIntegrationTest do
  @moduledoc """
  End-to-end guild storage coverage through live player sessions, guild runtime
  entries, cluster claims, persistence, scripts, and lifecycle producers.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.StorageCloseRequest
  alias Aesir.Net.StorageDepositRequest
  alias Aesir.Net.StorageOpened
  alias Aesir.Net.StorageResult
  alias Aesir.Net.StorageWithdrawRequest
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Guild.Storage.Persistence, as: GuildStoragePersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @npc_position {170, 160}
  @guild_storage_skill 10_016
  @newbie_position 19
  @potion 501
  @poring_card 4001
  @fabre_card 4002
  @pupa_card 4003
  @drops_card 4004
  @sword 1101

  defmodule GuildKafraNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 170, y: 160, dir: 0, sprite: 117, name: "Guild Kafra"}]

    @impl true
    def on_talk(ctx) do
      ctx |> guildopenstorage() |> close()
    end
  end

  setup do
    ClusterTestHelper.clear_all()
    on_exit(&ClusterTestHelper.clear_all/0)
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([GuildKafraNpc])
    :ok
  end

  test "one member holds the window exclusively until closing it" do
    %{guild_id: guild_id, master: member_a, members: [member_b]} =
      guild_fixture(skill_level: 1, member_count: 1, can_storage: true)

    {:ok, _row} =
      GuildStoragePersistence.insert_item(guild_id, %{nameid: @potion, amount: 7, identify: 1})

    session_a = start_session(member_a)
    session_b = start_session(member_b)

    open_guild_storage!(session_a.pid)

    before = PlayerSession.get_state(session_a.pid)
    before_container = before.game_state.guild_storage
    before_context = before.guild_storage_ctx

    request_guild_storage(session_b.pid)

    assert_receive {:packet_sent, %StorageResult{result: :STORAGE_GUILD_IN_USE}, _}, 1_000
    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    refute_received {:packet_sent, %StorageOpened{}, _}

    refused = PlayerSession.get_state(session_b.pid)
    assert refused.game_state.guild_storage == nil
    assert refused.guild_storage_ctx == nil

    unchanged = PlayerSession.get_state(session_a.pid)
    assert unchanged.game_state.guild_storage == before_container
    assert unchanged.guild_storage_ctx == before_context
    assert Lock.held_by?(guild_id, session_a.pid)

    simulate_incoming_message(session_a.pid, %StorageCloseRequest{kind: :STORAGE_KIND_GUILD})

    assert_eventually(fn ->
      PlayerSession.get_state(session_a.pid).game_state.guild_storage == nil and
        Lock.holder(guild_id) == :error
    end)

    opened = open_guild_storage!(session_b.pid)
    assert Enum.any?(opened.items, &(&1.nameid == @potion and &1.amount == 7))
    assert Lock.held_by?(guild_id, session_b.pid)
  end

  test "a holder session death frees the claim without a restart or manual release" do
    %{guild_id: guild_id, master: member_a, members: [member_b]} =
      guild_fixture(skill_level: 1, member_count: 1, can_storage: true)

    session_a = start_session(member_a)
    session_b = start_session(member_b)

    open_guild_storage!(session_a.pid)
    assert Lock.held_by?(guild_id, session_a.pid)

    Process.unlink(session_a.pid)
    monitor = Process.monitor(session_a.pid)
    Process.exit(session_a.pid, :kill)
    assert_receive {:DOWN, ^monitor, :process, _, :killed}, 1_000

    assert_eventually(fn -> Lock.holder(guild_id) == :error end)

    open_guild_storage!(session_b.pid)
    assert Lock.held_by?(guild_id, session_b.pid)
  end

  test "deposit and withdraw preserve every identity-bearing item attribute" do
    %{guild_id: guild_id, master: master} =
      guild_fixture(skill_level: 1, member_count: 0)

    craft = ItemCraft.to_map(ItemCraft.forged(:fire, 3, master.id))
    random_options = %{"1" => %{"val" => 5, "parm" => 0}}

    seed_inventory(master.id, %{
      nameid: @sword,
      amount: 1,
      identify: 1,
      refine: 7,
      card0: @poring_card,
      card1: @fabre_card,
      card2: @pupa_card,
      card3: @drops_card,
      random_options: random_options,
      bound: 2,
      unique_id: 123_456,
      craft: craft
    })

    session = start_session(master)
    open_guild_storage!(session.pid)

    inventory_index =
      client_index_of(PlayerSession.get_state(session.pid).game_state.inventory, @sword)

    simulate_incoming_message(session.pid, %StorageDepositRequest{
      kind: :STORAGE_KIND_GUILD,
      inventory_index: inventory_index,
      amount: 1
    })

    assert_receive {:packet_sent, %StorageResult{result: :STORAGE_OK}, _}, 1_000

    deposited = PlayerSession.get_state(session.pid).game_state
    assert_item_attributes(only_item(deposited.guild_storage, @sword), craft, random_options)

    simulate_incoming_message(session.pid, %StorageCloseRequest{kind: :STORAGE_KIND_GUILD})

    assert_eventually(fn ->
      PlayerSession.get_state(session.pid).game_state.guild_storage == nil and
        Lock.holder(guild_id) == :error
    end)

    open_guild_storage!(session.pid)
    rehydrated = PlayerSession.get_state(session.pid).game_state
    assert_item_attributes(only_item(rehydrated.guild_storage, @sword), craft, random_options)

    storage_index = client_index_of(rehydrated.guild_storage, @sword)

    simulate_incoming_message(session.pid, %StorageWithdrawRequest{
      kind: :STORAGE_KIND_GUILD,
      storage_index: storage_index,
      amount: 1
    })

    assert_receive {:packet_sent, %StorageResult{result: :STORAGE_OK}, _}, 1_000

    returned = PlayerSession.get_state(session.pid).game_state
    assert returned.guild_storage == %{}
    assert_item_attributes(only_item(returned.inventory, @sword), craft, random_options)

    assert [%InventoryItem{} = persisted] = InventoryPersistence.load_inventory(master.id)
    assert_item_attributes(persisted, craft, random_options)
    assert GuildStoragePersistence.load_storage(guild_id) == []
  end

  test "disband deletes the open container and the session cannot write it back" do
    %{guild_id: guild_id, master: master} =
      guild_fixture(skill_level: 1, member_count: 0)

    {:ok, _row} =
      GuildStoragePersistence.insert_item(guild_id, %{nameid: @potion, amount: 7, identify: 1})

    session = start_session(master)
    open_guild_storage!(session.pid)
    assert map_size(PlayerSession.get_state(session.pid).game_state.guild_storage) == 1

    assert :ok = GuildManager.disband(guild_id, "integration test")

    assert_eventually(fn ->
      state = PlayerSession.get_state(session.pid)

      state.game_state.guild_id == 0 and state.game_state.guild_storage == nil and
        state.guild_storage_ctx == nil and Lock.holder(guild_id) == :error and
        GuildStoragePersistence.load_storage(guild_id) == []
    end)

    simulate_incoming_message(session.pid, %StorageCloseRequest{kind: :STORAGE_KIND_GUILD})
    end_player_session(session)

    assert Repo.get(GuildModel, guild_id) == nil
    assert GuildStoragePersistence.load_storage(guild_id) == []
  end

  test "expulsion force-closes the member and frees the claim for another member" do
    %{guild_id: guild_id, master: master, members: [expelled, next_member]} =
      guild_fixture(skill_level: 1, member_count: 2, can_storage: true)

    expelled_session = start_session(expelled)
    next_session = start_session(next_member)
    open_guild_storage!(expelled_session.pid)

    assert {:ok, _state} =
             GuildManager.expel(guild_id, master.id, expelled.id, "integration test")

    assert_eventually(fn ->
      state = PlayerSession.get_state(expelled_session.pid)

      state.game_state.guild_id == 0 and state.game_state.guild_storage == nil and
        state.guild_storage_ctx == nil and Lock.holder(guild_id) == :error
    end)

    open_guild_storage!(next_session.pid)
    assert Lock.held_by?(guild_id, next_session.pid)
  end

  test "voluntary departure force-closes the member and frees the claim" do
    %{guild_id: guild_id, members: [departing, next_member]} =
      guild_fixture(skill_level: 1, member_count: 2, can_storage: true)

    departing_session = start_session(departing)
    next_session = start_session(next_member)
    open_guild_storage!(departing_session.pid)

    assert {:ok, _state} = GuildManager.remove_member(guild_id, departing.id)

    assert_eventually(fn ->
      state = PlayerSession.get_state(departing_session.pid)

      state.game_state.guild_id == 0 and state.game_state.guild_storage == nil and
        state.guild_storage_ctx == nil and Lock.holder(guild_id) == :error
    end)

    open_guild_storage!(next_session.pid)
    assert Lock.held_by?(guild_id, next_session.pid)
  end

  test "edit_position grants storage access to the same previously denied member" do
    %{guild_id: guild_id, master: master, members: [member]} =
      guild_fixture(skill_level: 1, member_count: 1)

    session = start_session(member)
    request_guild_storage(session.pid)

    assert_receive {:packet_sent, %StorageResult{result: :STORAGE_GUILD_NO_PERMISSION}, _},
                   1_000

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    refute_received {:packet_sent, %StorageOpened{}, _}
    assert PlayerSession.get_state(session.pid).game_state.guild_storage == nil
    assert Lock.holder(guild_id) == :error

    assert {:ok, _state} =
             GuildManager.edit_position(guild_id, master.id, %{
               index: @newbie_position,
               name: "Newbie",
               can_invite: false,
               can_expel: false,
               can_storage: true
             })

    open_guild_storage!(session.pid)
    assert Lock.held_by?(guild_id, session.pid)
  end

  test "an unlearned guild storage skill refuses even the guild master" do
    %{guild_id: guild_id, master: master} =
      guild_fixture(skill_level: 0, member_count: 0)

    session = start_session(master)
    request_guild_storage(session.pid)

    assert_receive {:packet_sent, %StorageResult{result: :STORAGE_GUILD_NO_SKILL}, _}, 1_000
    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    refute_received {:packet_sent, %StorageOpened{}, _}
    assert PlayerSession.get_state(session.pid).game_state.guild_storage == nil
    assert Lock.holder(guild_id) == :error
  end

  test "the opened capacity reflects the live guild storage skill level" do
    %{master: master} = guild_fixture(skill_level: 3, member_count: 0)
    session = start_session(master)

    assert %StorageOpened{capacity: 400} = open_guild_storage!(session.pid)
  end

  test "a cross-map warp closes the window and frees the claim" do
    {:ok, _coordinator} = start_per_test_map("izlude")

    %{guild_id: guild_id, master: holder, members: [next_member]} =
      guild_fixture(skill_level: 1, member_count: 1, can_storage: true)

    holder_session = start_session(holder)
    next_session = start_session(next_member)
    open_guild_storage!(holder_session.pid)

    PlayerSession.warp(holder_session.pid, "izlude", 100, 100)

    assert_eventually(fn ->
      state = PlayerSession.get_state(holder_session.pid)

      state.game_state.map_name == "izlude" and state.game_state.guild_storage == nil and
        state.guild_storage_ctx == nil and Lock.holder(guild_id) == :error
    end)

    open_guild_storage!(next_session.pid)
    assert Lock.held_by?(guild_id, next_session.pid)
  end

  defp guild_fixture(opts) do
    skill_level = Keyword.fetch!(opts, :skill_level)
    member_count = Keyword.get(opts, :member_count, 0)
    can_storage = Keyword.get(opts, :can_storage, false)

    master = character_fixture("M")
    name = "GS#{System.unique_integer([:positive])}"
    {:ok, guild} = GuildManager.create(name, master)

    members =
      if member_count > 0 do
        Enum.map(1..member_count, fn _index ->
          member = character_fixture("N")
          {:ok, _state} = GuildManager.add_member(guild.guild_id, member)
          member
        end)
      else
        []
      end

    if can_storage do
      {:ok, _state} =
        GuildManager.edit_position(guild.guild_id, master.id, %{
          index: @newbie_position,
          name: "Newbie",
          can_invite: false,
          can_expel: false,
          can_storage: true
        })
    end

    if skill_level > 0 do
      guild_model = Repo.get!(GuildModel, guild.guild_id)

      guild_model
      |> GuildModel.changeset(%{
        learned_skills: %{Integer.to_string(@guild_storage_skill) => skill_level}
      })
      |> Repo.update!()

      ClusterTestHelper.clear_all()
      {:ok, _state} = GuildManager.ensure_started(guild.guild_id)
    end

    %{
      guild_id: guild.guild_id,
      master: Repo.get!(Character, master.id),
      members: Enum.map(members, &Repo.get!(Character, &1.id))
    }
  end

  defp start_session(%Character{} = character) do
    session =
      start_player_session(character: character, map_name: @map, position: @npc_position)

    on_exit(fn ->
      if Process.alive?(session.pid), do: end_player_session(session)
    end)

    flush_packets()
    session
  end

  defp open_guild_storage!(pid) do
    request_guild_storage(pid)

    assert_receive {:packet_sent, %StorageOpened{kind: :STORAGE_KIND_GUILD} = opened, _},
                   1_000

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE}, _}, 1_000
    opened
  end

  defp request_guild_storage(pid) do
    {x, y} = @npc_position
    {:ok, {_module, placement}} = NpcRegistry.module_at(@map, x, y)
    simulate_incoming_message(pid, %NpcTalk{npc_id: NpcRegistry.entity_id(placement)})
  end

  defp seed_inventory(char_id, attrs) do
    {:ok, item} = InventoryPersistence.insert_item(char_id, attrs)
    item
  end

  defp client_index_of(container, nameid) do
    {server_index, _item} = Enum.find(container, fn {_index, item} -> item.nameid == nameid end)
    PlayerState.client_index(server_index)
  end

  defp only_item(container, nameid) do
    Enum.find_value(container, fn {_index, item} ->
      if item.nameid == nameid, do: item
    end)
  end

  defp assert_item_attributes(item, craft, random_options) do
    assert %InventoryItem{
             refine: 7,
             card0: @poring_card,
             card1: @fabre_card,
             card2: @pupa_card,
             card3: @drops_card,
             random_options: ^random_options,
             bound: 2,
             unique_id: 123_456,
             craft: ^craft
           } = item
  end

  defp account_fixture(prefix) do
    suffix = System.unique_integer([:positive])
    userid = "gs#{String.downcase(prefix)}#{suffix}"

    %Account{}
    |> Account.changeset(%{
      userid: userid,
      user_pass: "password",
      sex: "M",
      email: "#{userid}@example.com"
    })
    |> Repo.insert!()
  end

  defp character_fixture(prefix) do
    account = account_fixture(prefix)
    suffix = System.unique_integer([:positive])

    %{
      account_id: account.id,
      char_num: 0,
      name: "GS#{prefix}#{suffix}",
      class: 0,
      base_level: 50,
      job_level: 50,
      last_map: @map,
      last_x: elem(@npc_position, 0),
      last_y: elem(@npc_position, 1),
      save_map: @map,
      save_x: elem(@npc_position, 0),
      save_y: elem(@npc_position, 1)
    }
    |> Character.new()
    |> Repo.insert!()
  end
end
