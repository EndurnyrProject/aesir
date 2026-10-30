defmodule Aesir.Commons.Network.FameProtoTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.Envelope
  alias Aesir.Net.FameUpdate
  alias Aesir.Net.RankingEntry
  alias Aesir.Net.RankingRequest
  alias Aesir.Net.RankingResponse

  test "ranking messages preserve ordered entries and point totals" do
    for category <- [:RANKING_BLACKSMITH, :RANKING_ALCHEMIST] do
      round_trip(:ranking_request, %RankingRequest{category: category})
      round_trip(:ranking_response, %RankingResponse{category: category, result: :OK})

      entries = [
        %RankingEntry{character_id: 8, name: "Latest", fame: 1_000_000_000},
        %RankingEntry{character_id: 2, name: "Earlier", fame: 1_000_000_000}
      ]

      round_trip(:ranking_response, %RankingResponse{
        category: category,
        entries: entries,
        own_fame: 1_000_000_000,
        result: :OK
      })

      round_trip(:fame_update, %FameUpdate{
        category: category,
        awarded_points: 50,
        total_fame: 1_000_000_000
      })
    end
  end

  test "ranking error enums round-trip without becoming success" do
    for result <- [:INVALID_CATEGORY, :UNAVAILABLE] do
      round_trip(:ranking_response, %RankingResponse{
        category: :RANKING_UNSPECIFIED,
        result: result,
        entries: []
      })
    end

    round_trip(:ranking_request, %RankingRequest{category: 999})
  end

  defp round_trip(tag, message) do
    envelope = %Envelope{seq: 7, body: {tag, message}}
    {:ok, encoded, _size} = Envelope.encode(envelope)
    assert {:ok, ^envelope} = Envelope.decode(IO.iodata_to_binary(encoded))
  end
end
