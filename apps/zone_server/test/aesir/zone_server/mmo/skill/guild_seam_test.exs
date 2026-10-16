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
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    on_exit(fn -> ClusterTestHelper.clear_all() end)

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
    test "the master casts at up to the guild's learned rank, on any ground" do
      {master, guild} = guild_fixture("SeamMaster", %{"10004" => 3})
      me = %{caster(master.id, guild.guild_id) | map_name: "prontera"}

      assert :ok = PlayerCaster.knows?(me, @gd_extension, 3, :begin)

      assert {:error, :guild_skill_unavailable} =
               PlayerCaster.knows?(me, @gd_extension, 4, :begin)
    end

    test "an unlearned guild skill is dropped silently" do
      {master, guild} = guild_fixture("SeamUnlearned", %{})

      assert {:error, :guild_skill_unavailable} =
               PlayerCaster.knows?(
                 caster(master.id, guild.guild_id),
                 @gd_emergencycall,
                 1,
                 :begin
               )
    end

    test "a non-master guild member is dropped silently" do
      {_master, guild} = guild_fixture("SeamPeon", %{"10004" => 3})

      assert {:error, :guild_skill_unavailable} =
               PlayerCaster.knows?(caster(999_999, guild.guild_id), @gd_extension, 1, :begin)
    end

    test "a guildless caster is dropped silently" do
      assert {:error, :guild_skill_unavailable} =
               PlayerCaster.knows?(caster(1, 0), @gd_extension, 1, :begin)

      assert {:error, :guild_skill_unavailable} =
               PlayerCaster.knows?(caster(1, nil), @gd_extension, 1, :begin)
    end

    test "nothing is checked again when the cast ends" do
      assert :ok = PlayerCaster.knows?(caster(1, 0), @gd_emergencycall, 1, :completion)
    end
  end

  describe "guild skill cooldowns" do
    test "live on the caster's own cooldown map" do
      {master, guild} = guild_fixture("SeamCooldown", %{"10004" => 3})
      me = caster(master.id, guild.guild_id)
      now = System.monotonic_time(:millisecond)

      assert PlayerCaster.cooldown_ready?(me, 10_013, now, :begin)

      after_cast = PlayerCaster.put_cooldown(me, 10_013, now + 300_000)

      assert after_cast.skill_cooldowns == %{10_013 => now + 300_000}
      refute PlayerCaster.cooldown_ready?(after_cast, 10_013, now, :begin)
      assert PlayerCaster.cooldown_ready?(me, 10_013, now, :begin)
    end
  end
end
