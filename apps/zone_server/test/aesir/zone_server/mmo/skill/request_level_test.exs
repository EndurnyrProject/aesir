defmodule Aesir.ZoneServer.Mmo.Skill.RequestLevelTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Guild.Manager, as: GuildManager
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  @extension 10_004
  @charge_shout_beating 10_018

  test "the requested level is capped by the learned, granted or copied level" do
    player =
      player(%{learned_skills: %{5 => 3}}, %{6 => 2})
      |> Map.put(:plagiarized, %{skill_id: 7, level: 4})

    assert PlayerCaster.request_level(player, 5, 10) == 3
    assert PlayerCaster.request_level(player, 5, 2) == 2
    assert PlayerCaster.request_level(player, 6, 10) == 2
    assert PlayerCaster.request_level(player, 7, 10) == 4
    assert PlayerCaster.request_level(player, 8, 10) == 0
  end

  test "a guild skill runs at the guild's level for the master only, Charge Shout Beating for any member" do
    guild = %GuildState{
      guild_id: 9,
      name: "G",
      master_char_id: 1,
      learned_skills: %{@extension => 5, @charge_shout_beating => 1}
    }

    stub(GuildManager, :get, fn 9 -> {:ok, guild} end)

    master = %{player(%{learned_skills: %{}}, %{}) | guild_id: 9, character_id: 1}
    member = %{master | character_id: 2}

    assert PlayerCaster.request_level(master, @extension, 1) == 5
    assert PlayerCaster.request_level(member, @extension, 1) == 0
    assert PlayerCaster.request_level(member, @charge_shout_beating, 3) == 1
    assert PlayerCaster.request_level(%{master | guild_id: 0}, @extension, 1) == 0
  end

  defp player(progression, granted) do
    %PlayerState{
      character_id: 1,
      guild_id: nil,
      stats: %{progression: progression, granted_skills: granted}
    }
  end
end
