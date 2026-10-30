defmodule Aesir.ZoneServer.Unit.Player.Handlers.FameHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import ExUnit.CaptureLog

  alias Aesir.Net.FameUpdate
  alias Aesir.Net.RankingRequest
  alias Aesir.Net.RankingResponse
  alias Aesir.ZoneServer.Mmo.Fame
  alias Aesir.ZoneServer.Mmo.Fame.Store
  alias Aesir.ZoneServer.Unit.Player.Handlers.FameHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    player = %PlayerState{
      character_id: 7,
      stats: %Stats{progression: %PlayerProgression{job_id: 18}}
    }

    :ok = UnitRegistry.register_unit(:player, 7, PlayerState, player, self())
    %{player: player}
  end

  test "an empty fame queue does not write or send", %{player: player} do
    reject(Store, :persist, 2)
    assert FameHandler.drain(self(), player) == player
    refute_received {:send, _, _}
  end

  test "a successful fame drain persists before privately notifying in event order", %{
    player: player
  } do
    player = player |> Fame.award(1) |> Fame.award(3)

    expect(Store, :persist, fn 7, 4 ->
      refute_received {:send, _, _}
      :ok
    end)

    cleared = FameHandler.drain(self(), player)
    assert cleared.pending_fame_awards == []

    assert_received {:send, :gameplay,
                     {:fame_update,
                      %FameUpdate{category: :RANKING_ALCHEMIST, awarded_points: 1, total_fame: 1}}}

    assert_received {:send, :gameplay,
                     {:fame_update, %FameUpdate{awarded_points: 3, total_fame: 4}}}

    assert FameHandler.drain(self(), cleared) == cleared
    refute_received {:send, _, _}

    capped = Fame.award(%{cleared | fame: 1_000_000_000}, 50)
    expect(Store, :persist, fn 7, 1_000_000_000 -> :ok end)
    assert FameHandler.drain(self(), capped).pending_fame_awards == []

    assert_received {:send, :gameplay,
                     {:fame_update, %FameUpdate{awarded_points: 50, total_fame: 1_000_000_000}}}
  end

  test "failed fame drain retains events and retries the absolute total once", %{player: player} do
    player = Fame.award(player, 1)
    expect(Store, :persist, fn 7, 1 -> {:error, :unavailable} end)

    assert capture_log(fn -> assert FameHandler.drain(self(), player) == player end) =~
             "unavailable"

    refute_received {:send, _, _}
    player = Fame.award(player, 3)
    expect(Store, :persist, fn 7, 4 -> :ok end)
    assert FameHandler.drain(self(), player).pending_fame_awards == []
    assert_received {:send, _, {:fame_update, %FameUpdate{awarded_points: 1, total_fame: 1}}}
    assert_received {:send, _, {:fame_update, %FameUpdate{awarded_points: 3, total_fame: 4}}}
    refute_received {:send, _, _}
  end

  test "ranking queries return either board and the requesters own production fame", %{
    player: player
  } do
    entries = [
      %{character_id: 9, name: "First", fame: 12},
      %{character_id: 3, name: "Second", fame: 10}
    ]

    for {wire, category} <- [RANKING_BLACKSMITH: :blacksmith, RANKING_ALCHEMIST: :alchemist] do
      expect(Store, :ranking, fn ^category -> {:ok, entries} end)
      session = %SessionState{connection_pid: self(), game_state: %{player | fame: 8}}

      assert {:noreply, returned} =
               PacketHandler.handle_message(%RankingRequest{category: wire}, session)

      assert returned.game_state.fame == 8

      assert_received {:send, :gameplay,
                       {:ranking_response,
                        %RankingResponse{
                          category: ^wire,
                          entries: [first, second],
                          own_fame: 8,
                          result: :OK
                        }}}

      assert {first.character_id, second.character_id} == {9, 3}
    end

    player = put_in(player.stats.progression.job_id, 0)
    expect(Store, :ranking, fn :blacksmith -> {:ok, []} end)
    session = %SessionState{connection_pid: self(), game_state: %{player | fame: 8}}

    assert {:noreply, _} =
             FameHandler.handle_request(%RankingRequest{category: :RANKING_BLACKSMITH}, session)

    assert_received {:send, _,
                     {:ranking_response, %RankingResponse{entries: [], own_fame: 0, result: :OK}}}
  end

  test "unknown categories and unavailable storage return explicit ranking errors", %{
    player: player
  } do
    session = %SessionState{connection_pid: self(), game_state: player}

    for category <- [:RANKING_UNSPECIFIED, 999] do
      assert {:noreply, _} =
               FameHandler.handle_request(%RankingRequest{category: category}, session)

      assert_received {:send, _,
                       {:ranking_response,
                        %RankingResponse{
                          category: ^category,
                          entries: [],
                          result: :INVALID_CATEGORY
                        }}}
    end

    expect(Store, :ranking, fn :blacksmith -> {:error, :unavailable} end)

    capture_log(fn ->
      assert {:noreply, _} =
               FameHandler.handle_request(%RankingRequest{category: :RANKING_BLACKSMITH}, session)
    end)

    assert_received {:send, _,
                     {:ranking_response, %RankingResponse{entries: [], result: :UNAVAILABLE}}}

    player = Fame.award(player, 1)
    session = %{session | game_state: player}
    expect(Store, :persist, fn 7, 1 -> {:error, :unavailable} end)
    reject(Store, :ranking, 1)

    capture_log(fn ->
      assert {:noreply, returned} =
               FameHandler.handle_request(%RankingRequest{category: :RANKING_BLACKSMITH}, session)

      assert returned.game_state == player
    end)

    assert_received {:send, _,
                     {:ranking_response, %RankingResponse{entries: [], result: :UNAVAILABLE}}}

    refute_received {:send, _, {:fame_update, _}}
  end
end
