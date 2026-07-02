defmodule Aesir.ZoneServer.Unit.Player.Handlers.NameHandler do
  @moduledoc """
  Resolves entity-name requests against the player's visible sets.

  Collapses the legacy player (ZC_ACK_REQNAMEALL) and non-player
  (ZC_ACK_REQNAME) replies into one `NameResponse`: players fill
  party/guild/position, mobs/NPCs leave them empty.
  """

  require Logger

  alias Aesir.Net.NameResponse
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Processes a name request (protobuf analogue of CZ_REQNAME2 0x0368).

  Resolves the id against, in order: the player's own character, the visible
  player set, the visible mob set, and finally static NPC placements. An id
  that resolves nowhere is ignored (out of view range).
  """
  @spec handle_name_request(integer(), map()) :: {:noreply, map()}
  def handle_name_request(
        entity_id,
        %{game_state: game_state, connection_pid: connection_pid} = state
      ) do
    cond do
      entity_id == game_state.character_id ->
        MessageRouter.send_to(connection_pid, %NameResponse{
          gid: game_state.character_id,
          name: game_state.character_name,
          party_name: party_name(game_state.party_id)
        })

      MapSet.member?(game_state.visible_players, entity_id) ->
        case UnitRegistry.get_unit(:player, entity_id) do
          {:ok, {_module, player_state, _pid}} ->
            MessageRouter.send_to(connection_pid, %NameResponse{
              gid: entity_id,
              name: player_state.character_name,
              party_name: party_name(player_state.party_id)
            })

          {:error, :not_found} ->
            Logger.warning(
              "Player #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      MapSet.member?(game_state.visible_mobs, entity_id) ->
        case UnitRegistry.get_unit(:mob, entity_id) do
          {:ok, {_module, mob_state, _pid}} ->
            MessageRouter.send_to(connection_pid, %NameResponse{
              gid: entity_id,
              name: mob_state.mob_data.name
            })

          {:error, :not_found} ->
            Logger.warning(
              "Mob #{entity_id} in visible set but not found in registry (lagged client)"
            )
        end

      true ->
        reply_npc_name(connection_pid, entity_id)
    end

    {:noreply, state}
  end

  # Resolves a party_id to its party name, defaulting to the proto3 zero-value
  # for a player with no party or a stale party_id (entry not live).
  defp party_name(0), do: ""

  defp party_name(party_id) do
    case PartyManager.get(party_id) do
      {:ok, party_state} -> party_state.name
      {:error, :not_found} -> ""
    end
  end

  # Resolves entity_id to a static NPC placement and replies with its name.
  # Reached only after the own-char/visible_players/visible_mobs branches
  # decline the id; an id that resolves to no NPC module is ignored.
  defp reply_npc_name(connection_pid, entity_id) do
    case NpcRegistry.module_for_unit(entity_id) do
      {:ok, {_module, placement}} ->
        MessageRouter.send_to(connection_pid, %NameResponse{gid: entity_id, name: placement.name})

      :error ->
        Logger.debug("Ignoring name request for entity #{entity_id} (not in view range)")
    end
  end
end
