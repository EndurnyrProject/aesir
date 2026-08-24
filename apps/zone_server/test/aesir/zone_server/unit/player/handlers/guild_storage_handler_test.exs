defmodule Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageHandlerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.StorageCloseRequest
  alias Aesir.Net.StorageDepositRequest
  alias Aesir.Net.StorageItemAdded
  alias Aesir.Net.StorageItemRemoved
  alias Aesir.Net.StorageOpened
  alias Aesir.Net.StorageResult
  alias Aesir.Net.StorageWithdrawRequest
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Guild.Storage.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StorageOps
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Storage.Persistence, as: PersonalStoragePersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    Mimic.copy(GuildStorageHandler)
    Mimic.copy(GuildStorageOps)
    Mimic.copy(Persistence)
    ClusterTestHelper.clear_all()
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  @guild_id 42
  @char_id 8_001
  @guild_storage_skill 10_016

  test "personal storage view messages retain the personal kind" do
    stored = item(501, 1)

    assert %StorageOpened{kind: :STORAGE_KIND_PERSONAL} =
             InventoryView.storage_opened(%{0 => stored})

    assert %StorageItemAdded{kind: :STORAGE_KIND_PERSONAL} =
             InventoryView.storage_item_added(stored, 0)

    assert %StorageItemRemoved{kind: :STORAGE_KIND_PERSONAL} =
             InventoryView.storage_item_removed(0, 1, 0)
  end

  test "a guild-kind deposit cannot fall through to an open personal container" do
    moved = item(501, 1)
    personal_storage = %{}

    stub(StorageOps, :deposit, fn 3_000, @char_id, _inventory, ^personal_storage, 0, 1 ->
      {:ok, %{}, %{0 => moved}, {:removed, 0}, {:added, 0, moved}}
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    state = state(storage: personal_storage, inventory: %{0 => moved})

    request = %StorageDepositRequest{
      kind: :STORAGE_KIND_GUILD,
      inventory_index: PlayerState.client_index(0),
      amount: 1
    }

    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_NOT_OPEN}}}
  end

  test "a guild-kind withdraw cannot act on an open personal container" do
    reject(&StorageHandler.withdraw/3)

    state = state(storage: %{0 => item(501, 1)})

    request = %StorageWithdrawRequest{
      kind: :STORAGE_KIND_GUILD,
      storage_index: PlayerState.client_index(0),
      amount: 1
    }

    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_NOT_OPEN}}}
  end

  test "a personal-kind close is a silent no-op while only guild storage is open" do
    state = state(guild_storage: %{}, guild_storage_ctx: storage_ctx(300))
    request = %StorageCloseRequest{kind: :STORAGE_KIND_PERSONAL}

    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)
    refute_received {:send, _, {:storage_result, %StorageResult{}}}
  end

  test "a guild-kind close is a silent no-op while only personal storage is open" do
    state = state(storage: %{})
    request = %StorageCloseRequest{kind: :STORAGE_KIND_GUILD}

    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)
    refute_received {:send, _, {:storage_result, %StorageResult{}}}
  end

  test "a guild-kind close routes to the guild storage handler" do
    state = state()
    expect(GuildStorageHandler, :close, fn ^state -> {:noreply, state} end)

    request = %StorageCloseRequest{kind: :STORAGE_KIND_GUILD}
    assert {:noreply, ^state} = PacketHandler.handle_message(request, state)
  end

  test "successful deposit commits both containers and emits guild storage deltas" do
    moved = item(501, 4)
    new_storage = %{0 => moved}
    ctx = storage_ctx(300)

    stub(GuildStorageOps, :deposit, fn ^ctx, _inventory, %{}, 0, 4 ->
      {:ok, %{}, new_storage, {:removed, 0}, {:added, 0, moved}}
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    state =
      state(
        inventory: %{0 => moved},
        guild_storage: %{},
        guild_storage_ctx: ctx
      )

    client_index = PlayerState.client_index(0)
    assert {:noreply, committed} = GuildStorageHandler.deposit(client_index, 4, state)

    assert committed.game_state.inventory == %{}
    assert committed.game_state.guild_storage == new_storage

    assert_received {:send, :gameplay,
                     {:item_removed, %ItemRemoved{index: ^client_index, amount: 4}}}

    assert_received {:send, :gameplay,
                     {:storage_item_added,
                      %StorageItemAdded{
                        kind: :STORAGE_KIND_GUILD,
                        index: ^client_index,
                        nameid: 501,
                        amount: 4
                      }}}

    assert_received {:send, :gameplay, {:storage_result, %StorageResult{result: :STORAGE_OK}}}
  end

  test "successful withdraw commits both containers and emits guild storage deltas" do
    moved = item(501, 3)
    new_inventory = %{0 => moved}
    ctx = storage_ctx(300)

    stub(GuildStorageOps, :withdraw, fn ^ctx, %{}, _storage, _stats, 0, 3 ->
      {:ok, new_inventory, %{}, {:added, 0, moved}, {:removed, 0}}
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    state = state(guild_storage: %{0 => moved}, guild_storage_ctx: ctx)
    client_index = PlayerState.client_index(0)

    assert {:noreply, committed} = GuildStorageHandler.withdraw(client_index, 3, state)

    assert committed.game_state.inventory == new_inventory
    assert committed.game_state.guild_storage == %{}

    assert_received {:send, :gameplay,
                     {:storage_item_removed,
                      %StorageItemRemoved{
                        kind: :STORAGE_KIND_GUILD,
                        index: ^client_index,
                        amount: 3
                      }}}

    assert_received {:send, :gameplay,
                     {:item_added, %ItemAdded{index: ^client_index, nameid: 501, amount: 3}}}

    assert_received {:send, :gameplay, {:storage_result, %StorageResult{result: :STORAGE_OK}}}
  end

  test "guild transfer errors map to their dedicated result codes" do
    ctx = storage_ctx(300)
    state = state(guild_storage: %{}, guild_storage_ctx: ctx)

    stub(GuildStorageOps, :deposit, fn ^ctx, _inventory, %{}, 0, 1 ->
      {:error, Process.get(:guild_storage_error)}
    end)

    for {reason, code} <- [
          rental: :STORAGE_RENTAL,
          no_guild_storage: :STORAGE_NO_GUILD_STORAGE,
          not_holder: :STORAGE_STALE,
          stale: :STORAGE_STALE
        ] do
      Process.put(:guild_storage_error, reason)
      assert {:noreply, ^state} = GuildStorageHandler.deposit(2, 1, state)
      assert_received {:send, :gameplay, {:storage_result, %StorageResult{result: ^code}}}
    end
  end

  test "withdraw while guild storage is closed is refused" do
    reject(&GuildStorageOps.withdraw/6)

    state = state()

    assert {:noreply, ^state} = GuildStorageHandler.withdraw(2, 1, state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_NOT_OPEN}}}
  end

  test "a non-positive transfer amount is refused before calling the ops layer" do
    reject(&GuildStorageOps.deposit/5)

    state = state(guild_storage: %{}, guild_storage_ctx: storage_ctx(300))

    assert {:noreply, ^state} = GuildStorageHandler.deposit(2, 0, state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_INVALID_AMOUNT}}}
  end

  test "deposit while guild storage is closed is refused" do
    reject(&GuildStorageOps.deposit/5)

    state = state()

    assert {:noreply, ^state} = GuildStorageHandler.deposit(2, 1, state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_NOT_OPEN}}}
  end

  test "force_close releases the lock and clears the window without a reply tuple" do
    ctx = storage_ctx(300)
    state = state(guild_storage: %{}, guild_storage_ctx: ctx)

    assert :ok = Lock.claim(@guild_id, @char_id, self())
    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    closed = GuildStorageHandler.force_close(state)
    assert closed.game_state.guild_storage == nil
    assert closed.guild_storage_ctx == nil
    assert :error = Lock.holder(@guild_id)
  end

  test "close clears the window context and releases its lock" do
    ctx = storage_ctx(300)
    state = state(guild_storage: %{}, guild_storage_ctx: ctx)

    assert :ok = Lock.claim(@guild_id, @char_id, self())
    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    assert {:noreply, closed} = GuildStorageHandler.close(state)
    assert closed.game_state.guild_storage == nil
    assert closed.guild_storage_ctx == nil
    assert :error = Lock.holder(@guild_id)
  end

  test "close is a silent no-op when guild storage is already closed" do
    holder = anchor()
    assert :ok = Lock.claim(@guild_id, 9_999, holder)

    state = state()

    assert {:noreply, ^state} = GuildStorageHandler.close(state)
    refute_received {:send, _, {:storage_result, %StorageResult{}}}

    assert {:ok, %{char_id: 9_999, session_pid: ^holder}} = Lock.holder(@guild_id)
  end

  test "personal storage refuses to open while guild storage is open" do
    reject(&PersonalStoragePersistence.load_storage/1)

    state = state(guild_storage: %{}, guild_storage_ctx: storage_ctx(300))

    assert {:noreply, ^state} = StorageHandler.open(state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_OTHER_STORAGE_OPEN}}}
  end

  test "open without a guild is refused before guild lookup" do
    reject(&Manager.ensure_started/1)

    state = %SessionState{
      connection_pid: self(),
      game_state: %PlayerState{character_id: @char_id, guild_id: 0, storage: nil}
    }

    assert {:noreply, ^state} = GuildStorageHandler.open(state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_NO_GUILD}}}
  end

  test "open without the guild storage skill is refused before loading rows" do
    guild = guild_state(skill_level: 0, can_storage: true)
    stub(Manager, :ensure_started, fn @guild_id -> {:ok, guild} end)
    reject(&Persistence.load_storage/1)

    state = state()

    assert {:noreply, ^state} = GuildStorageHandler.open(state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_GUILD_NO_SKILL}}}
  end

  test "open while personal storage is open is refused before claiming the lock" do
    guild = guild_state(skill_level: 1, can_storage: true)
    stub(Manager, :ensure_started, fn @guild_id -> {:ok, guild} end)
    reject(&Persistence.load_storage/1)

    state = state(storage: %{})

    assert {:noreply, ^state} = GuildStorageHandler.open(state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_OTHER_STORAGE_OPEN}}}

    assert :error = Lock.holder(@guild_id)
  end

  test "successful open caches context and sends the guild kind with skill capacity" do
    guild = guild_state(skill_level: 2, can_storage: true)
    stub(Manager, :ensure_started, fn @guild_id -> {:ok, guild} end)
    stub(Persistence, :load_storage, fn @guild_id -> [] end)
    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)

    assert {:noreply, opened} = GuildStorageHandler.open(state())

    assert opened.game_state.guild_storage == %{}

    assert opened.guild_storage_ctx == %{
             guild_id: @guild_id,
             char_id: @char_id,
             session_pid: self(),
             capacity: 300
           }

    assert_received {:send, :bulk,
                     {:storage_opened,
                      %StorageOpened{
                        kind: :STORAGE_KIND_GUILD,
                        capacity: 300,
                        items: []
                      }}}
  end

  test "re-opening sends the cached window without lookup, claim, or database load" do
    reject(&Manager.ensure_started/1)
    reject(&Persistence.load_storage/1)

    ctx = %{
      guild_id: @guild_id,
      char_id: @char_id,
      session_pid: self(),
      capacity: 300
    }

    state = state(guild_storage: %{}, guild_storage_ctx: ctx)
    assert :ok = Lock.claim(@guild_id, @char_id, self())

    assert {:noreply, ^state} = GuildStorageHandler.open(state)

    assert_received {:send, :bulk,
                     {:storage_opened,
                      %StorageOpened{
                        kind: :STORAGE_KIND_GUILD,
                        capacity: 300,
                        items: []
                      }}}
  end

  test "open while another member holds the guild storage is refused" do
    guild = guild_state(skill_level: 1, can_storage: true)
    stub(Manager, :ensure_started, fn @guild_id -> {:ok, guild} end)
    reject(&Persistence.load_storage/1)

    holder = anchor()
    assert :ok = Lock.claim(@guild_id, 9_999, holder)

    state = state()

    assert {:noreply, ^state} = GuildStorageHandler.open(state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_GUILD_IN_USE}}}
  end

  test "a permission failure leaves the guild storage lock free" do
    guild = guild_state(skill_level: 1, can_storage: false)
    stub(Manager, :ensure_started, fn @guild_id -> {:ok, guild} end)
    reject(&Persistence.load_storage/1)

    state = state()

    assert {:noreply, ^state} = GuildStorageHandler.open(state)

    assert_received {:send, :gameplay,
                     {:storage_result, %StorageResult{result: :STORAGE_GUILD_NO_PERMISSION}}}

    assert :error = Lock.holder(@guild_id)
  end

  defp state(opts \\ []) do
    game_state = %{
      PlayerState.new(character())
      | guild_id: @guild_id,
        storage: Keyword.get(opts, :storage),
        inventory: Keyword.get(opts, :inventory, %{}),
        guild_storage: Keyword.get(opts, :guild_storage)
    }

    %SessionState{
      connection_pid: self(),
      game_state: game_state,
      guild_storage_ctx: Keyword.get(opts, :guild_storage_ctx)
    }
  end

  defp character do
    %Character{
      id: @char_id,
      account_id: 3_000,
      name: "Member",
      class: 0,
      base_level: 50,
      job_level: 50,
      hp: 800,
      sp: 300,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      learned_skills: %{Integer.to_string(1) => 6}
    }
  end

  defp storage_ctx(capacity) do
    %{
      guild_id: @guild_id,
      char_id: @char_id,
      session_pid: self(),
      capacity: capacity
    }
  end

  defp item(nameid, amount) do
    %InventoryItem{
      id: 11,
      nameid: nameid,
      amount: amount,
      equip: 0,
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{},
      bound: 0,
      favorite: 0
    }
  end

  defp anchor do
    pid = spawn(fn -> receive do: (:stop -> :ok) end)
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    pid
  end

  defp guild_state(opts) do
    level = Keyword.fetch!(opts, :skill_level)
    can_storage = Keyword.fetch!(opts, :can_storage)
    member = Member.new(@char_id, "Member", 50, true, 5, "prontera")

    %GuildState{
      guild_id: @guild_id,
      name: "Guild",
      master_char_id: 999,
      positions: %{5 => %Position{index: 5, can_storage: can_storage}},
      members: %{@char_id => member},
      learned_skills: if(level == 0, do: %{}, else: %{@guild_storage_skill => level})
    }
  end
end
