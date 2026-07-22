defmodule Aesir.ZoneServer.Unit.Player.GuildSyncBroadcastTest do
  use Aesir.DataCase, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "a committed state change for a guild member broadcasts GuildMemberUpdate on guild:{id}" do
    master = char_fixture("Warlord")
    {:ok, guild} = Manager.create("Broadcasters", master)

    Phoenix.PubSub.subscribe(Aesir.PubSub, "guild:#{guild.guild_id}")

    previous = player_state(master, guild.guild_id, 500)
    current = player_state(master, guild.guild_id, 420)
    session = %{game_state: previous}

    :ok = UnitRegistry.register_unit(:player, master.id, PlayerState, previous, self())

    assert %{game_state: ^current} = StateCommit.commit(session, current)

    assert_receive {:social, {:guild_member_updated, guild_id, %Member{} = member}}
    assert guild_id == guild.guild_id
    assert member.char_id == master.id
    assert member.hp == 420
    assert member.online == true
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

  defp player_state(%Character{} = character, guild_id, hp) do
    %PlayerState{
      character_id: character.id,
      character_name: character.name,
      guild_id: guild_id,
      map_name: "prontera",
      stats: %PlayerStats{
        progression: %PlayerProgression{base_level: 50, job_id: 7},
        current_state: %CurrentState{hp: hp, sp: 300, ap: 40},
        derived_stats: %DerivedStats{max_hp: 1_000, max_sp: 500, max_ap: 100}
      }
    }
  end
end
