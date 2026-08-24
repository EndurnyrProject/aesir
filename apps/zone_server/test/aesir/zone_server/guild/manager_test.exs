defmodule Aesir.ZoneServer.Guild.ManagerTest do
  use Aesir.DataCase, async: false

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildExpulsion
  alias Aesir.Commons.Models.GuildPosition
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State

  @newbie_position 19
  @max_members 16

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp account_fixture(userid) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@example.com"
      })
      |> Repo.insert()

    account
  end

  defp character_fixture(attrs) do
    {:ok, character} =
      attrs
      |> Enum.into(%{char_num: 0, class: 0, base_level: 1})
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp char_fixture(name, attrs \\ %{}) do
    account = account_fixture(name)
    character_fixture(Map.merge(%{account_id: account.id, name: name}, attrs))
  end

  defp guild_fixture(master_name) do
    master = char_fixture(master_name)
    {:ok, state} = Manager.create("Guild-#{master_name}", master)
    {master, state}
  end

  defp fill_to(state, count, prefix) do
    Enum.reduce((State.member_count(state) + 1)..count, state, fn n, acc ->
      joiner = char_fixture("#{prefix}#{n}")
      {:ok, next} = Manager.add_member(acc.guild_id, joiner)
      next
    end)
  end

  describe "create/2" do
    test "persists guild + 20 positions + master at guild_id/position 0 and starts an entry" do
      master = char_fixture("Founder", %{class: 7, base_level: 50, hp: 500, max_hp: 1_000})

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
      master1 = char_fixture("Owner1")
      master2 = char_fixture("Owner2")

      assert {:ok, _state} = Manager.create("SameName", master1)
      assert {:error, :name_taken} = Manager.create("SameName", master2)

      reloaded = Repo.get(Character, master2.id)
      assert reloaded.guild_id == 0
      assert reloaded.guild_position == 0

      assert Repo.aggregate(from(g in GuildModel, where: g.name == "SameName"), :count) == 1
    end

    test "blank name returns {:error, :invalid_name}" do
      master = char_fixture("Blankster")
      assert {:error, :invalid_name} = Manager.create("   ", master)
    end
  end

  describe "ensure_started/1" do
    test "rebuilds guild + positions + offline members from the DB" do
      master = char_fixture("RebuildMaster", %{class: 9, base_level: 40, last_map: "geffen"})
      {:ok, created} = Manager.create("Rebuildable", master)
      joiner = char_fixture("RebuildJoiner")
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
      assert rebuilt.skill_cooldowns == %{}
    end
  end

  describe "add_member/2" do
    test "joins at the Newbie position, persists, and broadcasts {:guild_updated, state}" do
      {_master, created} = guild_fixture("Joiners")
      joiner = char_fixture("Newcomer")

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

      overflow = char_fixture("Overflow")
      assert {:error, :guild_full} = Manager.add_member(full.guild_id, overflow)
      assert Repo.get(Character, overflow.id).guild_id == 0
    end

    test "returns {:error, :not_found} when no entry is running" do
      joiner = char_fixture("SoloJoin")
      assert {:error, :not_found} = Manager.add_member(999_999, joiner)
    end

    test "two concurrent adds into the last slot yield one success and one guild_full" do
      {_master, created} = guild_fixture("Race")
      filled = fill_to(created, @max_members - 1, "Race")

      a = char_fixture("RaceA")
      b = char_fixture("RaceB")

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

  describe "remove_member/2" do
    test "drops a non-master member and resets its row" do
      {_master, created} = guild_fixture("Leavers")
      joiner = char_fixture("Quitter")
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
      joiner = char_fixture("Follower")
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
      joiner = char_fixture("DoomedMember")
      {:ok, _joined} = Manager.add_member(created.guild_id, joiner)
      other = char_fixture("Expelled")
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

    test "returns {:error, :not_found} when no entry is running" do
      assert {:error, :not_found} = Manager.disband(999_999, "gm_action")
    end
  end

  describe "expel/4" do
    test "master expels a member, resets the row, and writes exactly one expulsion" do
      {master, created} = guild_fixture("Expellers")
      target = char_fixture("Troublemaker")
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
      member = char_fixture("Powerless")
      {:ok, _} = Manager.add_member(created.guild_id, member)
      target = char_fixture("Victim")
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
      officer = char_fixture("Officer")
      {:ok, _} = Manager.add_member(created.guild_id, officer)
      target = char_fixture("Doomed2")
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
      member = char_fixture("NotMaster")
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
      member = char_fixture("Grunt")
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
      member = char_fixture("Peon")
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
      member = char_fixture("Climber")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:ok, state} =
               Manager.assign_member_position(created.guild_id, master.id, member.id, 4)

      assert Map.fetch!(state.members, member.id).position_index == 4
      assert Repo.get(Character, member.id).guild_position == 4
    end

    test "denies a non-master" do
      {_master, created} = guild_fixture("AssignGate")
      member = char_fixture("Nobody")
      {:ok, _} = Manager.add_member(created.guild_id, member)
      other = char_fixture("Other")
      {:ok, _} = Manager.add_member(created.guild_id, other)

      assert {:error, :no_permission} =
               Manager.assign_member_position(created.guild_id, member.id, other.id, 3)
    end

    test "rejects an out-of-range index" do
      {master, created} = guild_fixture("RangeCheck")
      member = char_fixture("Ranged")
      {:ok, _} = Manager.add_member(created.guild_id, member)

      assert {:error, :invalid_position} =
               Manager.assign_member_position(created.guild_id, master.id, member.id, 20)
    end
  end

  describe "presence" do
    test "push_base_level updates the member and broadcasts" do
      {master, created} = guild_fixture("Levelers")

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{created.guild_id}")

      assert {:ok, state} = Manager.push_base_level(created.guild_id, master.id, 99)
      assert Map.fetch!(state.members, master.id).base_level == 99
      assert_receive {:social, {:guild_updated, ^state}}
    end

    test "push_map_change updates the member map" do
      {master, created} = guild_fixture("Movers")
      assert {:ok, state} = Manager.push_map_change(created.guild_id, master.id, "payon")
      assert Map.fetch!(state.members, master.id).map_name == "payon"
    end

    test "set_online updates the online flag" do
      {master, created} = guild_fixture("Toggles")
      assert {:ok, state} = Manager.set_online(created.guild_id, master.id, false)
      assert Map.fetch!(state.members, master.id).online == false
    end

    test "presence pushes for a non-member return {:error, :not_member}" do
      {_master, created} = guild_fixture("NoMember")
      assert {:error, :not_member} = Manager.push_base_level(created.guild_id, 999_999, 10)
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
  end
end
