defmodule Aesir.ZoneServer.Guild.RelationsTest do
  use Aesir.DataCase, async: false
  use Mimic

  import Ecto.Query

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.GuildRelation
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Relation
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer

  setup :verify_on_exit!
  setup :set_mimic_from_context

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

  defp char_fixture(name) do
    account = account_fixture(name)

    {:ok, character} =
      %{account_id: account.id, name: name, char_num: 0, class: 0, base_level: 1}
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp guild_fixture(master_name) do
    master = char_fixture(master_name)
    {:ok, state} = Manager.create("Guild-#{master_name}", master)
    state.guild_id
  end

  defp relation_rows(guild_id) do
    GuildRelation |> where([r], r.guild_id == ^guild_id) |> Repo.all()
  end

  defp relation_row(guild_id, other_guild_id) do
    Repo.one(
      where(
        GuildRelation,
        [r],
        r.guild_id == ^guild_id and r.other_guild_id == ^other_guild_id
      )
    )
  end

  defp total_relation_count do
    Repo.aggregate(GuildRelation, :count)
  end

  describe "allied?/2" do
    test "false for nil, 0, and equal ids" do
      refute Relations.allied?(nil, 5)
      refute Relations.allied?(5, nil)
      refute Relations.allied?(0, 5)
      refute Relations.allied?(5, 0)
      refute Relations.allied?(5, 5)
    end

    test "true from either side once allied, false for unrelated guilds" do
      a = guild_fixture("AlliedA")
      b = guild_fixture("AlliedB")
      c = guild_fixture("AlliedC")

      assert :ok = Relations.ally(a, b)

      assert Relations.allied?(a, b)
      assert Relations.allied?(b, a)
      refute Relations.allied?(a, c)
    end
  end

  describe "friendly?/2" do
    test "true for equal nonzero ids, false for equal nil/zero" do
      assert Relations.friendly?(7, 7)
      refute Relations.friendly?(nil, nil)
      refute Relations.friendly?(0, 0)
    end

    test "defers to allied?/2 for distinct ids" do
      a = guild_fixture("FriendlyA")
      b = guild_fixture("FriendlyB")

      refute Relations.friendly?(a, b)
      assert :ok = Relations.ally(a, b)
      assert Relations.friendly?(a, b)
    end
  end

  describe "load/1" do
    test "empty map for a guild with no relation rows" do
      a = guild_fixture("LoadEmpty")
      assert Relations.load(a) == %{}
    end

    test "maps the other guild id to a Relation struct" do
      a = guild_fixture("LoadA")
      b = guild_fixture("LoadB")
      assert :ok = Relations.ally(a, b)

      assert %{^b => %Relation{guild_id: ^b, name: "Guild-LoadB", kind: :ally}} =
               Relations.load(a)
    end
  end

  describe "request_check/2" do
    test ":same_guild when both ids are equal" do
      a = guild_fixture("CheckSame")
      assert {:error, :same_guild} = Relations.request_check(a, a)
    end

    test ":not_found when a guild row is missing" do
      a = guild_fixture("CheckReal")
      assert {:error, :not_found} = Relations.request_check(a, a + 1_000_000)
    end

    test ":siege_active when a siege is active" do
      a = guild_fixture("CheckSiegeA")
      b = guild_fixture("CheckSiegeB")
      stub(WoeServer, :active?, fn -> true end)

      assert {:error, :siege_active} = Relations.request_check(a, b)
    end

    test ":already_allied when an ally row exists in either direction" do
      a = guild_fixture("CheckAllyA")
      b = guild_fixture("CheckAllyB")
      assert :ok = Relations.ally(a, b)

      assert {:error, :already_allied} = Relations.request_check(a, b)
      assert {:error, :already_allied} = Relations.request_check(b, a)
    end

    test ":ally_limit when either guild already has 3 allies" do
      a = guild_fixture("CheckLimitA")
      [b, c, d, e] = for n <- 1..4, do: guild_fixture("CheckLimitPeer#{n}")
      assert :ok = Relations.ally(a, b)
      assert :ok = Relations.ally(a, c)
      assert :ok = Relations.ally(a, d)

      assert {:error, :ally_limit} = Relations.request_check(a, e)
    end

    test ":ok when nothing refuses the request" do
      a = guild_fixture("CheckOkA")
      b = guild_fixture("CheckOkB")
      assert :ok = Relations.request_check(a, b)
    end
  end

  describe "ally/2" do
    test "creates symmetric ally rows, updates both live entries, and broadcasts" do
      a = guild_fixture("AllyHappyA")
      b = guild_fixture("AllyHappyB")

      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{a}")
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{b}")

      assert :ok = Relations.ally(a, b)

      assert %GuildRelation{kind: "ally", other_name: "Guild-AllyHappyB"} =
               relation_row(a, b)

      assert %GuildRelation{kind: "ally", other_name: "Guild-AllyHappyA"} =
               relation_row(b, a)

      assert {:ok, %State{relations: %{^b => %Relation{kind: :ally}}}} = Manager.get(a)
      assert {:ok, %State{relations: %{^a => %Relation{kind: :ally}}}} = Manager.get(b)

      assert_receive {:social, {:guild_updated, %State{guild_id: ^a}}}
      assert_receive {:social, {:guild_updated, %State{guild_id: ^b}}}
    end

    test "removes antagonist rows in both directions" do
      a = guild_fixture("AllyClearsA")
      b = guild_fixture("AllyClearsB")
      assert :ok = Relations.declare_antagonist(a, b)
      assert :ok = Relations.declare_antagonist(b, a)

      assert :ok = Relations.ally(a, b)

      refute relation_row(a, b) && relation_row(a, b).kind == "antagonist"
      refute relation_row(b, a) && relation_row(b, a).kind == "antagonist"
      assert relation_row(a, b).kind == "ally"
      assert relation_row(b, a).kind == "ally"
    end

    test "refuses :same_guild and writes nothing" do
      a = guild_fixture("AllySameA")
      before = total_relation_count()

      assert {:error, :same_guild} = Relations.ally(a, a)
      assert total_relation_count() == before
    end

    test "refuses :siege_active and writes nothing" do
      a = guild_fixture("AllySiegeA")
      b = guild_fixture("AllySiegeB")
      before = total_relation_count()
      stub(WoeServer, :active?, fn -> true end)

      assert {:error, :siege_active} = Relations.ally(a, b)
      assert total_relation_count() == before
    end

    test "refuses :already_allied and writes nothing further" do
      a = guild_fixture("AllyDupA")
      b = guild_fixture("AllyDupB")
      assert :ok = Relations.ally(a, b)
      before = total_relation_count()

      assert {:error, :already_allied} = Relations.ally(a, b)
      assert total_relation_count() == before
    end

    test "the fourth ally fails with :ally_limit and writes nothing" do
      a = guild_fixture("AllyLimitA")
      [b, c, d, e] = for n <- 1..4, do: guild_fixture("AllyLimitPeer#{n}")
      assert :ok = Relations.ally(a, b)
      assert :ok = Relations.ally(a, c)
      assert :ok = Relations.ally(a, d)
      before = total_relation_count()

      assert {:error, :ally_limit} = Relations.ally(a, e)
      assert total_relation_count() == before
      assert length(relation_rows(a)) == 3
    end

    test "refuses :not_found for a missing guild and writes nothing" do
      a = guild_fixture("AllyMissingA")
      before = total_relation_count()

      assert {:error, :not_found} = Relations.ally(a, a + 1_000_000)
      assert total_relation_count() == before
    end
  end

  describe "break/2" do
    test "deletes both ally rows" do
      a = guild_fixture("BreakA")
      b = guild_fixture("BreakB")
      assert :ok = Relations.ally(a, b)

      assert :ok = Relations.break(a, b)

      assert relation_row(a, b) == nil
      assert relation_row(b, a) == nil
      refute Relations.allied?(a, b)
    end

    test "refuses :not_related when no ally row exists and writes nothing" do
      a = guild_fixture("BreakNoneA")
      b = guild_fixture("BreakNoneB")

      assert {:error, :not_related} = Relations.break(a, b)
    end

    test "refuses :siege_active and leaves the alliance intact" do
      a = guild_fixture("BreakSiegeA")
      b = guild_fixture("BreakSiegeB")
      assert :ok = Relations.ally(a, b)
      stub(WoeServer, :active?, fn -> true end)

      assert {:error, :siege_active} = Relations.break(a, b)
      assert relation_row(a, b).kind == "ally"
    end
  end

  describe "declare_antagonist/2" do
    test "inserts a single a -> b row" do
      a = guild_fixture("AntagHappyA")
      b = guild_fixture("AntagHappyB")

      assert :ok = Relations.declare_antagonist(a, b)

      assert %GuildRelation{kind: "antagonist", other_name: "Guild-AntagHappyB"} =
               relation_row(a, b)

      assert relation_row(b, a) == nil
      assert {:ok, %State{relations: %{^b => %Relation{kind: :antagonist}}}} = Manager.get(a)
    end

    test "refuses :same_guild" do
      a = guild_fixture("AntagSameA")
      assert {:error, :same_guild} = Relations.declare_antagonist(a, a)
    end

    test "refuses :already_antagonist and writes nothing further" do
      a = guild_fixture("AntagDupA")
      b = guild_fixture("AntagDupB")
      assert :ok = Relations.declare_antagonist(a, b)
      before = total_relation_count()

      assert {:error, :already_antagonist} = Relations.declare_antagonist(a, b)
      assert total_relation_count() == before
    end

    test "replaces an existing alliance outside a siege" do
      a = guild_fixture("AntagConvertA")
      b = guild_fixture("AntagConvertB")
      assert :ok = Relations.ally(a, b)

      assert :ok = Relations.declare_antagonist(a, b)

      assert relation_row(a, b).kind == "antagonist"
      assert relation_row(b, a) == nil
      refute Relations.allied?(a, b)
    end

    test "refuses :siege_active against an existing alliance and leaves it intact" do
      a = guild_fixture("AntagSiegeA")
      b = guild_fixture("AntagSiegeB")
      assert :ok = Relations.ally(a, b)
      stub(WoeServer, :active?, fn -> true end)

      assert {:error, :siege_active} = Relations.declare_antagonist(a, b)
      assert relation_row(a, b).kind == "ally"
      assert relation_row(b, a).kind == "ally"
    end

    test "the fourth antagonist fails with :antagonist_limit and writes nothing" do
      a = guild_fixture("AntagLimitA")
      [b, c, d, e] = for n <- 1..4, do: guild_fixture("AntagLimitPeer#{n}")
      assert :ok = Relations.declare_antagonist(a, b)
      assert :ok = Relations.declare_antagonist(a, c)
      assert :ok = Relations.declare_antagonist(a, d)
      before = total_relation_count()

      assert {:error, :antagonist_limit} = Relations.declare_antagonist(a, e)
      assert total_relation_count() == before
      assert length(relation_rows(a)) == 3
    end
  end

  describe "remove_antagonist/2" do
    test "deletes the a -> b antagonist row" do
      a = guild_fixture("RemoveAntagA")
      b = guild_fixture("RemoveAntagB")
      assert :ok = Relations.declare_antagonist(a, b)

      assert :ok = Relations.remove_antagonist(a, b)

      assert relation_row(a, b) == nil
    end

    test "refuses :not_related when no antagonist row exists" do
      a = guild_fixture("RemoveAntagNoneA")
      b = guild_fixture("RemoveAntagNoneB")

      assert {:error, :not_related} = Relations.remove_antagonist(a, b)
    end
  end
end
