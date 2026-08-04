defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.ItemEffectHandler do
  @moduledoc """
  Validates and atomically commits staged Homunculus item effects.
  """

  require Logger

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.Net.ItemUseResult
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.PrivateStateView
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @type effect :: :homunculus_evolution | {:homunculus_intimacy, pos_integer()}
  @type opts :: [roll: (non_neg_integer(), non_neg_integer() -> non_neg_integer())]

  @spec handle(non_neg_integer(), non_neg_integer(), effect(), SessionState.t(), opts()) ::
          {:noreply, SessionState.t()}
  def handle(client_index, server_index, effect, %SessionState{} = session, opts \\ []) do
    case transition(server_index, effect, session, opts) do
      {:ok, inventory, homunculus} ->
        committed = commit(session, inventory, homunculus)
        publish_success(committed, client_index, server_index)
        {:noreply, clear_private_dirty(committed)}

      {:error, {:persistence, reason}} ->
        Logger.error("Homunculus item transition failed: #{inspect(reason)}")
        {:noreply, session}

      {:error, _reason} ->
        {:noreply, session}
    end
  end

  @doc "Atomically settles one owner inventory cost with an already-settled Homunculus cast."
  @spec settle_skill_cost(SessionState.t(), HomunculusState.t(), pos_integer(), pos_integer()) ::
          {:ok, SessionState.t(), non_neg_integer()} | {:error, term()}
  def settle_skill_cost(
        %SessionState{} = session,
        %HomunculusState{} = updated,
        item_id,
        amount
      )
      when is_integer(item_id) and item_id > 0 and is_integer(amount) and amount > 0 do
    character_id = session.game_state.character_id
    inventory = session.game_state.inventory
    runtime = session.homunculus_runtime
    now_ms = Clock.now_ms()

    with %HomunculusState{id: id, owner_character_id: ^character_id} <- session.homunculus,
         %HomunculusState{id: ^id, owner_character_id: ^character_id} <- updated,
         %Homunculus{id: ^id} = row <- Persistence.load_for_character(character_id),
         index when is_integer(index) <- Inventory.stackable_index(inventory, item_id),
         {:ok, removed_inventory, change} <- Inventory.remove(inventory, index, amount),
         {:ok, clocks} <-
           Clock.durable_snapshot(
             updated.lifecycle,
             runtime.active_deadline_ms,
             updated.cooldowns,
             now_ms
           ),
         attrs <-
           updated
           |> ProgressionHandler.persistence_attrs()
           |> Map.merge(clocks),
         {:ok, persisted_inventory, _row} <-
           Persistence.transition_with_item(
             character_id,
             row,
             attrs,
             inventory,
             {removed_inventory, change}
           ) do
      settled = Map.update!(session, :game_state, &%{&1 | inventory: persisted_inventory})
      {:ok, settled, index}
    else
      nil -> {:error, :missing_item}
      false -> {:error, :invalid_homunculus}
      {:error, {operation, reason}} -> {:error, {:persistence, {operation, reason}}}
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, :invalid_homunculus}
    end
  end

  def settle_skill_cost(%SessionState{}, %HomunculusState{}, _item_id, _amount),
    do: {:error, :invalid_item_cost}

  @doc "Notifies the owner after a committed Homunculus skill consumed an inventory stack."
  @spec publish_skill_cost(SessionState.t(), non_neg_integer(), pos_integer()) :: :ok
  def publish_skill_cost(%SessionState{} = session, index, amount)
      when is_integer(index) and index >= 0 and is_integer(amount) and amount > 0 do
    MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, amount))
    :ok
  end

  defp transition(server_index, effect, session, opts) do
    homunculus = session.homunculus
    character_id = session.game_state.character_id

    with %Homunculus{id: id} = row <- Persistence.load_for_character(character_id),
         true <- is_struct(homunculus, HomunculusState) and id == homunculus.id,
         {:ok, updated} <- apply_effect(effect, homunculus, opts),
         {:ok, inventory, change} <-
           Inventory.remove(session.game_state.inventory, server_index, 1),
         {:ok, persisted_inventory, _row} <-
           persist(character_id, row, updated, session.game_state.inventory, inventory, change) do
      {:ok, persisted_inventory, updated}
    else
      {:error, {operation, reason}} -> {:error, {:persistence, {operation, reason}}}
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, :invalid_homunculus}
    end
  end

  defp apply_effect(:homunculus_evolution, homunculus, opts),
    do: ProgressionHandler.evolve(homunculus, opts)

  defp apply_effect({:homunculus_intimacy, amount}, homunculus, _opts)
       when is_integer(amount) and amount > 0 do
    with :ok <- require_active_living(homunculus) do
      {:ok,
       %{
         homunculus
         | intimacy_hundredths: min(homunculus.intimacy_hundredths + amount, 100_000)
       }}
    end
  end

  defp apply_effect(_effect, _homunculus, _opts), do: {:error, :invalid_effect}

  defp require_active_living(%HomunculusState{lifecycle: :active} = homunculus) do
    if Unit.living?(homunculus), do: :ok, else: {:error, :not_living}
  end

  defp require_active_living(%HomunculusState{}), do: {:error, :invalid_lifecycle}

  defp persist(character_id, row, updated, old_inventory, inventory, change) do
    case Persistence.transition_with_item(
           character_id,
           row,
           ProgressionHandler.persistence_attrs(updated),
           old_inventory,
           {inventory, change}
         ) do
      {:ok, persisted_inventory, persisted_row} ->
        {:ok, persisted_inventory, persisted_row}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp commit(session, inventory, homunculus) do
    session
    |> Map.update!(:game_state, &%{&1 | inventory: inventory})
    |> StateCommit.commit(homunculus)
  end

  defp publish_success(session, client_index, server_index) do
    MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(server_index, 1))

    MessageRouter.send_to(session.connection_pid, %ItemUseResult{
      index: client_index,
      ok: true,
      reason: 0
    })

    MessageRouter.send_to(
      session.connection_pid,
      PrivateStateView.build(session.homunculus, session.homunculus_runtime)
    )
  end

  defp clear_private_dirty(session) do
    %{session | homunculus_runtime: %{session.homunculus_runtime | private_dirty: false}}
  end
end
