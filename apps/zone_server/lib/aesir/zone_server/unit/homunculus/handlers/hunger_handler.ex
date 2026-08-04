defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.HungerHandler do
  @moduledoc """
  Persists Homunculus hunger, feeding, intimacy, and starvation transitions.

  Successful results are already durable. Errors return the original aggregate
  state and inventory so callers never commit partial effects.
  """

  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Inventory

  @type intimacy_grade ::
          :hate_with_passion | :hate | :awkward | :shy | :neutral | :cordial | :loyal
  @type inventory :: Inventory.t()
  @type timer_start :: (non_neg_integer(), atom() -> reference())
  @type timer_cancel :: (reference() -> term())
  @type timer_read :: (reference() -> non_neg_integer() | false)
  @type opts :: [
          timer_start: timer_start(),
          timer_cancel: timer_cancel(),
          timer_read: timer_read()
        ]
  @type result ::
          {:ok, HomunculusState.t() | nil, Runtime.t(), inventory()}
          | {:noop, HomunculusState.t(), Runtime.t(), inventory()}
          | {:error, term(), HomunculusState.t(), Runtime.t(), inventory()}

  @doc "Returns the fixed-point intimacy change for a pre-feed hunger value."
  @spec intimacy_delta(0..100) :: -50 | -5 | 50 | 75 | 100
  def intimacy_delta(hunger) when hunger in 0..10, do: 50
  def intimacy_delta(hunger) when hunger in 11..25, do: 100
  def intimacy_delta(hunger) when hunger in 26..75, do: 75
  def intimacy_delta(hunger) when hunger in 76..90, do: -5
  def intimacy_delta(hunger) when hunger in 91..100, do: -50

  @doc "Returns the canonical grade for fixed-point intimacy."
  @spec grade(0..100_000) :: intimacy_grade()
  def grade(intimacy) when intimacy in 0..399, do: :hate_with_passion
  def grade(intimacy) when intimacy in 400..1_099, do: :hate
  def grade(intimacy) when intimacy in 1_100..10_099, do: :awkward
  def grade(intimacy) when intimacy in 10_100..25_099, do: :shy
  def grade(intimacy) when intimacy in 25_100..75_099, do: :neutral
  def grade(intimacy) when intimacy in 75_100..91_099, do: :cordial
  def grade(intimacy) when intimacy in 91_100..100_000, do: :loyal

  @doc "Returns the delay selected from hunger before the next tick."
  @spec tick_delay(0..100) :: 20_000 | 60_000
  def tick_delay(hunger) when hunger in 0..10, do: 20_000
  def tick_delay(hunger) when hunger in 11..100, do: 60_000

  @doc "Arms the single hunger timer only for an online, active, living Homunculus."
  @spec arm(HomunculusState.t(), Runtime.t(), opts()) ::
          {:ok, HomunculusState.t(), Runtime.t()}
          | {:noop, HomunculusState.t(), Runtime.t()}
  def arm(homunculus, runtime, opts \\ [])

  def arm(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts) do
    if eligible?(homunculus, runtime) do
      cancel_timer(runtime.hunger_timer_ref, opts)
      timer_ref = start_timer(tick_delay(homunculus.hunger), opts)
      {:ok, homunculus, %{runtime | hunger_timer_ref: timer_ref}}
    else
      {:noop, homunculus, stop_hunger(runtime, opts)}
    end
  end

  @doc "Returns whether the inventory contains the catalog food for this species."
  @spec food_available?(pos_integer(), inventory()) :: boolean()
  def food_available?(class_id, inventory),
    do: match?({:ok, _index}, food_index(class_id, inventory))

  @doc "Returns the exact inventory stack index for the catalog food."
  @spec food_index(pos_integer(), inventory()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def food_index(class_id, inventory) do
    with {:ok, %{food: food}} <- catalog_food(class_id),
         {:ok, item} <- food_item(food),
         index when is_integer(index) <- Inventory.stackable_index(inventory, item.id) do
      {:ok, index}
    else
      nil -> {:error, :missing_food}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Consumes one catalog food and atomically persists its relationship transition."
  @spec feed(HomunculusState.t(), Runtime.t(), inventory(), opts()) :: result()
  def feed(homunculus, runtime, inventory, opts \\ [])

  def feed(%HomunculusState{} = homunculus, %Runtime{} = runtime, inventory, opts) do
    with true <- eligible?(homunculus, runtime),
         {:ok, new_inventory, change} <- food_removal(homunculus.class_id, inventory),
         {:ok, row} <- durable_row(homunculus) do
      persist_feed(row, homunculus, runtime, inventory, new_inventory, change, opts)
    else
      false -> {:error, :invalid_lifecycle, homunculus, runtime, inventory}
      {:error, reason} -> {:error, reason, homunculus, runtime, inventory}
    end
  end

  @doc "Feeds only when configured and due; unavailable food falls through as a no-op."
  @spec auto_feed(HomunculusState.t(), Runtime.t(), inventory(), opts()) :: result()
  def auto_feed(homunculus, runtime, inventory, opts \\ [])

  def auto_feed(
        %HomunculusState{ai_config: %Config{} = config} = homunculus,
        %Runtime{} = runtime,
        inventory,
        opts
      ) do
    if config.auto_feed and homunculus.hunger <= config.auto_feed_threshold do
      case feed(homunculus, runtime, inventory, opts) do
        {:error, :missing_food, ^homunculus, ^runtime, ^inventory} ->
          {:noop, homunculus, runtime, inventory}

        result ->
          result
      end
    else
      {:noop, homunculus, runtime, inventory}
    end
  end

  @doc "Handles a hunger timer delivery after reference and lifecycle revalidation."
  @spec tick(HomunculusState.t(), Runtime.t(), inventory(), reference(), opts()) :: result()
  def tick(homunculus, runtime, inventory, received_ref, opts \\ [])

  def tick(
        %HomunculusState{} = homunculus,
        %Runtime{} = runtime,
        inventory,
        received_ref,
        opts
      ) do
    cond do
      not Clock.current_timer?(runtime.hunger_timer_ref, received_ref) ->
        {:noop, homunculus, runtime, inventory}

      not eligible?(homunculus, runtime) ->
        {:noop, homunculus, stop_hunger(runtime, opts), inventory}

      remaining = read_timer(received_ref, opts) ->
        cancel_timer(received_ref, opts)
        timer_ref = start_timer(remaining, opts)
        {:ok, homunculus, %{runtime | hunger_timer_ref: timer_ref}, inventory}

      true ->
        persist_tick(homunculus, %{runtime | hunger_timer_ref: nil}, inventory, opts)
    end
  end

  defp persist_feed(row, homunculus, runtime, inventory, new_inventory, change, opts) do
    hunger = min(homunculus.hunger + 10, 100)

    intimacy =
      homunculus.intimacy_hundredths
      |> Kernel.+(intimacy_delta(homunculus.hunger))
      |> min(100_000)
      |> max(0)

    item_change = {new_inventory, change}

    if intimacy == 0 do
      case Persistence.delete(row, {inventory, item_change}) do
        {:ok, persisted_inventory, nil} ->
          {:ok, nil, stop_hunger(runtime, opts), persisted_inventory}

        {:error, reason} ->
          {:error, reason, homunculus, runtime, inventory}
      end
    else
      attrs = %{hunger: hunger, intimacy_hundredths: intimacy}

      case Persistence.transition_with_item(
             homunculus.owner_character_id,
             row,
             attrs,
             inventory,
             item_change
           ) do
        {:ok, persisted_inventory, _persisted} ->
          next = %{homunculus | hunger: hunger, intimacy_hundredths: intimacy}
          {:ok, next, reset_hunger(next, runtime, opts), persisted_inventory}

        {:error, reason} ->
          {:error, reason, homunculus, runtime, inventory}
      end
    end
  end

  defp food_removal(class_id, inventory) do
    case food_index(class_id, inventory) do
      {:ok, index} -> Inventory.remove(inventory, index, 1)
      {:error, reason} -> {:error, reason}
    end
  end

  defp catalog_food(class_id) do
    case Catalog.by_id(class_id) do
      {:ok, species} -> {:ok, species}
      :error -> {:error, :unknown_species}
    end
  end

  defp food_item(food) do
    case ItemManagement.get_item_by_aegis(food) do
      {:ok, item} -> {:ok, item}
      {:error, :item_not_found} -> {:error, :food_item_not_found}
    end
  end

  defp persist_tick(homunculus, runtime, inventory, opts) do
    case durable_row(homunculus) do
      {:ok, row} ->
        next_hunger = max(homunculus.hunger - 1, 0)
        next_intimacy = starvation_intimacy(homunculus)

        if next_intimacy == 0 do
          delete_starved(row, homunculus, runtime, inventory, opts)
        else
          save_tick(row, homunculus, runtime, inventory, next_hunger, next_intimacy, opts)
        end

      {:error, reason} ->
        retry_error(reason, homunculus, runtime, inventory, opts)
    end
  end

  defp save_tick(row, homunculus, runtime, inventory, hunger, intimacy, opts) do
    case Persistence.save_semantic(row, %{hunger: hunger, intimacy_hundredths: intimacy}) do
      {:ok, _persisted} ->
        next = %{homunculus | hunger: hunger, intimacy_hundredths: intimacy}
        {:ok, next, rearm(next, runtime, opts), inventory}

      {:error, reason} ->
        retry_error({:homunculus, reason}, homunculus, runtime, inventory, opts)
    end
  end

  defp delete_starved(row, homunculus, runtime, inventory, opts) do
    case Persistence.delete(row, inventory) do
      {:ok, persisted_inventory, nil} ->
        {:ok, nil, runtime, persisted_inventory}

      {:error, reason} ->
        retry_error(reason, homunculus, runtime, inventory, opts)
    end
  end

  defp retry_error(reason, homunculus, runtime, inventory, opts) do
    {:error, reason, homunculus, rearm(homunculus, runtime, opts), inventory}
  end

  defp durable_row(%HomunculusState{id: id, owner_character_id: character_id}) do
    case Persistence.load_for_character(character_id) do
      %{id: ^id} = row -> {:ok, row}
      nil -> {:error, :homunculus_not_found}
      _row -> {:error, :durable_state_mismatch}
    end
  end

  defp starvation_intimacy(%HomunculusState{hunger: 0, intimacy_hundredths: intimacy}),
    do: max(intimacy - 100, 0)

  defp starvation_intimacy(%HomunculusState{intimacy_hundredths: intimacy}), do: intimacy

  defp reset_hunger(homunculus, runtime, opts) do
    cancel_timer(runtime.hunger_timer_ref, opts)
    rearm(homunculus, runtime, opts)
  end

  defp rearm(homunculus, runtime, opts) do
    %{runtime | hunger_timer_ref: start_timer(tick_delay(homunculus.hunger), opts)}
  end

  defp stop_hunger(runtime, opts) do
    cancel_timer(runtime.hunger_timer_ref, opts)
    %{runtime | hunger_timer_ref: nil}
  end

  defp eligible?(%HomunculusState{} = homunculus, %Runtime{clocks_online: clocks_online}) do
    clocks_online and HomunculusState.living?(homunculus)
  end

  defp start_timer(delay, opts) do
    timer_start = Keyword.get(opts, :timer_start, &default_start_timer/2)
    timer_start.(delay, :hunger_tick)
  end

  defp default_start_timer(delay, event), do: Clock.arm(delay, event)

  defp cancel_timer(nil, _opts), do: :ok

  defp cancel_timer(ref, opts) do
    timer_cancel = Keyword.get(opts, :timer_cancel, &Process.cancel_timer/1)
    timer_cancel.(ref)
    :ok
  end

  defp read_timer(ref, opts) do
    timer_read = Keyword.get(opts, :timer_read, &Process.read_timer/1)
    timer_read.(ref)
  end
end
