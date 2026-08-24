defmodule Aesir.ZoneServer.Unit.Player.Handlers.SocialHandlerGuildStorageTest do
  use ExUnit.Case, async: false

  import Aesir.TestWait
  import Mimic

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Net.GuildDisbanded
  alias Aesir.ZoneServer.Guild.Member, as: GuildMember
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State, as: GuildState
  alias Aesir.ZoneServer.Guild.Storage.Lock
  alias Aesir.ZoneServer.Unit.Player.GuildSync
  alias Aesir.ZoneServer.Unit.Player.Handlers.SocialHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @guild_id 5
  @char_id 77

  setup :verify_on_exit!
  setup :set_mimic_private

  setup do
    ClusterTestHelper.clear_all()
    on_exit(&ClusterTestHelper.clear_all/0)
    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _game_state -> :ok end)
    stub(GuildSync, :sync, fn _previous, _next -> :ok end)
    :ok
  end

  test "an expulsion state update force-closes guild storage and frees its claim" do
    state = open_storage()

    assert {:noreply, updated} =
             SocialHandler.info({:guild_updated, guild_without_member()}, state)

    assert_membership_cleared(updated)
    assert_claim_available()
  end

  test "a voluntary departure state update force-closes guild storage and frees its claim" do
    state = open_storage()

    assert {:noreply, updated} =
             SocialHandler.guild_updated(guild_without_member(), state)

    assert_membership_cleared(updated)
    assert_claim_available()
  end

  test "a guild disband force-closes guild storage and frees its claim" do
    state = open_storage()

    assert {:noreply, updated} =
             SocialHandler.info({:guild_disbanded, @guild_id, "disbanded"}, state)

    assert_membership_cleared(updated)
    assert_claim_available()

    assert_received {:send, _channel,
                     {:guild_disbanded, %GuildDisbanded{guild_id: @guild_id, reason: "disbanded"}}}
  end

  test "an unrelated same-guild update leaves storage and its claim open" do
    state = open_storage()

    assert {:noreply, updated} = SocialHandler.guild_updated(guild_with_member(), state)
    assert updated.game_state.guild_storage == %{}
    assert updated.guild_storage_ctx == state.guild_storage_ctx
    assert Lock.held_by?(@guild_id, self())
  end

  defp open_storage do
    assert :ok = Lock.claim(@guild_id, @char_id, self())

    game_state = %PlayerState{
      character_id: @char_id,
      account_id: 1,
      guild_id: @guild_id,
      guild_storage: %{}
    }

    %SessionState{
      connection_pid: self(),
      game_state: game_state,
      guild_storage_ctx: %{
        guild_id: @guild_id,
        char_id: @char_id,
        session_pid: self(),
        capacity: 200
      }
    }
  end

  defp guild_without_member do
    %GuildState{guild_id: @guild_id, name: "Departures", master_char_id: 1, members: %{}}
  end

  defp guild_with_member do
    member = GuildMember.new(@char_id, "Member", 50, true, 5, "prontera")

    %GuildState{
      guild_id: @guild_id,
      name: "Updates",
      master_char_id: 1,
      level: 2,
      notice: %{subject: "Notice", body: "Changed"},
      positions: %{5 => %Position{index: 5, name: "Member"}},
      members: %{@char_id => member}
    }
  end

  defp assert_membership_cleared(state) do
    assert state.game_state.guild_id == 0
    assert state.game_state.guild_storage == nil
    assert state.guild_storage_ctx == nil
  end

  defp assert_claim_available do
    next_holder = spawn(fn -> receive do: (:stop -> :ok) end)
    on_exit(fn -> if Process.alive?(next_holder), do: Process.exit(next_holder, :kill) end)

    assert_eventually(fn -> Lock.claim(@guild_id, @char_id + 1, next_holder) == :ok end)
  end
end
