defmodule Aesir.ZoneServer.Mmo.Skill.GuildSeamTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @gd_extension %{id: 10_004}
  @gd_emergencycall %{id: 10_013}

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

  defp guild_fixture(master_name, learned_skills) do
    master = char_fixture(master_name)
    {:ok, state} = Manager.create("Guild-#{master_name}", master)

    {1, nil} =
      from(g in GuildModel, where: g.id == ^state.guild_id)
      |> Repo.update_all(set: [learned_skills: learned_skills])

    ClusterTestHelper.clear_all()
    {:ok, state} = Manager.ensure_started(state.guild_id)
    {master, state}
  end

  defp caster(char_id, guild_id) do
    %PlayerState{character_id: char_id, account_id: 1, guild_id: guild_id}
  end

  describe "knows?/4 for guild-band skills" do
    test "the master casts at up to the guild's learned rank" do
      {master, guild} = guild_fixture("SeamMaster", %{"10004" => 3})
      me = caster(master.id, guild.guild_id)

      assert :ok = PlayerCaster.knows?(me, @gd_extension, 3, :begin)
      assert :ok = PlayerCaster.knows?(me, @gd_extension, 1, :completion)
      assert {:error, :skill_not_learned} = PlayerCaster.knows?(me, @gd_extension, 4, :begin)
    end

    test "an unlearned guild skill is rejected" do
      {master, guild} = guild_fixture("SeamUnlearned", %{})

      assert {:error, :skill_not_learned} =
               PlayerCaster.knows?(
                 caster(master.id, guild.guild_id),
                 @gd_emergencycall,
                 1,
                 :begin
               )
    end

    test "a non-master guild member is rejected" do
      {_master, guild} = guild_fixture("SeamPeon", %{"10004" => 3})

      assert {:error, :not_guild_master} =
               PlayerCaster.knows?(caster(999_999, guild.guild_id), @gd_extension, 1, :begin)
    end

    test "a guildless caster is rejected" do
      assert {:error, :skill_not_learned} =
               PlayerCaster.knows?(caster(1, 0), @gd_extension, 1, :begin)

      assert {:error, :skill_not_learned} =
               PlayerCaster.knows?(caster(1, nil), @gd_extension, 1, :begin)
    end

    test "the GvG gate rejects when enabled and passes on the relaxed default" do
      {master, guild} = guild_fixture("SeamGvg", %{"10004" => 3})
      me = caster(master.id, guild.guild_id)

      Application.put_env(:zone_server, :guild_skills_gvg_only, true)
      on_exit(fn -> Application.delete_env(:zone_server, :guild_skills_gvg_only) end)

      assert {:error, :not_gvg_ground} = PlayerCaster.knows?(me, @gd_extension, 1, :begin)

      Application.delete_env(:zone_server, :guild_skills_gvg_only)
      assert :ok = PlayerCaster.knows?(me, @gd_extension, 1, :begin)
    end
  end

  describe "guild-scoped cooldowns" do
    test "put_cooldown arms on the guild entry, leaving the character map untouched" do
      {master, guild} = guild_fixture("SeamCooldown", %{"10004" => 3})
      me = caster(master.id, guild.guild_id)
      now = System.monotonic_time(:millisecond)

      assert PlayerCaster.cooldown_ready?(me, 10_013, now, :begin)

      after_cast = PlayerCaster.put_cooldown(me, 10_013, now + 300_000)
      assert after_cast.skill_cooldowns == %{}

      refute PlayerCaster.cooldown_ready?(me, 10_013, now, :begin)

      {:ok, live} = Manager.get(guild.guild_id)
      assert is_integer(live.skill_cooldowns[10_013])
    end

    test "a relogged master still sees the armed cooldown" do
      {master, guild} = guild_fixture("SeamRelog", %{"10004" => 3})
      me = caster(master.id, guild.guild_id)
      now = System.monotonic_time(:millisecond)

      PlayerCaster.put_cooldown(me, 10_013, now + 300_000)

      fresh_session_caster = caster(master.id, guild.guild_id)
      refute PlayerCaster.cooldown_ready?(fresh_session_caster, 10_013, now, :begin)
    end

    test "non-guild skills keep using the per-character cooldown map" do
      me = caster(1, 0)
      after_cast = PlayerCaster.put_cooldown(me, 28, 12_345)

      assert after_cast.skill_cooldowns == %{28 => 12_345}
    end
  end
end
