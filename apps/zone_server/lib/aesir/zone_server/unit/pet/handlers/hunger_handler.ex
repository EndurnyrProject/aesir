defmodule Aesir.ZoneServer.Unit.Pet.Handlers.HungerHandler do
  @moduledoc """
  The pet's hunger timer, feeding, intimacy and autofeed.

  Hunger drops by the pet's fullness every hunger delay (scaled by
  `pet_hungry_delay_rate`); below 0 it stays at 0, costs intimacy and the
  timer ticks every 20 s. Intimacy is clamped to 0..1000 and mirrored in the
  egg's `card3` grade; at 0 the egg is deleted and the pet runs away.

  Every change is saved when it happens.
  """

  import Bitwise

  require Logger

  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.PetFoodResult
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Mmo.PetManagement.PetDefinition
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerEvents
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit

  @starving_interval_ms 20_000
  @hungry_satisfied 90
  @hungry_neutral 75
  @hungry_stuffed 100
  @intimate_max 1000

  @doc """
  Arms the hunger timer of a pet that just came out: the scaled hunger delay,
  or 20 s when hunger is already 0, at least 1 ms.
  """
  @spec arm(SessionState.t()) :: SessionState.t()
  def arm(%SessionState{pet: %PetState{} = pet} = session) do
    interval = if pet.hungry <= 0, do: @starving_interval_ms, else: hungry_delay(pet)
    schedule(session, interval)
  end

  def arm(%SessionState{} = session), do: session

  @doc """
  One hunger tick. A pet that ran away (intimacy 0) stops here. Otherwise
  hunger drops by the fullness; below 0 it stays at 0, intimacy changes by
  `intimacy_hungry` (INTIMACY to the owner) and the next tick is in 20 s.
  HUNGER goes to the owner when the value changed, then autofeed feeds a pet
  at or below `feature_pet_autofeed_rate`.
  """
  @spec tick(SessionState.t()) :: SessionState.t()
  def tick(%SessionState{pet_runtime: runtime} = session) do
    session = %{session | pet_runtime: %{runtime | hunger_timer_ref: nil}}

    case session.pet do
      %PetState{intimate: intimate} = pet when intimate > 0 -> starve(session, pet)
      _gone -> session
    end
  end

  defp starve(session, %PetState{} = pet) do
    definition = definition(pet)
    hungry = pet.hungry - definition.fullness

    {updated, recompute_at, interval} =
      if hungry < 0 do
        updated = pet |> Map.put(:hungry, 0) |> starving_intimacy(definition, session)
        {updated, updated, @starving_interval_ms}
      else
        {%{pet | hungry: hungry}, nil, hungry_delay(pet)}
      end

    session
    |> apply_change(pet, updated, recompute_at)
    |> autofeed()
    |> schedule(interval)
  end

  defp starving_intimacy(pet, definition, session) do
    pet = change_intimacy(pet, pet.intimate + definition.intimacy_hungry)
    if pet.intimate <= 0, do: run_away_speed(pet, session), else: pet
  end

  defp autofeed(%SessionState{pet: %PetState{} = pet} = session) do
    if Config.feature_pet_autofeed?() and pet.autofeed and
         pet.hungry <= Config.feature_pet_autofeed_rate(),
       do: feed(session),
       else: session
  end

  defp autofeed(session), do: session

  @doc """
  Feeds the pet one of its food. Without the food only the failure goes to
  the owner. A pet with no food item (id 0) is fed for free while the
  inventory has a free slot. Intimacy changes by `feed_delta/3` (at 0 after
  overfeeding the pet runs away) and the owner is recomputed, then hunger rises
  by `hunger_increase` up to 100 and HUNGER, INTIMACY and the success go to
  the owner.
  """
  @spec feed(SessionState.t()) :: SessionState.t()
  def feed(%SessionState{pet: %PetState{} = pet, game_state: owner} = session) do
    definition = definition(pet)
    food = definition.food_item_id

    case find_food(owner.inventory, food) do
      {:ok, index} -> fed(session, pet, definition, index)
      :error -> send_food_result(session, food, false)
    end
  end

  def feed(%SessionState{} = session), do: session

  defp fed(%SessionState{game_state: owner} = session, pet, definition, index) do
    {inventory, removed} = consume_food(owner.inventory, index)
    delta = feed_delta(definition, pet.hungry, Config.pet_friendly_rate())
    intimate = change_intimacy(pet, pet.intimate + delta)

    intimate =
      if pet.hungry > @hungry_satisfied and intimate.intimate <= 0,
        do: run_away_speed(intimate, session),
        else: intimate

    updated = %{intimate | hungry: min(pet.hungry + definition.hunger_increase, @hungry_stuffed)}

    case persist(session, pet, updated, inventory, removed, intimate) do
      {:ok, session} ->
        send_state_change(session, :PET_STATE_HUNGER, updated.hungry)
        send_state_change(session, :PET_STATE_INTIMACY, updated.intimate)
        send_food_result(session, definition.food_item_id, true)

      :error ->
        session
    end
  end

  @doc """
  The intimacy change of one feeding at `hungry`: `intimacy_overfed` above
  90, else `intimacy_fed` scaled by `friendly_rate` percent, halved (at least
  1) above 75.
  """
  @spec feed_delta(PetDefinition.t(), 0..100, integer()) :: integer()
  def feed_delta(%PetDefinition{} = definition, hungry, _friendly_rate)
      when hungry > @hungry_satisfied,
      do: definition.intimacy_overfed

  def feed_delta(%PetDefinition{} = definition, hungry, friendly_rate) do
    fed =
      if friendly_rate != 100,
        do: div(definition.intimacy_fed * friendly_rate, 100),
        else: definition.intimacy_fed

    if hungry > @hungry_neutral, do: max(div(fed, 2), 1), else: fed
  end

  @doc """
  Sets the pet's intimacy, clamped to 0..1000, and saves it: at 0 the egg is
  deleted, otherwise its `card3` keeps the rename bit and takes the new grade.
  The owner is recomputed on every call, an unchanged value included.
  """
  @spec set_intimate(SessionState.t(), integer()) :: SessionState.t()
  def set_intimate(%SessionState{pet: %PetState{} = pet} = session, value) do
    updated = change_intimacy(pet, value)
    apply_change(session, pet, updated, updated)
  end

  @doc """
  The owner died. Outside `noexppenalty` maps the pet's intimacy changes by
  `intimacy_owner_die` (at 0 the egg is deleted and the pet runs away at its
  current speed) and INTIMACY goes to the owner, even when unchanged.
  """
  @spec owner_died(SessionState.t()) :: SessionState.t()
  def owner_died(%SessionState{pet: %PetState{} = pet, game_state: owner} = session) do
    if MapFlags.get(owner.map_name, :noexppenalty) do
      session
    else
      session = set_intimate(session, pet.intimate + definition(pet).intimacy_owner_die)

      if session.pet.intimate == pet.intimate,
        do: send_state_change(session, :PET_STATE_INTIMACY, pet.intimate)

      session
    end
  end

  def owner_died(%SessionState{} = session), do: session

  @doc """
  Turns autofeed on or off. Ignored (`:error`) unless `feature_pet_autofeed`
  is on and the pet's species allows autofeed.
  """
  @spec set_autofeed(SessionState.t(), boolean()) :: {:ok, SessionState.t()} | :error
  def set_autofeed(%SessionState{pet: %PetState{} = pet} = session, enabled) do
    with true <- Config.feature_pet_autofeed?(),
         %PetDefinition{allow_auto_feed: true} <- definition(pet),
         {:ok, session} <-
           persist(
             session,
             pet,
             %{pet | autofeed: enabled},
             session.game_state.inventory,
             [],
             nil
           ) do
      {:ok, session}
    else
      _ignored -> :error
    end
  end

  def set_autofeed(%SessionState{}, _enabled), do: :error

  # Saves the change, then sends the owner INTIMACY and HUNGER when they changed.
  defp apply_change(%SessionState{game_state: owner} = session, pet, updated, recompute_at) do
    case persist(session, pet, updated, owner.inventory, [], recompute_at) do
      {:ok, session} ->
        if updated.intimate != pet.intimate,
          do: send_state_change(session, :PET_STATE_INTIMACY, updated.intimate)

        if updated.hungry != pet.hungry,
          do: send_state_change(session, :PET_STATE_HUNGER, updated.hungry)

        session

      :error ->
        session
    end
  end

  defp change_intimacy(pet, value), do: %{pet | intimate: value |> max(0) |> min(@intimate_max)}

  defp run_away_speed(pet, %SessionState{game_state: owner}),
    do: %{pet | walk_speed: PetState.base_walk_speed(pet.class_id, owner)}

  # Saves the pet with `inventory` (the owner's after the slots in `removed`
  # lost one item) and the egg upkeep: the egg is deleted at intimacy 0,
  # otherwise its card3 grade follows the intimacy. The owner is told about
  # every removal once saved. With `recompute_at`, the owner is recomputed
  # with that pet before `updated` is stored.
  defp persist(
         %SessionState{game_state: owner} = session,
         pet,
         updated,
         inventory,
         removed,
         recompute_at
       ) do
    {inventory, removed} = egg_upkeep(inventory, updated, removed)

    with %Pet{} = row <- Persistence.load(pet.pet_id),
         {:ok, inventory, _row} <-
           Persistence.save_with_inventory(
             row,
             row_attrs(updated),
             owner.character_id,
             owner.inventory,
             inventory
           ) do
      session = PlayerStateCommit.commit(session, %{owner | inventory: inventory})
      Enum.each(removed, &notify_removed(session, &1))
      {:ok, session |> recompute_owner(recompute_at) |> StateCommit.commit(updated)}
    else
      failure ->
        Logger.error("Failed to save pet #{pet.pet_id}: #{inspect(failure)}")
        :error
    end
  end

  defp recompute_owner(session, nil), do: session

  defp recompute_owner(session, %PetState{} = pet),
    do: session |> StateCommit.commit(pet) |> StateCommit.sync_owner_bonus()

  defp egg_upkeep(inventory, %PetState{} = pet, removed) do
    case egg_index(inventory, pet.pet_id) do
      nil ->
        {inventory, removed}

      index when pet.intimate <= 0 ->
        {:ok, inventory, _change} = Inventory.remove(inventory, index, 1)
        {inventory, removed ++ [index]}

      index ->
        egg = Map.fetch!(inventory, index)
        card3 = Egg.card3(egg.card3 &&& 1, pet.intimate)
        {%{inventory | index => %{egg | card3: card3}}, removed}
    end
  end

  defp egg_index(inventory, pet_id) do
    inventory
    |> Enum.filter(fn {_index, item} -> Egg.pet_id(item) == pet_id end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.min(fn -> nil end)
  end

  defp find_food(inventory, 0) do
    if Inventory.blank_slots(inventory) > 0, do: {:ok, nil}, else: :error
  end

  defp find_food(inventory, food) do
    case Inventory.stackable_index(inventory, food) do
      nil -> :error
      index -> {:ok, index}
    end
  end

  defp consume_food(inventory, nil), do: {inventory, []}

  defp consume_food(inventory, index) do
    {:ok, inventory, _change} = Inventory.remove(inventory, index, 1)
    {inventory, [index]}
  end

  defp notify_removed(%SessionState{game_state: owner} = session, index) do
    MessageRouter.send_to(session.connection_pid, InventoryView.item_removed(index, 1))
    PlayerEvents.inventory_changed(owner.character_id)
  end

  defp schedule(%SessionState{pet_runtime: runtime} = session, interval) do
    Clock.cancel(runtime.hunger_timer_ref)
    ref = Clock.arm(max(interval, 1), :hunger_tick, runtime.generation)
    %{session | pet_runtime: %{runtime | hunger_timer_ref: ref}}
  end

  defp hungry_delay(pet) do
    delay = definition(pet).hungry_delay_ms
    rate = Config.pet_hungry_delay_rate()
    if rate != 100, do: div(delay * rate, 100), else: delay
  end

  defp definition(%PetState{class_id: class_id}) do
    {:ok, definition} = Catalog.by_mob(class_id)
    definition
  end

  defp row_attrs(%PetState{} = pet),
    do: %{intimate: pet.intimate, hungry: pet.hungry, autofeed: pet.autofeed}

  defp send_state_change(%SessionState{pet: pet} = session, type, value) do
    MessageRouter.send_to(session.connection_pid, %PetStateChange{
      gid: pet.world_gid,
      type: type,
      value: value
    })
  end

  defp send_food_result(session, food, success) do
    MessageRouter.send_to(session.connection_pid, %PetFoodResult{
      success: success,
      food_item_id: food
    })

    session
  end
end
