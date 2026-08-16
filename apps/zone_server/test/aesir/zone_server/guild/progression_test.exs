defmodule Aesir.ZoneServer.Guild.ProgressionTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.View

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  defp char_fixture(name) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: name,
        user_pass: "password",
        sex: "M",
        email: "#{name}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{account_id: account.id, name: name, char_num: 0, class: 0, base_level: 1}
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp guild_fixture(master_name) do
    master = char_fixture(master_name)
    {:ok, state} = Manager.create("Guild-#{master_name}", master)
    {master, state}
  end

  describe "contribute_exp/2" do
    test "accumulates exp below the first threshold without leveling" do
      {_master, state} = guild_fixture("ExpAccum")

      assert :ok = Manager.contribute_exp(state.guild_id, 99_999)

      {:ok, after_state} = Manager.get(state.guild_id)
      assert after_state.level == 1
      assert after_state.exp == 99_999
      assert after_state.skill_points == 0
    end

    test "crossing a threshold levels up, grants a point, persists, and broadcasts" do
      {_master, state} = guild_fixture("ExpLevel")
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{state.guild_id}")

      assert :ok = Manager.contribute_exp(state.guild_id, 100_005)

      {:ok, after_state} = Manager.get(state.guild_id)
      assert after_state.level == 2
      assert after_state.exp == 5
      assert after_state.skill_points == 1

      row = Repo.get!(GuildModel, state.guild_id)
      assert row.level == 2
      assert row.exp == 5
      assert row.skill_points == 1

      assert_receive {:social, {:guild_level_up, %{level: 2, skill_points: 1}}}
    end

    test "a multi-level jump grants one point per level" do
      {_master, state} = guild_fixture("ExpJump")

      # levels 1 + 2 thresholds (100k + 400k) plus 7 spare
      assert :ok = Manager.contribute_exp(state.guild_id, 500_007)

      {:ok, after_state} = Manager.get(state.guild_id)
      assert after_state.level == 3
      assert after_state.exp == 7
      assert after_state.skill_points == 2
    end

    test "scales contributions by the guild_exp_rate config" do
      {_master, state} = guild_fixture("ExpRate")
      Application.put_env(:zone_server, :guild_exp_rate, 200)
      on_exit(fn -> Application.delete_env(:zone_server, :guild_exp_rate) end)

      assert :ok = Manager.contribute_exp(state.guild_id, 50_000)

      {:ok, after_state} = Manager.get(state.guild_id)
      assert after_state.level == 2
      assert after_state.exp == 0
    end

    test "clamps at the level cap without further level-ups" do
      {_master, state} = guild_fixture("ExpCap")

      {1, nil} =
        from(g in GuildModel, where: g.id == ^state.guild_id)
        |> Repo.update_all(set: [level: 50])

      ClusterTestHelper.clear_all()
      {:ok, _} = Manager.ensure_started(state.guild_id)

      assert :ok = Manager.contribute_exp(state.guild_id, 1_000_000)

      {:ok, after_state} = Manager.get(state.guild_id)
      assert after_state.level == 50
      assert after_state.exp == 0
      assert after_state.skill_points == 0
    end

    test "contribution to an unknown guild is dropped" do
      assert :ok = Manager.contribute_exp(999_999, 1_000)
    end

    test "progression survives an entry restart" do
      {_master, state} = guild_fixture("ExpRestart")
      assert :ok = Manager.contribute_exp(state.guild_id, 100_005)

      ClusterTestHelper.clear_all()
      assert {:ok, rebuilt} = Manager.ensure_started(state.guild_id)
      assert rebuilt.level == 2
      assert rebuilt.exp == 5
      assert rebuilt.skill_points == 1
    end
  end

  describe "View.guild_info/1 progression fields" do
    test "carries level, exp, next_exp, points, and learned skills" do
      {_master, state} = guild_fixture("ViewProg")
      :ok = Manager.contribute_exp(state.guild_id, 100_005)
      {:ok, after_state} = Manager.get(state.guild_id)

      info = View.guild_info(%{after_state | learned_skills: %{10_004 => 3}})

      assert info.level == 2
      assert info.exp == 5
      assert info.next_exp == 400_000
      assert info.skill_points == 1
      assert [%{skill_id: 10_004, level: 3, max_level: 10}] = info.skills
    end

    test "next_exp is 0 at the level cap" do
      {_master, state} = guild_fixture("ViewCap")
      {:ok, guild_state} = Manager.get(state.guild_id)

      info = View.guild_info(%{guild_state | level: 50})
      assert info.next_exp == 0
    end
  end

  defp grant_points(guild_id, points) do
    {1, nil} =
      from(g in GuildModel, where: g.id == ^guild_id)
      |> Repo.update_all(set: [skill_points: points])

    ClusterTestHelper.clear_all()
    {:ok, _} = Manager.ensure_started(guild_id)
    :ok
  end

  describe "allocate_skill_point/3" do
    test "spends a point, learns the skill, persists, and broadcasts" do
      {master, state} = guild_fixture("AllocOk")
      :ok = grant_points(state.guild_id, 2)
      Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{state.guild_id}")

      assert {:ok, after_state} =
               Manager.allocate_skill_point(state.guild_id, master.id, 10_000)

      assert after_state.skill_points == 1
      assert after_state.learned_skills == %{10_000 => 1}

      row = Repo.get!(GuildModel, state.guild_id)
      assert row.skill_points == 1
      assert row.learned_skills == %{"10000" => 1}

      assert_receive {:social, {:guild_skill_update, %{learned_skills: %{10_000 => 1}}}}
      assert_receive {:social, {:guild_updated, _state}}
    end

    test "rejects a non-master caller without mutating" do
      {_master, state} = guild_fixture("AllocNotMaster")
      :ok = grant_points(state.guild_id, 2)

      assert {:error, :not_master} =
               Manager.allocate_skill_point(state.guild_id, 999_999, 10_000)

      {:ok, after_state} = Manager.get(state.guild_id)
      assert after_state.skill_points == 2
      assert after_state.learned_skills == %{}
    end

    test "rejects with no points available" do
      {master, state} = guild_fixture("AllocNoPoints")

      assert {:error, :no_skill_points} =
               Manager.allocate_skill_point(state.guild_id, master.id, 10_000)
    end

    test "rejects unmet prerequisites" do
      {master, state} = guild_fixture("AllocPrereq")
      :ok = grant_points(state.guild_id, 1)

      # GD_KAFRACONTRACT requires GD_APPROVAL 1
      assert {:error, :prerequisite_not_met} =
               Manager.allocate_skill_point(state.guild_id, master.id, 10_001)
    end

    test "rejects exceeding max level, including GLORYGUILD at 0" do
      {master, state} = guild_fixture("AllocMax")
      :ok = grant_points(state.guild_id, 3)

      {:ok, _} = Manager.allocate_skill_point(state.guild_id, master.id, 10_000)

      assert {:error, :max_level_reached} =
               Manager.allocate_skill_point(state.guild_id, master.id, 10_000)

      assert {:error, :max_level_reached} =
               Manager.allocate_skill_point(state.guild_id, master.id, 10_005)
    end

    test "rejects ids outside the tree and unknown guilds" do
      {master, state} = guild_fixture("AllocUnknown")
      :ok = grant_points(state.guild_id, 1)

      assert {:error, :unknown_skill} =
               Manager.allocate_skill_point(state.guild_id, master.id, 99)

      assert {:error, :not_found} = Manager.allocate_skill_point(999_999, master.id, 10_000)
    end
  end

  describe "check_and_arm_skill_cooldown/3" do
    test "arms once and rejects until expiry" do
      {_master, state} = guild_fixture("Cooldown")

      assert :ok = Manager.check_and_arm_skill_cooldown(state.guild_id, 10_013, 60_000)

      assert {:error, {:cooldown, remaining}} =
               Manager.check_and_arm_skill_cooldown(state.guild_id, 10_013, 60_000)

      assert remaining > 0 and remaining <= 60_000
    end

    test "frees after expiry" do
      {_master, state} = guild_fixture("CooldownExpiry")

      assert :ok = Manager.check_and_arm_skill_cooldown(state.guild_id, 10_013, 1)
      Process.sleep(5)
      assert :ok = Manager.check_and_arm_skill_cooldown(state.guild_id, 10_013, 60_000)
    end

    test "unknown guild reports not_found" do
      assert {:error, :not_found} = Manager.check_and_arm_skill_cooldown(999_999, 10_013, 1)
    end
  end

  describe "edit_position tax clamp" do
    test "clamps tax to guild_exp_limit and stores in-range values" do
      {master, state} = guild_fixture("TaxClamp")

      {:ok, clamped} =
        Manager.edit_position(state.guild_id, master.id, %{
          index: 5,
          name: "Taxed",
          can_invite: false,
          can_expel: false,
          tax: 80
        })

      assert clamped.positions[5].tax == 50

      {:ok, kept} =
        Manager.edit_position(state.guild_id, master.id, %{
          index: 5,
          name: "Taxed",
          can_invite: false,
          can_expel: false,
          tax: 30
        })

      assert kept.positions[5].tax == 30
    end

    test "an edit without tax preserves the existing tax" do
      {master, state} = guild_fixture("TaxPreserve")

      {:ok, _} =
        Manager.edit_position(state.guild_id, master.id, %{
          index: 5,
          name: "Taxed",
          can_invite: false,
          can_expel: false,
          tax: 30
        })

      {:ok, preserved} =
        Manager.edit_position(state.guild_id, master.id, %{
          index: 5,
          name: "Renamed",
          can_invite: true,
          can_expel: false
        })

      assert preserved.positions[5].tax == 30
      assert preserved.positions[5].name == "Renamed"
    end
  end
end
