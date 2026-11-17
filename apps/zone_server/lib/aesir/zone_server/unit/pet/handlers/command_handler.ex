defmodule Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler do
  @moduledoc "Routes owner pet commands and timer events."

  require Logger

  alias Aesir.Net.PetCatchTargetCommand
  alias Aesir.Net.PetEquipAccessoryCommand
  alias Aesir.Net.PetMenuCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.Net.PetSelectEggCommand
  alias Aesir.Net.PetSetAutofeedCommand
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AccessoryHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CatchHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HatchHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipmentHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @performance_move_delay_ms 2_000

  @doc """
  Runs a pet request and replies with its `PetResult`. A catch pick needs no
  pet out and is always acknowledged, its outcome going in `PetCatchResult`;
  the menu needs a pet out with intimacy above 0. An accessory equip first
  passes the gear equip request checks; an accessory equip or unequip
  succeeds only when the pet's accessory changed.
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

  defp run({:select_egg, %PetSelectEggCommand{index: index}}, session) do
    selected = HatchHandler.select_egg(session, PlayerState.server_index(index))

    if is_nil(session.pet) and not is_nil(selected.pet),
      do: {:ok, selected},
      else: {{:error, :PET_ERROR_INVALID_REQUEST}, selected}
  end

  defp run({:catch_target, %PetCatchTargetCommand{target_id: target_id}}, session),
    do: {:ok, CatchHandler.finish(session, target_id)}

  defp run({:equip_accessory, %PetEquipAccessoryCommand{index: index}}, session) do
    server_index = PlayerState.server_index(index)

    with :ok <- EquipmentHandler.check_equip_request(server_index, session),
         %SessionState{pet: %PetState{}} <- session do
      session |> AccessoryHandler.equip(server_index) |> accessory_outcome(session)
    else
      :refused -> {{:error, :PET_ERROR_INVALID_REQUEST}, session}
      %SessionState{pet: nil} -> {{:error, :PET_ERROR_NO_PET}, session}
    end
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

  defp run({:menu, %PetMenuCommand{action: :PET_MENU_FEED}}, session),
    do: {:ok, HungerHandler.feed(session)}

  defp run({:menu, %PetMenuCommand{action: :PET_MENU_UNEQUIP}}, session),
    do: session |> AccessoryHandler.unequip() |> accessory_outcome(session)

  defp run({:menu, %PetMenuCommand{action: :PET_MENU_PERFORMANCE}}, session) do
    session = stop_for_performance(session)
    pet = session.pet
    {:ok, definition} = Catalog.by_mob(pet.class_id)
    value = performance_value(pet, definition, &:rand.uniform/1)

    Broadcast.to_in_range(pet.map_name, pet.x, pet.y, Config.view_range(), %PetStateChange{
      gid: pet.world_gid,
      type: :PET_STATE_PERFORMANCE,
      value: value
    })

    {:ok, session}
  end

  defp run({:menu, %PetMenuCommand{action: :PET_MENU_RETURN_TO_EGG}}, session) do
    case LifecycleHandler.return_to_egg(session) do
      %SessionState{pet: nil} = returned -> {:ok, returned}
      unchanged -> {{:error, :PET_ERROR_INVALID_REQUEST}, unchanged}
    end
  end

  defp run({:set_autofeed, %PetSetAutofeedCommand{enabled: enabled}}, session) do
    case HungerHandler.set_autofeed(session, enabled) do
      {:ok, session} -> {:ok, session}
      :error -> {{:error, :PET_ERROR_INVALID_REQUEST}, session}
    end
  end

  defp run(_command, session), do: {{:error, :PET_ERROR_INVALID_REQUEST}, session}

  # An accessory request succeeds only when the pet's accessory changed.
  defp accessory_outcome(%SessionState{pet: %PetState{equip: equip}} = handled, %SessionState{
         pet: %PetState{equip: equip}
       }),
       do: {{:error, :PET_ERROR_INVALID_REQUEST}, handled}

  defp accessory_outcome(handled, _requested), do: {:ok, handled}

  # Only a walking pet is stopped; its move lock becomes now + 2 s, replacing any other.
  defp stop_for_performance(session) do
    if MovementHandler.walking?(session) do
      %SessionState{pet_runtime: runtime} = session = MovementHandler.stop(session)
      now = System.monotonic_time(:millisecond)
      %{session | pet_runtime: %{runtime | can_move_at_ms: now + @performance_move_delay_ms}}
    else
      session
    end
  end

  @doc """
  The performance shown: `roll.(n)` with n 4 above intimacy 910 for a species
  with special performances, 3 above 910, 2 above 750, else 1.
  """
  @spec performance_value(PetState.t(), PetDefinition.t(), (pos_integer() -> pos_integer())) ::
          1..4
  def performance_value(%PetState{intimate: intimacy}, %PetDefinition{} = definition, roll) do
    max_value =
      cond do
        intimacy > 910 and definition.special_performance -> 4
        intimacy > 910 -> 3
        intimacy > 750 -> 2
        true -> 1
      end

    roll.(max_value)
  end

  @doc """
  Handles an asynchronous pet command: `{:birthpet}` opens the egg list and
  `{:catchpet, lure_id, flag}` starts a catch.
  """
  @spec cast(term(), SessionState.t()) :: {:noreply, SessionState.t()}
  def cast({:birthpet}, %SessionState{} = session),
    do: {:noreply, HatchHandler.open_egg_list(session)}

  def cast({:catchpet, lure_id, flag}, %SessionState{} = session),
    do: {:noreply, CatchHandler.start(session, lure_id, flag)}

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

  def info(
        {:hunger_tick, _generation},
        ref,
        %SessionState{pet_runtime: %{hunger_timer_ref: ref}} = session
      )
      when is_reference(ref),
      do: {:noreply, HungerHandler.tick(session)}

  def info({:hunger_tick, _generation}, _ref, %SessionState{} = session), do: {:noreply, session}

  def info(event, _ref, %SessionState{} = session) do
    Logger.warning("Unsupported pet info event: #{inspect(event)}")
    {:noreply, session}
  end
end
