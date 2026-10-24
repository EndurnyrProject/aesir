defmodule Aesir.ZoneServer.Mmo.Skills.Clown.MarionetteLink do
  @moduledoc """
  Matching, range and echo-terminating teardown of a Marionette link in both
  modes, between a player master and a player or Homunculus puppet.

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

  @typedoc "A typed unit reference used as a link peer."
  @type peer :: {:player, integer()} | {:homunculus, integer()}

  @doc "True when a living peer holds the counterpart for this exact link."
  @spec intact?(peer(), atom(), reference()) :: boolean()
  def intact?({unit_type, peer_id}, status, link_id) do
    with %StatusEntry{state: %{link_id: ^link_id}} <-
           StatusStorage.get_status(unit_type, peer_id, status),
         {:ok, {_module, peer, _pid}} <- UnitRegistry.get_unit(unit_type, peer_id) do
      Unit.living?(peer)
    else
      _ -> false
    end
  end

  @doc "True when both peers share a map and are within Chebyshev range."
  @spec within?(peer(), peer(), non_neg_integer()) :: boolean()
  def within?({unit_type, id}, {peer_type, peer_id}, range) do
    with {:ok, {x, y, map}} <- SpatialIndex.get_unit_position(unit_type, id),
         {:ok, {px, py, ^map}} <- SpatialIndex.get_unit_position(peer_type, peer_id) do
      Geometry.chebyshev_distance(x, y, px, py) <= range
    else
      _ -> false
    end
  end

  @doc "Closes only the peer's matching link, clearing its back-reference before expiry."
  @spec close_peer(map(), atom()) :: :ok
  def close_peer(%{peer: {unit_type, id}, link_id: link}, status) do
    case StatusStorage.get_status(unit_type, id, status) do
      %StatusEntry{state: %{link_id: ^link}} ->
        StatusStorage.update_status(unit_type, id, status, fn entry ->
          %{entry | state: Map.put(entry.state, :peer, nil)}
        end)

        Interpreter.remove_status(unit_type, id, status)

      _ ->
        :ok
    end
  end

  def close_peer(_state, _status), do: :ok
end
