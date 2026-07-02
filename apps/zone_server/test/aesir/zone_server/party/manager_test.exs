defmodule Aesir.ZoneServer.Party.ManagerTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Party
  alias Aesir.Repo
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Party.State

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

  defp leader_fixture(name, attrs \\ %{}) do
    account = account_fixture(name)
    character_fixture(Map.merge(%{account_id: account.id, name: name}, attrs))
  end

  defp party_fixture(leader_name) do
    leader = leader_fixture(leader_name)
    {:ok, state} = Manager.create("Party-#{leader_name}", leader)
    {leader, state}
  end

  describe "create/2" do
    test "persists a parties row, sets the leader's party_id, and starts a running entry" do
      leader = leader_fixture("Alice")

      assert {:ok, %State{} = state} = Manager.create("Vanguard", leader)
      assert state.name == "Vanguard"
      assert state.leader_char_id == leader.id
      assert state.exp_share == false
      member = Map.fetch!(state.members, leader.id)
      assert member.online == true
      assert member.base_level == leader.base_level

      assert Repo.get_by(Aesir.Commons.Models.Party, name: "Vanguard")
      assert Repo.get(Character, leader.id).party_id == state.party_id

      assert {:ok, ^state} = Manager.get(state.party_id)
    end

    test "duplicate name returns {:error, :name_taken} and performs no partial writes" do
      leader1 = leader_fixture("Bobby")
      leader2 = leader_fixture("Carol")

      assert {:ok, _state} = Manager.create("Sameteam", leader1)
      assert {:error, :name_taken} = Manager.create("Sameteam", leader2)

      reloaded_leader2 = Repo.get(Character, leader2.id)
      assert reloaded_leader2.party_id == 0

      assert Repo.aggregate(
               Ecto.Query.from(p in Aesir.Commons.Models.Party, where: p.name == "Sameteam"),
               :count
             ) == 1
    end
  end

  describe "ensure_started/1" do
    test "rebuilds an entry from DB when none is running" do
      leader = leader_fixture("Dave")
      {:ok, created} = Manager.create("Rebuildable", leader)

      ClusterTestHelper.clear_all()
      assert {:error, :not_found} = Manager.get(created.party_id)

      assert {:ok, rebuilt} = Manager.ensure_started(created.party_id)
      assert rebuilt.party_id == created.party_id
      assert rebuilt.name == "Rebuildable"
      assert rebuilt.leader_char_id == leader.id

      member = Map.fetch!(rebuilt.members, leader.id)
      assert member.online == false
      assert member.base_level == leader.base_level
    end

    test "is a no-op when an entry is already running" do
      leader = leader_fixture("Erin")
      {:ok, created} = Manager.create("AlreadyRunning", leader)

      assert {:ok, state} = Manager.ensure_started(created.party_id)
      assert state == created
    end

    test "returns {:error, :not_found} when no party row exists" do
      assert {:error, :not_found} = Manager.ensure_started(999_999)
    end

    test "concurrent calls racing to rebuild the same not-yet-started party both succeed" do
      leader = leader_fixture("Heidi")
      {:ok, created} = Manager.create("Racing", leader)

      ClusterTestHelper.clear_all()
      assert {:error, :not_found} = Manager.get(created.party_id)

      [result_a, result_b] =
        [
          Task.async(fn -> Manager.ensure_started(created.party_id) end),
          Task.async(fn -> Manager.ensure_started(created.party_id) end)
        ]
        |> Task.await_many()

      assert {:ok, %State{party_id: party_id_a}} = result_a
      assert {:ok, %State{party_id: party_id_b}} = result_b
      assert party_id_a == created.party_id
      assert party_id_b == created.party_id
    end
  end

  describe "disband/2" do
    test "deletes the row, resets every member's party_id, and removes the entry" do
      leader = leader_fixture("Frank")
      {:ok, created} = Manager.create("Doomed", leader)

      assert :ok = Manager.disband(created.party_id, "leader_left")

      assert {:error, :not_found} = Manager.get(created.party_id)
      assert Repo.get(Aesir.Commons.Models.Party, created.party_id) == nil
      assert Repo.get(Character, leader.id).party_id == 0
    end

    test "broadcasts {:party_disbanded, party_id, reason} on the party topic" do
      leader = leader_fixture("Grace")
      {:ok, created} = Manager.create("Broadcasting", leader)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{created.party_id}")

      assert :ok = Manager.disband(created.party_id, "leader_left")

      party_id = created.party_id
      assert_receive {:party_disbanded, ^party_id, "leader_left"}
    end

    test "returns {:error, :not_found} when no entry is running" do
      assert {:error, :not_found} = Manager.disband(999_999, "leader_left")
    end
  end

  describe "add_member/2" do
    test "adds the member, persists party_id, and broadcasts {:party_updated, state}" do
      {_leader, created} = party_fixture("Ivan")
      joiner = leader_fixture("Judy")

      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{created.party_id}")

      assert {:ok, state} = Manager.add_member(created.party_id, joiner)
      member = Map.fetch!(state.members, joiner.id)
      assert member.online == true
      assert member.base_level == joiner.base_level

      assert Repo.get(Character, joiner.id).party_id == created.party_id
      assert_receive {:party_updated, ^state}
    end

    test "rejects a same-account character without mutating state" do
      {leader, created} = party_fixture("Karl")

      alt =
        character_fixture(%{account_id: leader.account_id, name: "KarlAlt", char_num: 1})

      assert {:error, :same_account} = Manager.add_member(created.party_id, alt)

      assert {:ok, state} = Manager.get(created.party_id)
      refute Map.has_key?(state.members, alt.id)
      assert Repo.get(Character, alt.id).party_id == 0
    end

    test "rejects a full party without mutating state" do
      {_leader, created} = party_fixture("Liam")

      full_state =
        Enum.reduce(2..Config.max_party(), created, fn n, acc ->
          joiner = leader_fixture("Liam#{n}")
          {:ok, state} = Manager.add_member(acc.party_id, joiner)
          state
        end)

      overflow = leader_fixture("Overflow")

      assert {:error, :party_full} = Manager.add_member(full_state.party_id, overflow)
      assert Repo.get(Character, overflow.id).party_id == 0
    end

    test "returns {:error, :not_found} when no party entry is running" do
      joiner = leader_fixture("MiaSolo")

      assert {:error, :not_found} = Manager.add_member(999_999, joiner)
    end

    test "two concurrent adds into the last slot yield exactly one success and one party_full" do
      {_leader, created} = party_fixture("Nora")

      filled_state =
        Enum.reduce(2..(Config.max_party() - 1), created, fn n, acc ->
          joiner = leader_fixture("Nora#{n}")
          {:ok, state} = Manager.add_member(acc.party_id, joiner)
          state
        end)

      joiner_a = leader_fixture("RaceA")
      joiner_b = leader_fixture("RaceB")

      [result_a, result_b] =
        [
          Task.async(fn -> Manager.add_member(filled_state.party_id, joiner_a) end),
          Task.async(fn -> Manager.add_member(filled_state.party_id, joiner_b) end)
        ]
        |> Task.await_many()

      results = [result_a, result_b]
      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, :party_full}, &1)) == 1
    end
  end

  describe "remove_member/2" do
    test "drops a non-leader member, resets party_id, and broadcasts {:party_updated, state}" do
      {_leader, created} = party_fixture("Oscar")
      joiner = leader_fixture("Peggy")
      {:ok, joined} = Manager.add_member(created.party_id, joiner)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{joined.party_id}")

      assert {:ok, state} = Manager.remove_member(joined.party_id, joiner.id)
      refute Map.has_key?(state.members, joiner.id)
      assert Repo.get(Character, joiner.id).party_id == 0
      assert_receive {:party_updated, ^state}
    end

    test "removing the leader disbands the party" do
      {leader, created} = party_fixture("Quinn")

      assert :ok = Manager.remove_member(created.party_id, leader.id)
      assert {:error, :not_found} = Manager.get(created.party_id)
      assert Repo.get(Character, leader.id).party_id == 0
    end

    test "returns {:error, :not_found} when no party entry is running" do
      assert {:error, :not_found} = Manager.remove_member(999_999, 1)
    end

    test "old leader leaving after a leadership transfer does not disband the party" do
      {leader, created} = party_fixture("Xavier")
      target = leader_fixture("Yolanda")
      {:ok, joined} = Manager.add_member(created.party_id, target)

      assert {:ok, transferred} = Manager.transfer_leader(joined.party_id, leader.id, target.id)
      assert transferred.leader_char_id == target.id

      assert {:ok, state} = Manager.remove_member(transferred.party_id, leader.id)
      refute Map.has_key?(state.members, leader.id)
      assert state.leader_char_id == target.id
      assert {:ok, ^state} = Manager.get(transferred.party_id)
      assert Repo.get(Character, leader.id).party_id == 0
    end
  end

  describe "kick/3" do
    test "succeeds for an offline target and broadcasts {:party_updated, state}" do
      {leader, created} = party_fixture("Randy")
      target = leader_fixture("Sybil")
      {:ok, joined} = Manager.add_member(created.party_id, target)
      force_member(joined.party_id, target.id, online: false)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{joined.party_id}")

      assert {:ok, state} = Manager.kick(joined.party_id, leader.id, target.id)
      refute Map.has_key?(state.members, target.id)
      assert Repo.get(Character, target.id).party_id == 0
      assert_receive {:party_updated, ^state}
    end

    test "rejects a non-leader requester" do
      {_leader, created} = party_fixture("Trent")
      member = leader_fixture("Ursula")
      {:ok, joined} = Manager.add_member(created.party_id, member)

      assert {:error, :not_leader} = Manager.kick(joined.party_id, member.id, member.id)
      assert Repo.get(Character, member.id).party_id == joined.party_id
    end

    test "rejects a target that is not a member" do
      {leader, created} = party_fixture("Victor")

      assert {:error, :not_member} = Manager.kick(created.party_id, leader.id, 999_999)
    end

    test "the leader kicking themselves disbands the party" do
      {leader, created} = party_fixture("Wendy")

      assert :ok = Manager.kick(created.party_id, leader.id, leader.id)
      assert {:error, :not_found} = Manager.get(created.party_id)
    end

    test "returns {:error, :not_found} when no party entry is running" do
      assert {:error, :not_found} = Manager.kick(999_999, 1, 2)
    end
  end

  describe "transfer_leader/3" do
    defp force_member(party_id, char_id, attrs) do
      [{pid, _value}] = Horde.Registry.lookup(Cluster.registry(), {:party, party_id})

      Entry.update(pid, fn %State{} = state ->
        member = Map.fetch!(state.members, char_id)
        %State{state | members: Map.put(state.members, char_id, struct(member, attrs))}
      end)
    end

    test "swaps the leader for an online same-map target and broadcasts" do
      {leader, created} = party_fixture("Xena")
      target = leader_fixture("Yusuf")
      {:ok, joined} = Manager.add_member(created.party_id, target)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{joined.party_id}")

      assert {:ok, state} = Manager.transfer_leader(joined.party_id, leader.id, target.id)
      assert state.leader_char_id == target.id
      assert Repo.get(Party, joined.party_id).leader_char_id == target.id
      assert_receive {:party_updated, ^state}
    end

    test "rejects an offline target" do
      {leader, created} = party_fixture("Zane")
      target = leader_fixture("Yara")
      {:ok, joined} = Manager.add_member(created.party_id, target)
      force_member(joined.party_id, target.id, online: false)

      assert {:error, :not_same_map} =
               Manager.transfer_leader(joined.party_id, leader.id, target.id)
    end

    test "rejects a target on a different map" do
      {leader, created} = party_fixture("Abel")
      target = leader_fixture("Beth")
      {:ok, joined} = Manager.add_member(created.party_id, target)
      force_member(joined.party_id, target.id, map_name: "geffen")

      assert {:error, :not_same_map} =
               Manager.transfer_leader(joined.party_id, leader.id, target.id)
    end

    test "rejects a non-leader requester" do
      {_leader, created} = party_fixture("Cleo")
      target = leader_fixture("Dagny")
      {:ok, joined} = Manager.add_member(created.party_id, target)

      assert {:error, :not_leader} =
               Manager.transfer_leader(joined.party_id, target.id, target.id)
    end

    test "rejects a target that is not a member" do
      {leader, created} = party_fixture("Elke")

      assert {:error, :not_member} = Manager.transfer_leader(created.party_id, leader.id, 999_999)
    end

    test "returns {:error, :not_found} when no party entry is running" do
      assert {:error, :not_found} = Manager.transfer_leader(999_999, 1, 2)
    end
  end

  describe "set_options/3" do
    test "leader can toggle exp_share on within the level-spread boundary and it broadcasts" do
      {leader, created} = party_fixture("Felix")
      target = leader_fixture("Greta", %{base_level: 1 + Config.party_share_level()})
      {:ok, joined} = Manager.add_member(created.party_id, target)

      Phoenix.PubSub.subscribe(Aesir.PubSub, "party:#{joined.party_id}")

      assert {:ok, state} = Manager.set_options(joined.party_id, leader.id, true)
      assert state.exp_share == true
      assert Repo.get(Party, joined.party_id).exp_share == true
      assert_receive {:party_updated, ^state}
    end

    test "rejects enabling exp_share when the online level spread exceeds party_share_level" do
      {leader, created} = party_fixture("Harlan")
      target = leader_fixture("Ines", %{base_level: 2 + Config.party_share_level()})
      {:ok, joined} = Manager.add_member(created.party_id, target)

      assert {:error, :level_range} = Manager.set_options(joined.party_id, leader.id, true)
      assert Repo.get(Party, joined.party_id).exp_share == false
    end

    test "rejects a non-leader requester" do
      {_leader, created} = party_fixture("Jarod")
      target = leader_fixture("Kiona")
      {:ok, joined} = Manager.add_member(created.party_id, target)

      assert {:error, :not_leader} = Manager.set_options(joined.party_id, target.id, true)
    end

    test "returns {:error, :not_found} when no party entry is running" do
      assert {:error, :not_found} = Manager.set_options(999_999, 1, true)
    end
  end
end
