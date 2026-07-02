defmodule Aesir.ZoneServer.Party.ManagerTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Repo
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

  defp leader_fixture(name) do
    account = account_fixture(name)
    character_fixture(%{account_id: account.id, name: name})
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
end
