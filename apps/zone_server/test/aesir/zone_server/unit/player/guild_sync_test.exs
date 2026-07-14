defmodule Aesir.ZoneServer.Unit.Player.GuildSyncTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!
  setup :set_mimic_from_context

  test "publishes a complete live member snapshot when guild-visible state changes" do
    previous = player_state(hp: 40)
    current = player_state(hp: 35)

    expect(Manager, :sync_member, fn 7, 12, member ->
      assert member == %Member{
               char_id: 12,
               name: "Aesir",
               job_id: 4054,
               base_level: 175,
               hp: 35,
               max_hp: 8_000,
               sp: 900,
               max_sp: 1_200,
               ap: 120,
               max_ap: 200,
               online: true,
               map_name: "prontera"
             }

      {:ok, %{}}
    end)

    assert :ok = GuildSync.sync(previous, current)
  end

  test "does not publish when only non-guild state changes" do
    previous = player_state(x: 100)
    current = player_state(x: 101)

    reject(&Manager.sync_member/3)

    assert :ok = GuildSync.sync(previous, current)
  end

  test "does not publish for a player without a guild" do
    previous = player_state(guild_id: 0, hp: 40)
    current = player_state(guild_id: 0, hp: 35)

    reject(&Manager.sync_member/3)

    assert :ok = GuildSync.sync(previous, current)
  end

  test "does not inspect missing stats for a partial player without a guild" do
    previous = %PlayerState{guild_id: 0}
    current = %PlayerState{guild_id: 0}

    reject(&Manager.sync_member/3)

    assert :ok = GuildSync.sync(previous, current)
  end

  test "can force an offline snapshot without clearing last-known values" do
    current = player_state(hp: 35)

    expect(Manager, :sync_member, fn 7, 12, member ->
      assert member.online == false
      assert member.hp == 35
      {:ok, %{}}
    end)

    assert :ok = GuildSync.sync(current, online: false)
  end

  test "can force an online snapshot" do
    current = player_state(hp: 35)

    expect(Manager, :sync_member, fn 7, 12, member ->
      assert member.online == true
      {:ok, %{}}
    end)

    assert :ok = GuildSync.sync(current, online: true)
  end

  test "does not force a snapshot for a player without a guild" do
    current = player_state(guild_id: 0, hp: 35)

    reject(&Manager.sync_member/3)

    assert :ok = GuildSync.sync(current, online: true)
  end

  defp player_state(overrides) do
    current_state = %CurrentState{hp: Keyword.get(overrides, :hp, 40), sp: 900, ap: 120}

    %PlayerState{
      character_id: 12,
      character_name: "Aesir",
      guild_id: Keyword.get(overrides, :guild_id, 7),
      map_name: "prontera",
      x: Keyword.get(overrides, :x, 100),
      stats: %PlayerStats{
        progression: %PlayerProgression{base_level: 175, job_id: 4054},
        current_state: current_state,
        derived_stats: %DerivedStats{max_hp: 8_000, max_sp: 1_200, max_ap: 200}
      }
    }
  end
end
