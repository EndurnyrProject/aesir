defmodule Aesir.ZoneServer.Guild.ManagerTest do
  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.Factory
  import Aesir.TestWait
  import Ecto.Query
  import ExUnit.CaptureLog

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildActivityLog
  alias Aesir.Commons.Models.GuildExpulsion
  alias Aesir.Commons.Models.GuildPosition
  alias Aesir.Commons.Models.GuildRelation
  alias Aesir.Commons.Models.GuildStorageLog
  alias Aesir.Net.StorageResult
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Activity
  alias Aesir.ZoneServer.Guild.Lifecycle
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Relation
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Guild.Storage.Persistence, as: GuildStoragePersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.GuildStorageOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @newbie_position 19
  @max_members 16

  setup :verify_on_exit!
  setup :set_mimic_from_context

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp guild_fixture(master_name) do
    master = insert(:character, name: master_name)
    {:ok, state} = Manager.create("Guild-#{master_name}", master)
    {master, state}
  end

  defp fill_to(state, count, prefix) do
    Enum.reduce((State.member_count(state) + 1)..count, state, fn n, acc ->
      joiner = insert(:character, name: "#{prefix}#{n}")
      {:ok, next} = Manager.add_member(acc.guild_id, joiner)
      next
    end)
  end

  describe "create/2" do
    test "persists guild + 20 positions + master at guild_id/position 0 and starts an entry" do
      master =
        insert(:character, name: "Founder", class: 7, base_level: 50, hp: 500, max_hp: 1_000)

      assert {:ok, %State{} = state} = Manager.create("Vanguard", master)
      assert state.name == "Vanguard"
      assert state.master_char_id == master.id
      assert state.emblem_id == 0
      assert map_size(state.positions) == 20

      member = Map.fetch!(state.members, master.id)
      assert member.online == true
      assert member.position_index == 0
      assert member.job_id == 7

      guild = Repo.get_by(GuildModel, name: "Vanguard")
      assert guild

      assert Repo.aggregate(from(p in GuildPosition, where: p.guild_id == ^guild.id), :count) ==
               20

      reloaded = Repo.get(Character, master.id)
      assert reloaded.guild_id == guild.id
      assert reloaded.guild_position == 0

      assert {:ok, ^state} = Manager.get(state.guild_id)
    end

    test "seeds default position flags (master invite+expel, newbie none)" do
      {_master, state} = guild_fixture("Seeded")

      master_pos = Map.fetch!(state.positions, 0)
      assert master_pos.name == "GuildMaster"
      assert master_pos.can_invite and master_pos.can_expel

      newbie_pos = Map.fetch!(state.positions, @newbie_position)
      assert newbie_pos.name == "Newbie"
      refute newbie_pos.can_invite or newbie_pos.can_expel
    end

    test "duplicate name returns {:error, :name_taken} with no partial writes" do
      master1 = insert(:character, name: "Owner1")
      master2 = insert(:character, name: "Owner2")

      assert {:ok, _state} = Manager.create("SameName", master1)
      assert {:error, :name_taken} = Manager.create("SameName", master2)

      reloaded = Repo.get(Character, master2.id)
      assert reloaded.guild_id == 0
      assert reloaded.guild_position == 0

      assert Repo.aggregate(from(g in GuildModel, where: g.name == "SameName"), :count) == 1
    end

    test "blank name returns {:error, :invalid_name}" do
      master = insert(:character, name: "Blankster")
      assert {:error, :invalid_name} = Manager.create("   ", master)
    end
  end

  describe "ensure_started/1" do
    test "rebuilds guild + positions + offline members from the DB" do
      master =
        insert(:character, name: "RebuildMaster", class: 9, base_level: 40, last_map: "geffen")

      {:ok, created} = Manager.create("Rebuildable", master)
      joiner = insert(:character, name: "RebuildJoiner")
      {:ok, _joined} = Manager.add_member(created.guild_id, joiner)

      ClusterTestHelper.clear_all()
      assert {:error, :not_found} = Manager.get(created.guild_id)

      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert rebuilt.name == "Rebuildable"
      assert rebuilt.master_char_id == master.id
      assert map_size(rebuilt.positions) == 20
      assert map_size(rebuilt.members) == 2

      master_member = Map.fetch!(rebuilt.members, master.id)
      assert master_member.online == false
      assert master_member.position_index == 0
      assert master_member.map_name == "geffen"

      joiner_member = Map.fetch!(rebuilt.members, joiner.id)
      assert joiner_member.position_index == @newbie_position
    end

    test "rebuilds a guild's relations from persisted rows" do
      {_master, created} = guild_fixture("RebuildRelations")
      {_ally_master, ally} = guild_fixture("RebuildRelationsAlly")
      ally_id = ally.guild_id
      assert :ok = Relations.ally(created.guild_id, ally_id)

      ClusterTestHelper.clear_all()

      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)

      assert %{^ally_id => %Relation{kind: :ally}} = rebuilt.relations
    end

    test "returns {:error, :not_found} when no guild row exists" do
      assert {:error, :not_found} = Manager.ensure_started(999_999)
    end

    test "is a no-op when an entry is already running" do
      {_master, created} = guild_fixture("AlreadyUp")
      assert {:ok, ^created} = Manager.ensure_started(created.guild_id)
    end

    test "hydrates progression fields, integer-keying jsonb learned skills" do
      {_master, created} = guild_fixture("ProgressionHydrate")

      {1, nil} =
        from(g in GuildModel, where: g.id == ^created.guild_id)
        |> Repo.update_all(
          set: [level: 3, exp: 500_000, skill_points: 2, learned_skills: %{"10004" => 3}]
        )

      ClusterTestHelper.clear_all()

      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert rebuilt.level == 3
      assert rebuilt.exp == 500_000
      assert rebuilt.skill_points == 2
      assert rebuilt.learned_skills == %{10_004 => 3}
    end
  end

  describe "add_member/2" do
    test "joins at the Newbie position, persists, and broadcasts {:guild_updated, state}" do
      {_master, created} = guild_fixture("Joiners")
      joiner = insert(:character, name: "Newcomer")

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert {:ok, state} = Manager.add_member(created.guild_id, joiner)
      member = Map.fetch!(state.members, joiner.id)
      assert member.position_index == @newbie_position
      assert member.online == true

      reloaded = Repo.get(Character, joiner.id)
      assert reloaded.guild_id == created.guild_id
      assert reloaded.guild_position == @newbie_position

      assert_receive {:social, {:guild_updated, ^state}}
    end

    test "rejects a full guild (cap 16) without mutating state" do
      {_master, created} = guild_fixture("Packed")
      full = fill_to(created, @max_members, "Packed")

      overflow = insert(:character, name: "Overflow")
      assert {:error, :guild_full} = Manager.add_member(full.guild_id, overflow)
      assert Repo.get(Character, overflow.id).guild_id == 0
    end

    test "returns {:error, :not_found} when no entry is running" do
      joiner = insert(:character, name: "SoloJoin")
      assert {:error, :not_found} = Manager.add_member(999_999, joiner)
    end

    test "two concurrent adds into the last slot yield one success and one guild_full" do
      {_master, created} = guild_fixture("Race")
      filled = fill_to(created, @max_members - 1, "Race")

      a = insert(:character, name: "RaceA")
      b = insert(:character, name: "RaceB")

      [ra, rb] =
        [
          Task.async(fn -> Manager.add_member(filled.guild_id, a) end),
          Task.async(fn -> Manager.add_member(filled.guild_id, b) end)
        ]
        |> Task.await_many()

      assert Enum.count([ra, rb], &match?({:ok, _}, &1)) == 1
      assert Enum.count([ra, rb], &match?({:error, :guild_full}, &1)) == 1
    end
  end

  describe "member slots" do
    test "a rebuilt entry numbers members by position, a joiner takes the lowest free slot" do
      {master, created} = guild_fixture("Slots")
      first = insert(:character, name: "SlotsFirst")
      second = insert(:character, name: "SlotsSecond")
      {:ok, _} = Manager.add_member(created.guild_id, first)
      {:ok, _} = Manager.add_member(created.guild_id, second)

      from(c in Character, where: c.id == ^second.id) |> Repo.update_all(set: [guild_position: 5])
      ClusterTestHelper.clear_all()
      {:ok, rebuilt} = Manager.ensure_started(created.guild_id)

      assert slots(rebuilt) == %{master.id => 0, second.id => 1, first.id => 2}

      {:ok, left} = Manager.remove_member(created.guild_id, second.id)
      assert slots(left) == %{master.id => 0, first.id => 2}

      third = insert(:character, name: "SlotsThird")
      {:ok, joined} = Manager.add_member(created.guild_id, third)
      assert slots(joined) == %{master.id => 0, third.id => 1, first.id => 2}
    end

    test "a member's presence update keeps its slot" do
      {master, created} = guild_fixture("SlotsSync")
      pushed = Member.new(master.id, master.name, 99, true, 0)

      {:ok, state} = Manager.sync_member(created.guild_id, master.id, pushed)

      assert state.members[master.id].slot == 0
    end
  end

  defp slots(state), do: Map.new(state.members, fn {id, member} -> {id, member.slot} end)

  describe "remove_member/2" do
    test "drops a non-master member and resets its row" do
      {_master, created} = guild_fixture("Leavers")
      joiner = insert(:character, name: "Quitter")
      {:ok, joined} = Manager.add_member(created.guild_id, joiner)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{joined.guild_id}")

      assert {:ok, state} = Manager.remove_member(joined.guild_id, joiner.id)
      refute Map.has_key?(state.members, joiner.id)
      reloaded = Repo.get(Character, joiner.id)
      assert reloaded.guild_id == 0
      assert reloaded.guild_position == 0
      assert_receive {:social, {:guild_updated, ^state}}
    end

    test "the master leaving disbands the guild" do
      {master, created} = guild_fixture("MasterLeaves")
      joiner = insert(:character, name: "Follower")
      {:ok, _joined} = Manager.add_member(created.guild_id, joiner)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert :ok = Manager.remove_member(created.guild_id, master.id)
      assert {:error, :not_found} = Manager.get(created.guild_id)
      assert Repo.get(GuildModel, created.guild_id) == nil
      assert Repo.get(Character, master.id).guild_id == 0
      assert Repo.get(Character, joiner.id).guild_id == 0
      assert_receive {:social, {:guild_disbanded, _id, "master_left"}}
    end

    test "returns {:error, :not_found} when no entry is running" do
      assert {:error, :not_found} = Manager.remove_member(999_999, 1)
    end
  end

  describe "disband/2" do
    test "resets every member, deletes positions/expulsions/guild, stops the entry, broadcasts" do
      {master, created} = guild_fixture("Doomed")
      joiner = insert(:character, name: "DoomedMember")
      {:ok, _joined} = Manager.add_member(created.guild_id, joiner)
      other = insert(:character, name: "Expelled")
      {:ok, _} = Manager.add_member(created.guild_id, other)
      {:ok, _} = Manager.expel(created.guild_id, master.id, other.id, "spam")

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert :ok = Manager.disband(created.guild_id, "gm_action")

      assert {:error, :not_found} = Manager.get(created.guild_id)
      assert Repo.get(GuildModel, created.guild_id) == nil

      assert Repo.aggregate(
               from(p in GuildPosition, where: p.guild_id == ^created.guild_id),
               :count
             ) == 0

      assert Repo.aggregate(
               from(e in GuildExpulsion, where: e.guild_id == ^created.guild_id),
               :count
             ) == 0

      assert Repo.get(Character, master.id).guild_id == 0
      assert Repo.get(Character, joiner.id).guild_id == 0
      assert_receive {:social, {:guild_disbanded, _id, "gm_action"}}
    end

    test "publishes {:disbanded, guild_id} on the guild lifecycle topic" do
      {_master, created} = guild_fixture("LifecycleDoomed")
      guild_id = created.guild_id

      assert :ok = Lifecycle.subscribe()
      assert :ok = Manager.disband(guild_id, "gm_action")

      assert_receive {:guild_lifecycle, {:disbanded, ^guild_id}}
    end

    test "disbanding an allied guild refreshes the peer's live entry and leaves no rows" do
      {_master, disbanded} = guild_fixture("DisbandedAlly")
      {_peer_master, peer} = guild_fixture("SurvivingAlly")
      disbanded_id = disbanded.guild_id
      peer_id = peer.guild_id
      assert :ok = Relations.ally(disbanded_id, peer_id)

      assert :ok = Manager.disband(disbanded_id, "gm_action")

      assert {:ok, %State{relations: relations}} = Manager.get(peer_id)
      refute Map.has_key?(relations, disbanded_id)

      assert Repo.aggregate(
               from(r in GuildRelation,
                 where: r.guild_id == ^disbanded_id or r.other_guild_id == ^disbanded_id
               ),
               :count
             ) == 0
    end

    test "disbanding a guild refreshes a peer that declared it an antagonist" do
      {_master, disbanded} = guild_fixture("AntagonizedGuild")
      {_peer_master, peer} = guild_fixture("AntagonizingPeer")
      disbanded_id = disbanded.guild_id
      peer_id = peer.guild_id

      assert :ok = Relations.declare_antagonist(peer_id, disbanded_id)
      assert {:ok, %State{relations: relations}} = Manager.get(peer_id)
      assert Map.has_key?(relations, disbanded_id)

      assert :ok = Manager.disband(disbanded_id, "gm_action")

      assert {:ok, %State{relations: relations}} = Manager.get(peer_id)
      refute Map.has_key?(relations, disbanded_id)
    end

    test "a failed disband leaves the storage claim and window usable" do
      {master, created} = guild_fixture("FailedDisband")
      guild_id = created.guild_id
      ctx = %{guild_id: guild_id, char_id: master.id, session_pid: self(), capacity: 600}

      {:ok, row} =
        GuildStoragePersistence.insert_item(guild_id, %{nameid: 501, amount: 4, identify: 1})

      storage = PlayerState.from_list([GuildStoragePersistence.to_session_item(row)])
      assert :ok = Lock.claim(guild_id, master.id, self())

      stub(Repo, :transaction, fn %Ecto.Multi{} ->
        {:error, :guild, :forced_failure, %{}}
      end)

      assert {:error, :forced_failure} = Manager.disband(guild_id, "gm_action")
      assert Lock.held_by?(guild_id, self())
      assert Repo.get(GuildModel, guild_id)

      assert {:ok, %{0 => _persisted_item}, %{}, {:added, 0, _change_item}, {:removed, 0}} =
               GuildStorageOps.withdraw(
                 ctx,
                 %{},
                 storage,
                 Stats.from_character(master),
                 0,
                 4
               )
    end

    test "an in-flight withdraw after the cascade rolls back as stale" do
      {master, created} = guild_fixture("StaleDisband")
      guild_id = created.guild_id
      ctx = %{guild_id: guild_id, char_id: master.id, session_pid: self(), capacity: 600}

      {:ok, row} =
        GuildStoragePersistence.insert_item(guild_id, %{nameid: 501, amount: 4, identify: 1})

      storage = PlayerState.from_list([GuildStoragePersistence.to_session_item(row)])
      assert :ok = Lock.claim(guild_id, master.id, self())
      Mimic.copy(Lock)

      expect(Lock, :stop, fn ^guild_id ->
        assert [] = GuildStoragePersistence.load_storage(guild_id)
        assert Lock.held_by?(guild_id, self())

        assert {:error, :stale} =
                 GuildStorageOps.withdraw(
                   ctx,
                   %{},
                   storage,
                   Stats.from_character(master),
                   0,
                   4
                 )

        call_original(Lock, :stop, [guild_id])
      end)

      assert :ok = Manager.disband(guild_id, "gm_action")
      assert [] = InventoryPersistence.load_inventory(master.id)

      assert Repo.aggregate(
               from(log in GuildStorageLog, where: log.guild_id == ^guild_id),
               :count
             ) == 0

      assert_eventually(fn -> Lock.holder(guild_id) == :error end)
    end

    test "a post-cascade deposit is rejected without crashing the session" do
      {master, created} = guild_fixture("CascadeDeposit")
      guild_id = created.guild_id
      ctx = %{guild_id: guild_id, char_id: master.id, session_pid: self(), capacity: 600}

      {:ok, item} =
        InventoryPersistence.insert_item(master.id, %{nameid: 501, amount: 4, identify: 1})

      game_state = %{
        PlayerState.new(master)
        | guild_id: guild_id,
          inventory: PlayerState.from_list([item]),
          guild_storage: %{}
      }

      state = %SessionState{
        connection_pid: self(),
        game_state: game_state,
        guild_storage_ctx: ctx
      }

      assert :ok = Lock.claim(guild_id, master.id, self())
      Mimic.copy(Lock)

      expect(Lock, :stop, fn ^guild_id ->
        assert [] = GuildStoragePersistence.load_storage(guild_id)

        assert {:noreply, ^state} =
                 GuildStorageHandler.deposit(PlayerState.client_index(0), 4, state)

        :ok
      end)

      log = capture_log(fn -> assert :ok = Manager.disband(guild_id, "gm_action") end)

      assert log =~ "Guild storage transfer failed"

      assert_received {:send, :gameplay,
                       {:storage_result, %StorageResult{result: :STORAGE_STALE}}}

      assert [%{id: item_id, amount: 4}] = InventoryPersistence.load_inventory(master.id)
      assert item_id == item.id
      assert [] = GuildStoragePersistence.load_storage(guild_id)

      assert Repo.aggregate(
               from(entry in GuildStorageLog, where: entry.guild_id == ^guild_id),
               :count
             ) == 0
    end

    test "a failed claim stop cannot suppress a committed disband" do
      {master, created} = guild_fixture("StopFailure")
      guild_id = created.guild_id
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{guild_id}")
      assert :ok = Lock.claim(guild_id, master.id, self())
      Mimic.copy(Lock)

      expect(Lock, :stop, fn ^guild_id -> exit(:timeout) end)

      log = capture_log(fn -> assert :ok = Manager.disband(guild_id, "gm_action") end)

      assert log =~ "Failed to stop guild storage claim for guild #{guild_id}"
      assert_receive {:social, {:guild_disbanded, ^guild_id, "gm_action"}}
      assert {:error, :not_found} = Manager.get(guild_id)
      assert Repo.get(GuildModel, guild_id) == nil
      assert Lock.held_by?(guild_id, self())
    end

    test "returns {:error, :not_found} when no entry is running and publishes nothing" do
      assert :ok = Lifecycle.subscribe()
      assert {:error, :not_found} = Manager.disband(999_999, "gm_action")
      refute_receive {:guild_lifecycle, _event}
    end
  end

  describe "expel/4" do
    test "master expels a member, resets the row, and writes exactly one expulsion" do
      {master, created} = guild_fixture("Expellers")
      target = insert(:character, name: "Troublemaker")
      {:ok, _joined} = Manager.add_member(created.guild_id, target)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert {:ok, state} = Manager.expel(created.guild_id, master.id, target.id, "griefing")
      refute Map.has_key?(state.members, target.id)

      reloaded = Repo.get(Character, target.id)
      assert reloaded.guild_id == 0
      assert reloaded.guild_position == 0

      rows =
        Repo.all(
          from e in GuildExpulsion,
            where: e.guild_id == ^created.guild_id and e.char_id == ^target.id
        )

      assert length(rows) == 1
      assert hd(rows).reason == "griefing"
      assert hd(rows).name == "Troublemaker"
      assert hd(rows).account_id == target.account_id

      assert_receive {:social, {:guild_updated, ^state}}
    end

    test "denies a requester without the EXPEL permission" do
      {_master, created} = guild_fixture("Gated")
      member = insert(:character, name: "Powerless")
      {:ok, _} = Manager.add_member(created.guild_id, member)
      target = insert(:character, name: "Victim")
      {:ok, _} = Manager.add_member(created.guild_id, target)

      assert {:error, :no_permission} =
               Manager.expel(created.guild_id, member.id, target.id, "abuse")

      assert Repo.get(Character, target.id).guild_id == created.guild_id
    end

    test "refuses to expel the master" do
      {master, created} = guild_fixture("Untouchable")

      assert {:error, :cannot_target_master} =
               Manager.expel(created.guild_id, master.id, master.id, "self")
    end

    test "a member granted expel permission can expel" do
      {master, created} = guild_fixture("Delegated")
      officer = insert(:character, name: "Officer")
      {:ok, _} = Manager.add_member(created.guild_id, officer)
      target = insert(:character, name: "Doomed2")
      {:ok, _} = Manager.add_member(created.guild_id, target)

      {:ok, _} =
        Manager.edit_position(created.guild_id, master.id, %{
          index: 1,
          name: "Officer",
          can_invite: false,
          can_expel: true
        })

      {:ok, _} = Manager.assign_member_position(created.guild_id, master.id, officer.id, 1)

      assert {:ok, state} = Manager.expel(created.guild_id, officer.id, target.id, "by officer")
      refute Map.has_key?(state.members, target.id)
    end
  end

  describe "change_emblem/3" do
    test "master bumps emblem_id and stores the blob, broadcasting the change" do
      {master, created} = guild_fixture("Emblazoned")
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      blob = <<"BM", 0, 1, 2, 3>>
      assert {:ok, emblem_id} = Manager.change_emblem(created.guild_id, master.id, blob)
      assert emblem_id == 1

      guild = Repo.get(GuildModel, created.guild_id)
      assert guild.emblem_id == 1
      assert guild.emblem_data == blob

      assert {:ok, state} = Manager.get(created.guild_id)
      assert state.emblem_id == 1

      guild_id = created.guild_id
      assert_receive {:social, {:guild_emblem_changed, ^guild_id, 1}}
    end

    test "denies a non-master" do
      {_master, created} = guild_fixture("EmblemGate")
      member = insert(:character, name: "NotMaster")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:error, :no_permission} =
               Manager.change_emblem(created.guild_id, member.id, <<"BM">>)

      assert Repo.get(GuildModel, created.guild_id).emblem_id == 0
    end
  end

  describe "set_notice/3" do
    test "master sets the notice and it persists" do
      {master, created} = guild_fixture("Announcers")

      assert {:ok, state} =
               Manager.set_notice(created.guild_id, master.id, %{
                 subject: "Welcome",
                 body: "Read the rules"
               })

      assert state.notice == %{subject: "Welcome", body: "Read the rules"}
      guild = Repo.get(GuildModel, created.guild_id)
      assert guild.notice_subject == "Welcome"
      assert guild.notice_body == "Read the rules"
    end

    test "denies a non-master" do
      {_master, created} = guild_fixture("NoticeGate")
      member = insert(:character, name: "Grunt")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:error, :no_permission} =
               Manager.set_notice(created.guild_id, member.id, %{subject: "x", body: "y"})
    end
  end

  describe "edit_position/3" do
    test "master edits a non-zero position and it persists" do
      {master, created} = guild_fixture("Editors")

      assert {:ok, state} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 5,
                 name: "Veteran",
                 can_invite: true,
                 can_expel: false
               })

      pos = Map.fetch!(state.positions, 5)
      assert pos.name == "Veteran"
      assert pos.can_invite and not pos.can_expel

      row = Repo.get_by(GuildPosition, guild_id: created.guild_id, index: 5)
      assert row.name == "Veteran"
      assert row.can_invite
    end

    test "persists can_storage and preserves it when an older client omits the field" do
      {master, created} = guild_fixture("StorageEditors")

      assert {:ok, _state} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 5,
                 name: "Storage Officer",
                 can_invite: false,
                 can_expel: false,
                 can_storage: true
               })

      assert Repo.get_by(GuildPosition, guild_id: created.guild_id, index: 5).can_storage

      ClusterTestHelper.clear_all()
      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert rebuilt.positions[5].can_storage

      assert {:ok, _state} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 5,
                 name: "Officer",
                 can_invite: true,
                 can_expel: false
               })

      assert Repo.get_by(GuildPosition, guild_id: created.guild_id, index: 5).can_storage

      ClusterTestHelper.clear_all()
      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert rebuilt.positions[5].can_storage

      assert {:ok, state} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 5,
                 name: "Officer",
                 can_invite: true,
                 can_expel: false,
                 can_storage: false
               })

      refute state.positions[5].can_storage
      refute Repo.get_by(GuildPosition, guild_id: created.guild_id, index: 5).can_storage
    end

    test "refuses to edit the protected index 0" do
      {master, created} = guild_fixture("Protected")

      assert {:error, :no_permission} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 0,
                 name: "Hacked",
                 can_invite: false,
                 can_expel: false
               })

      assert Map.fetch!(created.positions, 0).name == "GuildMaster"
    end

    test "denies a non-positions member" do
      {_master, created} = guild_fixture("PosGate")
      member = insert(:character, name: "Peon")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:error, :no_permission} =
               Manager.edit_position(created.guild_id, member.id, %{
                 index: 3,
                 name: "x",
                 can_invite: true,
                 can_expel: true
               })
    end
  end

  describe "assign_member_position/4" do
    test "master assigns a member to a position and it persists" do
      {master, created} = guild_fixture("Assigners")
      member = insert(:character, name: "Climber")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:ok, state} =
               Manager.assign_member_position(created.guild_id, master.id, member.id, 4)

      assert Map.fetch!(state.members, member.id).position_index == 4
      assert Repo.get(Character, member.id).guild_position == 4
    end

    test "denies a non-master" do
      {_master, created} = guild_fixture("AssignGate")
      member = insert(:character, name: "Nobody")
      {:ok, _} = Manager.add_member(created.guild_id, member)
      other = insert(:character, name: "Other")
      {:ok, _} = Manager.add_member(created.guild_id, other)

      assert {:error, :no_permission} =
               Manager.assign_member_position(created.guild_id, member.id, other.id, 3)
    end

    test "rejects an out-of-range index" do
      {master, created} = guild_fixture("RangeCheck")
      member = insert(:character, name: "Ranged")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:error, :invalid_position} =
               Manager.assign_member_position(created.guild_id, master.id, member.id, 20)
    end
  end

  describe "sync_member/3" do
    test "broadcasts {:guild_member_updated, guild_id, member} on a change" do
      {master, created} = guild_fixture("SyncChange")
      %Member{} = old = Map.fetch!(created.members, master.id)
      member = %Member{old | hp: 777, map_name: "morocc"}

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert {:ok, state} = Manager.sync_member(created.guild_id, master.id, member)
      assert Map.fetch!(state.members, master.id) == member

      guild_id = created.guild_id
      assert_receive {:social, {:guild_member_updated, ^guild_id, ^member}}
    end

    test "preserves the stored position_index against a presence projection" do
      {master, created} = guild_fixture("SyncPosition")
      %Member{} = old = Map.fetch!(created.members, master.id)
      assert old.position_index == 0

      member = %Member{old | hp: 555, position_index: @newbie_position}

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert {:ok, state} = Manager.sync_member(created.guild_id, master.id, member)
      assert Map.fetch!(state.members, master.id).position_index == 0
      assert Map.fetch!(state.members, master.id).hp == 555

      guild_id = created.guild_id
      assert_receive {:social, {:guild_member_updated, ^guild_id, broadcast_member}}
      assert broadcast_member.position_index == 0
    end

    test "identical snapshots are a no-op" do
      {master, created} = guild_fixture("SyncNoop")
      member = Map.fetch!(created.members, master.id)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert {:ok, ^created} = Manager.sync_member(created.guild_id, master.id, member)
      refute_receive {:social, {:guild_member_updated, _id, _member}}
    end

    test "rejects a snapshot whose identity differs from the member key" do
      {master, created} = guild_fixture("SyncIdentity")
      %Member{} = old = Map.fetch!(created.members, master.id)
      member = %Member{old | char_id: master.id + 1}

      assert {:error, :not_member} = Manager.sync_member(created.guild_id, master.id, member)
    end

    test "returns {:error, :not_found} when no entry is running" do
      member = Member.new(1, "Ghost", 1, true, @newbie_position)
      assert {:error, :not_found} = Manager.sync_member(999_999, 1, member)
    end

    test "a presence projection keeps the member's stored contribution" do
      {master, created} = guild_fixture("SyncExp")
      :ok = Manager.contribute_exp(created.guild_id, master.id, 300)
      pushed = Member.new(master.id, master.name, 99, true, 0, "morocc")

      assert {:ok, state} = Manager.sync_member(created.guild_id, master.id, pushed)

      assert state.members[master.id].exp == 300
    end
  end

  describe "member last_seen" do
    test "a rebuilt entry carries each offline member's last login, 0 when it never logged in" do
      master = insert(:character, name: "SeenMaster", last_login: ~N[2026-11-11 20:58:00])
      {:ok, created} = Manager.create("SeenGuild", master)
      joiner = insert(:character, name: "SeenNever")
      {:ok, _} = Manager.add_member(created.guild_id, joiner)

      ClusterTestHelper.clear_all()
      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)

      assert rebuilt.members[master.id].last_seen == 1_794_430_680
      assert rebuilt.members[joiner.id].last_seen == 0
    end

    test "coming online stamps it and going offline keeps the stamp" do
      master = insert(:character, name: "SeenOnline")
      {:ok, created} = Manager.create("SeenOnlineGuild", master)
      ClusterTestHelper.clear_all()
      {:ok, _rebuilt} = Manager.ensure_started(created.guild_id)

      before = System.os_time(:second)
      online = Member.new(master.id, master.name, 1, true, 0)
      assert {:ok, state} = Manager.sync_member(created.guild_id, master.id, online)
      stamped = state.members[master.id].last_seen
      assert stamped >= before

      offline = Member.new(master.id, master.name, 1, false, 0)
      assert {:ok, state} = Manager.sync_member(created.guild_id, master.id, offline)

      assert %Member{online: false, last_seen: ^stamped} = state.members[master.id]
    end
  end

  describe "member contribution reset" do
    test "leaving and being expelled both zero the character's guild_exp" do
      {master, created} = guild_fixture("ExpReset")
      leaver = insert(:character, name: "ExpLeaver")
      expelled = insert(:character, name: "ExpExpelled")
      {:ok, _} = Manager.add_member(created.guild_id, leaver)
      {:ok, _} = Manager.add_member(created.guild_id, expelled)
      :ok = Manager.contribute_exp(created.guild_id, leaver.id, 100)
      :ok = Manager.contribute_exp(created.guild_id, expelled.id, 200)
      assert Repo.get(Character, leaver.id).guild_exp == 100

      {:ok, _} = Manager.remove_member(created.guild_id, leaver.id)
      {:ok, _} = Manager.expel(created.guild_id, master.id, expelled.id, "spam")

      assert Repo.get(Character, leaver.id).guild_exp == 0
      assert Repo.get(Character, expelled.id).guild_exp == 0
    end

    test "disbanding zeroes every member's guild_exp" do
      {master, created} = guild_fixture("ExpDisband")
      :ok = Manager.contribute_exp(created.guild_id, master.id, 100)

      assert :ok = Manager.disband(created.guild_id, "gm_action")

      assert Repo.get(Character, master.id).guild_exp == 0
    end
  end

  describe "notice author" do
    test "an edit records the editor's name and the edit time, and both survive a rebuild" do
      {master, created} = guild_fixture("NoticeAuthor")
      assert created.notice_author == ""
      assert created.notice_posted_at == 0

      before = System.os_time(:second)

      assert {:ok, state} =
               Manager.set_notice(created.guild_id, master.id, %{subject: "s", body: "b"})

      assert state.notice_author == master.name
      assert state.notice_posted_at >= before

      ClusterTestHelper.clear_all()
      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert rebuilt.notice_author == master.name
      assert rebuilt.notice_posted_at == state.notice_posted_at
    end

    test "a member whose position grants can_notice edits the notice" do
      {master, created} = guild_fixture("NoticeGranted")
      member = insert(:character, name: "NoticeScribe")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      {:ok, _} =
        Manager.edit_position(created.guild_id, master.id, %{
          index: @newbie_position,
          name: "Scribe",
          can_invite: false,
          can_expel: false,
          can_notice: true
        })

      assert {:ok, state} =
               Manager.set_notice(created.guild_id, member.id, %{subject: "s", body: "b"})

      assert state.notice_author == member.name
    end
  end

  describe "edit_position/3 notice and relations flags" do
    test "sets and persists both flags, and an edit that omits them leaves them unchanged" do
      {master, created} = guild_fixture("FlagEditors")

      assert {:ok, state} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 5,
                 name: "Diplomat",
                 can_invite: false,
                 can_expel: false,
                 can_notice: true,
                 can_relations: true
               })

      assert %{can_notice: true, can_relations: true} = state.positions[5]
      row = Repo.get_by(GuildPosition, guild_id: created.guild_id, index: 5)
      assert row.can_notice and row.can_relations

      assert {:ok, state} =
               Manager.edit_position(created.guild_id, master.id, %{
                 index: 5,
                 name: "Envoy",
                 can_invite: false,
                 can_expel: false,
                 can_notice: nil,
                 can_relations: false
               })

      assert %{name: "Envoy", can_notice: true, can_relations: false} = state.positions[5]
    end

    test "new guilds seed every position without either flag" do
      {_master, created} = guild_fixture("FlagDefaults")

      refute Enum.any?(Map.values(created.positions), &(&1.can_notice or &1.can_relations))
    end
  end

  describe "activity log" do
    test "founding is the guild's first entry, with the founder as actor" do
      {master, created} = guild_fixture("LogFounded")
      founder = master.name

      assert [%Activity{kind: :created, actor: ^founder, at: at}] = created.activity
      assert at > 0
    end

    test "membership and position changes are logged newest first and survive a rebuild" do
      {master, created} = guild_fixture("LogMembers")
      joiner = insert(:character, name: "LogJoiner")
      expelled = insert(:character, name: "LogExpelled")
      {:ok, _} = Manager.add_member(created.guild_id, joiner, master.id)
      {:ok, _} = Manager.add_member(created.guild_id, expelled)

      {:ok, _} =
        Manager.edit_position(created.guild_id, master.id, %{
          index: 3,
          name: "Officer",
          can_invite: true,
          can_expel: false
        })

      {:ok, _} = Manager.assign_member_position(created.guild_id, master.id, joiner.id, 3)
      {:ok, _} = Manager.expel(created.guild_id, master.id, expelled.id, "spam")
      {:ok, state} = Manager.remove_member(created.guild_id, joiner.id)

      founder = master.name
      joiner_name = joiner.name
      expelled_name = expelled.name

      assert [
               %Activity{kind: :left, subject: ^joiner_name, actor: ""},
               %Activity{kind: :expelled, subject: ^expelled_name, actor: ^founder},
               %Activity{
                 kind: :position_changed,
                 subject: ^joiner_name,
                 actor: ^founder,
                 detail: "Officer"
               },
               %Activity{kind: :joined, subject: ^expelled_name, actor: ""},
               %Activity{kind: :joined, subject: ^joiner_name, actor: ^founder},
               %Activity{kind: :created}
             ] = state.activity

      ClusterTestHelper.clear_all()
      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert rebuilt.activity == state.activity
    end

    test "re-assigning a member to the position it already holds logs nothing" do
      {master, created} = guild_fixture("LogSamePosition")
      joiner = insert(:character, name: "LogStays")
      {:ok, joined} = Manager.add_member(created.guild_id, joiner)

      {:ok, state} =
        Manager.assign_member_position(created.guild_id, master.id, joiner.id, @newbie_position)

      assert state.activity == joined.activity
    end

    test "a raised guild skill is logged with the master, the skill and its new level" do
      {master, created} = guild_fixture("LogSkill")

      {1, nil} =
        from(g in GuildModel, where: g.id == ^created.guild_id)
        |> Repo.update_all(set: [skill_points: 1])

      ClusterTestHelper.clear_all()
      {:ok, _} = Manager.ensure_started(created.guild_id)

      {:ok, state} = Manager.allocate_skill_point(created.guild_id, master.id, 10_000)

      founder = master.name

      assert [%Activity{kind: :skill_learned, actor: ^founder, skill_id: 10_000, level: 1} | _] =
               state.activity
    end

    test "the entry keeps only the newest 30 entries" do
      {_master, created} = guild_fixture("LogCapped")

      for n <- 1..31 do
        :ok = Manager.record_activity(created.guild_id, :castle_taken, %{subject: "Castle #{n}"})
      end

      {:ok, state} = Manager.get(created.guild_id)
      assert length(state.activity) == 30
      assert %Activity{subject: "Castle 31"} = hd(state.activity)
      refute Enum.any?(state.activity, &(&1.kind == :created))
    end

    test "record_activity/3 broadcasts the updated state of a live entry" do
      {_master, created} = guild_fixture("LogBroadcast")
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert :ok =
               Manager.record_activity(created.guild_id, :castle_lost, %{subject: "Kriemhild"})

      assert_receive {:social,
                      {:guild_updated,
                       %State{activity: [%Activity{kind: :castle_lost, subject: "Kriemhild"} | _]}}}
    end

    test "record_activity/3 still writes the row of a guild whose entry is not running" do
      {_master, created} = guild_fixture("LogOffline")
      ClusterTestHelper.clear_all()

      assert :ok =
               Manager.record_activity(created.guild_id, :castle_lost, %{subject: "Kriemhild"})

      assert {:ok, rebuilt} = Manager.ensure_started(created.guild_id)
      assert [%Activity{kind: :castle_lost, subject: "Kriemhild"} | _] = rebuilt.activity
    end

    test "disbanding deletes the guild's rows and logs the lost relation on its peers" do
      {_master, disbanded} = guild_fixture("LogDisbanded")
      {_ally_master, ally} = guild_fixture("LogDisbandAlly")
      {_foe_master, foe} = guild_fixture("LogDisbandFoe")
      assert :ok = Relations.ally(disbanded.guild_id, ally.guild_id)
      assert :ok = Relations.declare_antagonist(foe.guild_id, disbanded.guild_id)

      assert :ok = Manager.disband(disbanded.guild_id, "gm_action")

      assert Repo.aggregate(
               from(a in GuildActivityLog, where: a.guild_id == ^disbanded.guild_id),
               :count
             ) == 0

      name = disbanded.name
      {:ok, ally_state} = Manager.get(ally.guild_id)
      assert [%Activity{kind: :alliance_broken, subject: ^name} | _] = ally_state.activity
      {:ok, foe_state} = Manager.get(foe.guild_id)
      assert [%Activity{kind: :antagonist_removed, subject: ^name} | _] = foe_state.activity
    end
  end
end
