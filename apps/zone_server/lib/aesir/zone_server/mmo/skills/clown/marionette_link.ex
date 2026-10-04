defmodule Aesir.ZoneServer.Mmo.Skills.Clown.MarionetteLink do
  @moduledoc """
  Matching, range and echo-terminating teardown of a Marionette link in both modes.

  Status rows are written directly; ordinary removal clears the peer's
  back-reference before its expiry callback, and ticks heal a missing peer.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "True when a living peer holds the counterpart for this exact link."
  @spec intact?(integer(), atom(), reference()) :: boolean()
  def intact?(peer_id, status, link_id) do
    with %StatusEntry{state: %{link_id: ^link_id}} <-
           StatusStorage.get_status(:player, peer_id, status),
         {:ok, {_module, peer, _pid}} <- UnitRegistry.get_unit(:player, peer_id) do
      Unit.living?(peer)
    else
      _ -> false
    end
  end

  @doc "True when both players share a map and are within Chebyshev range."
  @spec within?(integer(), integer(), non_neg_integer()) :: boolean()
  def within?(id, peer_id, range) do
    with {:ok, {x, y, map}} <- SpatialIndex.get_unit_position(:player, id),
         {:ok, {px, py, ^map}} <- SpatialIndex.get_unit_position(:player, peer_id) do
      Geometry.chebyshev_distance(x, y, px, py) <= range
    else
      _ -> false
    end
  end

  @doc "Closes only the peer's matching link, clearing its back-reference before expiry."
  @spec close_peer(map(), atom()) :: :ok
  def close_peer(%{peer: {:player, id}, link_id: link}, status) do
    case StatusStorage.get_status(:player, id, status) do
      %StatusEntry{state: %{link_id: ^link}} ->
        StatusStorage.update_status(:player, id, status, fn entry ->
          %{entry | state: Map.put(entry.state, :peer, nil)}
        end)

        Interpreter.remove_status(:player, id, status)

      _ ->
        :ok
    end
  end

  def close_peer(_state, _status), do: :ok
end
