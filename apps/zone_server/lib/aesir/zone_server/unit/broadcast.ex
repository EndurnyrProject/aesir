defmodule Aesir.ZoneServer.Unit.Broadcast do
  @moduledoc """
  Helper functions for broadcasting packets to entities in the zone server.
  """
  require Logger
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Broadcasts a packet to all visible players in the game state.

  ## Options
    - `exclude_id`: The entity ID to exclude from the broadcast (e.g., the sender).
  """
  @spec to_visible_players(map(), struct(), keyword()) :: :ok
  def to_visible_players(game_state, packet, opts \\ []) do
    exclude_id = Keyword.get(opts, :exclude_id)

    game_state.visible_players
    |> Enum.reject(&(&1 == exclude_id))
    |> Enum.each(&send_to_player(&1, packet))
  end

  defp send_to_player(player_id, packet) do
    case UnitRegistry.get_player_pid(player_id) do
      {:ok, pid} ->
        GenServer.cast(pid, {:send_packet, packet})

      {:error, :not_found} ->
        Logger.debug("Visible player #{player_id} not found in registry during broadcast.")
    end
  end
end
