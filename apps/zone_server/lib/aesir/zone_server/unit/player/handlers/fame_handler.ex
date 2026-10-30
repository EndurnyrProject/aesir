defmodule Aesir.ZoneServer.Unit.Player.Handlers.FameHandler do
  @moduledoc "Persists staged fame before private notifications and serves production ranking requests."

  require Logger

  alias Aesir.Net.FameUpdate
  alias Aesir.Net.RankingEntry
  alias Aesir.Net.RankingRequest
  alias Aesir.Net.RankingResponse
  alias Aesir.ZoneServer.Mmo.Fame
  alias Aesir.ZoneServer.Mmo.Fame.Store
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @doc "Persists the final absolute total once, then notifies in event order; retains failures for retry."
  @spec drain(pid() | nil, PlayerState.t()) :: PlayerState.t()
  def drain(_connection_pid, %PlayerState{pending_fame_awards: []} = player), do: player

  def drain(connection_pid, %PlayerState{} = player) do
    case Store.persist(player.character_id, player.fame) do
      :ok ->
        Enum.each(player.pending_fame_awards, &notify(connection_pid, &1))
        %{player | pending_fame_awards: []}

      {:error, reason} ->
        Logger.error(
          "Failed to persist fame for character #{player.character_id}: #{inspect(reason)}"
        )

        player
    end
  end

  @doc "Commits pending fame and responds with the requested board or an explicit error."
  @spec handle_request(RankingRequest.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_request(%RankingRequest{category: category}, session) do
    session = StateCommit.commit(session, session.game_state)
    response = response(category, session.game_state)
    MessageRouter.send_to(session.connection_pid, response)
    {:noreply, session}
  end

  defp response(category, player) do
    case profession(category) do
      nil -> %RankingResponse{category: category, result: :INVALID_CATEGORY}
      profession -> read_ranking(category, profession, player)
    end
  end

  defp read_ranking(category, _profession, %PlayerState{pending_fame_awards: [_ | _]}),
    do: %RankingResponse{category: category, result: :UNAVAILABLE}

  defp read_ranking(category, profession, player) do
    case Store.ranking(profession) do
      {:ok, entries} ->
        %RankingResponse{
          category: category,
          result: :OK,
          entries: Enum.map(entries, &struct!(RankingEntry, &1)),
          own_fame: own_fame(player)
        }

      {:error, reason} ->
        Logger.error("Failed to query #{profession} ranking: #{inspect(reason)}")
        %RankingResponse{category: category, result: :UNAVAILABLE}
    end
  end

  defp own_fame(player) do
    if Fame.category(player.stats.progression.job_id), do: player.fame, else: 0
  end

  defp notify(nil, _event), do: :ok

  defp notify(connection_pid, event) do
    MessageRouter.send_to(connection_pid, %FameUpdate{
      category: wire_category(event.category),
      awarded_points: event.awarded_points,
      total_fame: event.total_fame
    })
  end

  defp profession(:RANKING_BLACKSMITH), do: :blacksmith
  defp profession(:RANKING_ALCHEMIST), do: :alchemist
  defp profession(_unknown), do: nil

  defp wire_category(:blacksmith), do: :RANKING_BLACKSMITH
  defp wire_category(:alchemist), do: :RANKING_ALCHEMIST
end
