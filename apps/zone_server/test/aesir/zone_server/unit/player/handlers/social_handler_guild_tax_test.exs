defmodule Aesir.ZoneServer.Unit.Player.Handlers.SocialHandlerGuildTaxTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Guild.Member, as: GuildMember
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    stub(UnitRegistry, :update_unit_state, fn :player, _id, _gs -> :ok end)
    stub(GuildSync, :sync, fn _prev, _next -> :ok end)
    :ok
  end

  @char_id 77

  defp session(guild_tax) do
    game_state = %PlayerState{
      character_id: @char_id,
      account_id: 1,
      guild_id: 5,
      guild_tax: guild_tax
    }

    %{connection_pid: self(), game_state: game_state}
  end

  defp guild_state(tax) do
    member = GuildMember.new(@char_id, "Member", 50, true, 5, "prontera")

    %GuildState{
      guild_id: 5,
      name: "Taxers",
      master_char_id: 1,
      positions: %{5 => %Position{index: 5, name: "Taxed", tax: tax}},
      members: %{@char_id => member}
    }
  end

  test "a guild broadcast refreshes the cached tax from the member's position" do
    {:noreply, updated} = SocialHandler.guild_updated(guild_state(30), session(0))

    assert updated.game_state.guild_tax == 30
    assert_received {:send, _channel, {:guild_info, _info}}
  end

  test "the cached tax is clamped to the configured limit" do
    {:noreply, updated} = SocialHandler.guild_updated(guild_state(90), session(0))

    assert updated.game_state.guild_tax == 50
  end

  test "an unchanged tax does not recommit state" do
    reject(&UnitRegistry.update_unit_state/3)

    {:noreply, updated} = SocialHandler.guild_updated(guild_state(30), session(30))

    assert updated.game_state.guild_tax == 30
  end

  test "a guild level-up pushes GuildLevelUp then the refreshed GuildInfo" do
    guild = %{guild_state(0) | level: 7, skill_points: 3}

    {:noreply, _updated} = SocialHandler.guild_leveled_up(guild, session(0))

    assert_received {:send, _channel, {first_tag, level_up}}
    assert first_tag == :guild_level_up
    assert level_up.guild_id == 5
    assert level_up.level == 7
    assert level_up.skill_points == 3

    assert_received {:send, _channel, {second_tag, info}}
    assert second_tag == :guild_info
    assert info.level == 7
  end

  test "a stale level-up for another guild is ignored" do
    guild = %{guild_state(0) | guild_id: 99}

    {:noreply, updated} = SocialHandler.guild_leveled_up(guild, session(0))

    assert updated.game_state.guild_tax == 0
    refute_received {:send, _channel, {:guild_level_up, _}}
  end
end
