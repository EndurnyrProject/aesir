defmodule Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler do
  @moduledoc "Routes owner pet commands and timer events."

  require Logger

  alias Aesir.Net.PetMenuCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @doc """
  Runs a pet request and replies with its `PetResult`. The menu (`pet_menu`,
  `pet.cpp:1422`) needs a pet out with intimacy above 0.
  """
  @spec request(PetRequest.t(), SessionState.t()) :: {:noreply, SessionState.t()}
  def request(%PetRequest{} = request, %SessionState{} = session) do
    {result, session} = run(request.command, session)

    reply =
      case result do
        :ok ->
          %PetResult{request_id: request.request_id, success: true}

        {:error, error} ->
          %PetResult{request_id: request.request_id, success: false, error: error}
      end

    MessageRouter.send_to(session.connection_pid, reply)
    {:noreply, session}
  end

  defp run(_command, %SessionState{pet: nil} = session),
    do: {{:error, :PET_ERROR_NO_PET}, session}

  defp run(
         {:menu, %PetMenuCommand{}},
         %SessionState{pet: %PetState{intimate: intimate}} = session
       )
       when intimate <= 0,
       do: {{:error, :PET_ERROR_INVALID_REQUEST}, session}

  defp run({:menu, %PetMenuCommand{action: :PET_MENU_STATUS}}, session) do
    LifecycleHandler.send_private_state(session)
    {:ok, session}
  end

  defp run({:menu, %PetMenuCommand{action: :PET_MENU_RETURN_TO_EGG}}, session) do
    case LifecycleHandler.return_to_egg(session) do
      %SessionState{pet: nil} = returned -> {:ok, returned}
      unchanged -> {{:error, :PET_ERROR_INVALID_REQUEST}, unchanged}
    end
  end

  defp run(_command, session), do: {{:error, :PET_ERROR_INVALID_REQUEST}, session}

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

  def info({:ai_tick, _generation}, ref, %SessionState{} = session),
    do: {:noreply, AiHandler.tick(ref, session)}

  def info({:move_step, _generation}, ref, %SessionState{} = session),
    do: {:noreply, MovementHandler.step(ref, session)}

  def info({:recall, _generation}, ref, %SessionState{} = session),
    do: {:noreply, MovementHandler.recall_timeout(ref, session)}

  def info(event, _ref, %SessionState{} = session) do
    Logger.warning("Unsupported pet info event: #{inspect(event)}")
    {:noreply, session}
  end
end
