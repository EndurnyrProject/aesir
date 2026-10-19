defmodule Aesir.ZoneServer.Unit.Player.Handlers.MemoHandler do
  @moduledoc "Captures Warp Portal memo points through the owning player session."

  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Mmo.Skill.WarpPortalMemo
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @doc "Records the authenticated player's current point and reports the outcome."
  @spec handle_request(SessionState.t()) :: {:noreply, SessionState.t()}
  def handle_request(%{game_state: %{action_state: :dead}} = state), do: {:noreply, state}

  def handle_request(%{game_state: player} = state) do
    case MapCache.get(player.map_name) do
      {:ok, map} ->
        access = Map.take(MapFlags.flags(player.map_name), [:nomemo, :nowarpto])
        access = Map.put(access, :any_warp, PortalAccess.permissions(player).any_warp)

        case WarpPortalMemo.remember(player, map, access) do
          {:ok, remembered} -> finish(state, remembered, :ok)
          {:error, reason, remembered} -> finish(state, remembered, reason)
        end

      {:error, :not_found} ->
        reply(state, :memo_forbidden)
        {:noreply, state}
    end
  end

  defp finish(state, player, result) do
    if player.memo_points == state.game_state.memo_points do
      reply(state, result)
      {:noreply, state}
    else
      case CharacterPersistence.update_character(player.character_id, %{
             memo_points: player.memo_points
           }) do
        {:ok, _character} ->
          reply(state, result)
          {:noreply, StateCommit.commit(state, player)}

        {:error, _reason} ->
          reply(state, :persistence_failed)
          {:noreply, state}
      end
    end
  end

  defp reply(state, result) do
    message =
      case result do
        :ok -> "Saved location as a Memo Point for Warp skill."
        :insufficient_level -> "Skill Level is not high enough."
        :skill_not_learned -> "You haven't learned Warp."
        :memo_forbidden -> "Saved point cannot be memorized."
        :instance_map -> "You cannot create a memo in an instance."
        :persistence_failed -> "Unable to save the memo point."
      end

    MessageRouter.send_to(state.connection_pid, %ChatMessage{
      gid: state.game_state.character_id,
      message: message
    })
  end
end
