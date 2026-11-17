defmodule Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler do
  @moduledoc "Routes owner pet commands and timer events."

  require Logger

  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc "Replies to a pet request."
  @spec request(PetRequest.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def request(%PetRequest{} = request, %SessionState{} = session) do
    error = if is_nil(session.pet), do: :PET_ERROR_NO_PET, else: :PET_ERROR_INVALID_REQUEST

    MessageRouter.send_to(session.connection_pid, %PetResult{
      request_id: request.request_id,
      success: false,
      error: error
    })

    {:noreply, session}
  end

  @doc "Handles an asynchronous pet command."
  @spec cast(term(), SessionState.t()) :: {:noreply, SessionState.t()}
  def cast(command, %SessionState{} = session) do
    Logger.warning("Unsupported pet cast: #{inspect(command)}")
    {:noreply, session}
  end

  @doc "Handles a synchronous pet command."
  @spec call(term(), GenServer.from(), SessionState.t()) :: {:reply, term(), SessionState.t()}
  def call(_command, _from, %SessionState{} = session),
    do: {:reply, {:error, :invalid_request}, session}

  @doc "Drops obsolete timer events and handles current pet timer events."
  @spec info(term(), reference(), SessionState.t()) :: {:noreply, SessionState.t()}
  def info(
        {_event, generation},
        _ref,
        %SessionState{pet_runtime: %{generation: current}} = session
      )
      when generation != current, do: {:noreply, session}

  def info(event, _ref, %SessionState{} = session) do
    Logger.warning("Unsupported pet info event: #{inspect(event)}")
    {:noreply, session}
  end
end
