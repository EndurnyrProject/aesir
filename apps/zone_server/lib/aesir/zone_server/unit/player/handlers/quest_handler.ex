defmodule Aesir.ZoneServer.Unit.Player.Handlers.QuestHandler do
  @moduledoc """
  Client-initiated quest log changes. Script-driven changes go through
  `ScriptEffectHandler`; this handles what the player does from the quest window.
  """

  require Logger

  alias Aesir.Net.QuestActiveRequest
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @doc """
  Shelves or resumes a quest (`CZ_ACTIVE_QUEST`, `quest_update_status`).

  An active or inactive quest is set to the requested state, persisted and
  acked with a `QuestStateChanged`, even when the state is unchanged. A complete
  or absent quest gets no reply and no change.
  """
  @spec handle_active_request(QuestActiveRequest.t(), SessionState.t()) ::
          {:noreply, SessionState.t()}
  def handle_active_request(%QuestActiveRequest{quest_id: quest_id, active: active?}, state) do
    %{game_state: gs} = state

    case QuestLog.set_active(gs.quest_log, quest_id, active?) do
      {:ok, quest_log, entry} ->
        QuestPersistence.upsert(gs.character_id, {quest_id, entry})

        MessageRouter.send_to(
          state.connection_pid,
          QuestView.quest_state_changed(quest_id, entry.state)
        )

        {:noreply, StateCommit.commit(state, %{gs | quest_log: quest_log})}

      {:error, :not_found} ->
        Logger.debug(
          "ignored quest active request: quest #{quest_id} (active: #{active?}) not found or complete"
        )

        {:noreply, state}
    end
  end
end
