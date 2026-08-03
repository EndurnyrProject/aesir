defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleSkillHandler do
  @moduledoc "Atomic inventory and Homunculus settlement for owner lifecycle skills."

  alias Aesir.Commons.Models.Homunculus
  alias Aesir.ZoneServer.Mmo.Homunculus.Ai.Config
  alias Aesir.ZoneServer.Mmo.Homunculus.Catalog, as: HomunculusCatalog
  alias Aesir.ZoneServer.Mmo.Skill.Catalog, as: SkillCatalog
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Persistence
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Homunculus.StateRestore
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @embryo_id 7142
  @seed_of_life_id 7140

  @type operation :: :call | :rest | {:resurrection, 1..5}

  @doc "Returns the lifecycle operation declared by a catalogued active skill."
  @spec operation(integer(), pos_integer()) :: operation() | nil
  def operation(skill_id, level) do
    with {:ok, definition} <- SkillCatalog.by_id(skill_id),
         {:ok, module} <- SkillCatalog.active_module_for(definition.name),
         true <- function_exported?(module, :lifecycle_operation, 0) do
      case module.lifecycle_operation() do
        :resurrection -> {:resurrection, level}
        operation -> operation
      end
    else
      _ -> nil
    end
  end

  @doc "Validates the latest aggregate and required item without changing it."
  @spec preflight(SessionState.t(), integer(), pos_integer(), integer() | nil) ::
          :ok | {:error, atom()}
  def preflight(session, skill_id, level, expected_id \\ nil) do
    case operation(skill_id, level) do
      nil -> :ok
      operation -> preflight_operation(session, operation, expected_id)
    end
  end

  @doc "Commits a validated lifecycle operation after owner resources have been prepared."
  @spec settle(SessionState.t(), map(), operation(), integer() | nil) ::
          {:ok, map(), HomunculusState.t(), struct(), Inventory.change() | nil, integer() | nil}
          | {:error, term()}
  def settle(%SessionState{} = session, charged_game_state, operation, expected_id \\ nil) do
    with :ok <- preflight_operation(session, operation, expected_id),
         :ok <- unchanged_inventory(session.game_state.inventory, charged_game_state.inventory),
         {:ok, planned, planned_runtime, inventory, item_change} <- plan(session, operation) do
      settle_planned(
        session,
        charged_game_state,
        operation,
        planned,
        planned_runtime,
        inventory,
        item_change
      )
    end
  end

  defp settle_planned(
         session,
         charged_game_state,
         operation,
         planned,
         planned_runtime,
         inventory,
         item_change
       ) do
    with {:ok, claim} <- reserve_activation(session, operation, planned) do
      case persist(session, planned, planned_runtime, inventory, item_change) do
        {:ok, persisted_inventory, persisted_row} ->
          settle_persisted(
            session,
            charged_game_state,
            operation,
            persisted_inventory,
            persisted_row,
            item_change,
            claim
          )

        {:error, _reason} = error ->
          release_activation(claim)
          error
      end
    end
  end

  defp settle_persisted(
         session,
         charged_game_state,
         operation,
         persisted_inventory,
         persisted_row,
         item_change,
         claim
       ) do
    case activate_committed(session, operation, persisted_row) do
      {:ok, homunculus, runtime} ->
        game_state = %{charged_game_state | inventory: persisted_inventory}

        {:ok, game_state, homunculus, runtime, item_change && elem(item_change, 1), claim}

      {:error, _reason} = error ->
        release_activation(claim)
        error
    end
  end

  defp reserve_activation(_session, :rest, _planned), do: {:ok, nil}

  defp reserve_activation(session, _operation, planned),
    do: StateCommit.reserve_activation(session, planned)

  defp release_activation(nil), do: :ok
  defp release_activation(gid), do: StateCommit.release_activation(gid)

  defp unchanged_inventory(inventory, inventory), do: :ok

  defp unchanged_inventory(_before, _charged),
    do: {:error, :inventory_changed_before_lifecycle}

  defp preflight_operation(session, :call, expected_id) do
    with :ok <- expected_identity(session.homunculus, expected_id),
         do: preflight_call_current(session)
  end

  defp preflight_operation(%{homunculus: %HomunculusState{} = homunculus} = session, :rest, id) do
    with :ok <- expected_identity(homunculus, id),
         do: LifecycleHandler.preflight_rest(homunculus, session.homunculus_runtime)
  end

  defp preflight_operation(_session, :rest, _id), do: {:error, :no_companion}

  defp preflight_operation(
         %{homunculus: %HomunculusState{} = homunculus} = session,
         {:resurrection, level},
         id
       ) do
    restored_hp = restored_hp(homunculus, level)

    with :ok <- expected_identity(homunculus, id),
         do:
           LifecycleHandler.preflight_resurrection(
             homunculus,
             restored_hp,
             session.homunculus_runtime
           )
  end

  defp preflight_operation(_session, {:resurrection, _level}, _id),
    do: {:error, :no_companion}

  defp preflight_call_current(%{homunculus: nil, game_state: game_state}),
    do: require_item(game_state.inventory, @embryo_id)

  defp preflight_call_current(session) do
    with :ok <- LifecycleHandler.preflight_call(session.homunculus, session.homunculus_runtime),
         do: require_item(session.game_state.inventory, @seed_of_life_id)
  end

  defp plan(%{homunculus: nil} = session, :call) do
    with {:ok, inventory, change} <- remove_item(session.game_state.inventory, @embryo_id),
         {:ok, created} <- initial_state(session.game_state.character_id),
         {:ok, planned, runtime} <-
           LifecycleHandler.first_creation(
             nil,
             created,
             session.homunculus_runtime,
             planning_opts()
           ) do
      {:ok, planned, runtime, inventory, {inventory, change}}
    end
  end

  defp plan(session, :call) do
    with {:ok, inventory, change} <- remove_item(session.game_state.inventory, @seed_of_life_id),
         {:ok, planned, runtime} <-
           LifecycleHandler.call(
             session.homunculus,
             session.homunculus_runtime,
             planning_opts()
           ) do
      {:ok, planned, runtime, inventory, {inventory, change}}
    end
  end

  defp plan(session, :rest) do
    with {:ok, planned, runtime} <-
           LifecycleHandler.voluntary_rest(
             session.homunculus,
             session.homunculus_runtime,
             planning_opts()
           ) do
      {:ok, planned, runtime, session.game_state.inventory, nil}
    end
  end

  defp plan(session, {:resurrection, level}) do
    with {:ok, planned, runtime} <-
           LifecycleHandler.resurrect(
             session.homunculus,
             restored_hp(session.homunculus, level),
             session.homunculus_runtime,
             planning_opts()
           ) do
      {:ok, planned, runtime, session.game_state.inventory, nil}
    end
  end

  defp persist(%{homunculus: nil} = session, planned, runtime, _inventory, item_change) do
    attrs = persistence_attrs(planned, runtime)

    Persistence.create_with_item(
      session.game_state.character_id,
      attrs,
      session.game_state.inventory,
      item_change
    )
  end

  defp persist(session, planned, runtime, _inventory, item_change) do
    with %Homunculus{id: id} = row <-
           Persistence.load_for_character(session.game_state.character_id),
         true <- id == session.homunculus.id do
      Persistence.transition_with_item(
        session.game_state.character_id,
        row,
        persistence_attrs(planned, runtime),
        session.game_state.inventory,
        item_change
      )
    else
      _ -> {:error, {:homunculus, :not_persisted}}
    end
  end

  defp activate_committed(%{homunculus: nil} = session, operation, %Homunculus{} = row) do
    with {:ok, persisted} <- StateRestore.restore(row) do
      activate(session, operation, persisted)
    end
  end

  defp activate_committed(session, operation, %Homunculus{}),
    do: activate(session, operation, session.homunculus)

  defp activate(session, :call, persisted) when is_nil(session.homunculus),
    do: LifecycleHandler.first_creation(nil, persisted, session.homunculus_runtime)

  defp activate(session, :call, _persisted),
    do: LifecycleHandler.call(session.homunculus, session.homunculus_runtime)

  defp activate(session, :rest, _persisted),
    do: LifecycleHandler.voluntary_rest(session.homunculus, session.homunculus_runtime)

  defp activate(session, {:resurrection, level}, _persisted),
    do:
      LifecycleHandler.resurrect(
        session.homunculus,
        restored_hp(session.homunculus, level),
        session.homunculus_runtime
      )

  defp persistence_attrs(state, runtime) do
    {:ok, clocks} =
      Clock.durable_snapshot(
        state.lifecycle,
        runtime.active_deadline_ms,
        state.cooldowns,
        Clock.now_ms()
      )

    state
    |> ProgressionHandler.persistence_attrs()
    |> Map.put(:active_remaining_ms, clocks.active_remaining_ms)
    |> Map.put(:cooldowns, clocks.cooldowns)
  end

  defp initial_state(character_id) do
    ids = HomunculusCatalog.initial_class_ids()
    selector = Application.get_env(:zone_server, :homunculus_initial_selector, &:rand.uniform/1)
    class_id = Enum.at(ids, selector.(length(ids)) - 1)

    with {:ok, species} <- HomunculusCatalog.by_id(class_id) do
      stats =
        Map.new(species.stats, fn {name, range} -> {String.to_existing_atom(name), range.base} end)

      {:ok,
       struct!(HomunculusState, %{
         id: 1,
         owner_character_id: character_id,
         class_id: class_id,
         name: species.name,
         lifecycle: :active,
         hp: stats.hp,
         max_hp: stats.hp,
         sp: stats.sp,
         max_sp: stats.sp,
         str: stats.str,
         agi: stats.agi,
         vit: stats.vit,
         int: stats.int,
         dex: stats.dex,
         luk: stats.luk,
         ai_config: Config.default([]),
         race: species.race,
         element: {species.element, 1},
         size: species.size,
         attack_delay_ms: species.attack_delay
       })}
    end
  end

  defp remove_item(inventory, item_id) do
    case Inventory.stackable_index(inventory, item_id) do
      nil -> {:error, :missing_item}
      index -> Inventory.remove(inventory, index, 1)
    end
  end

  defp require_item(inventory, item_id) do
    if Inventory.held_amount(inventory, item_id) > 0, do: :ok, else: {:error, :missing_item}
  end

  defp expected_identity(_homunculus, nil), do: :ok
  defp expected_identity(%HomunculusState{id: id}, id), do: :ok
  defp expected_identity(_homunculus, _id), do: {:error, :companion_changed}

  defp restored_hp(homunculus, level),
    do: max(div(homunculus.max_hp * 20 * level, 100), 1)

  defp planning_opts, do: [timer_start: &make_timer_ref/2, timer_cancel: &ignore_timer/1]
  defp make_timer_ref(_delay, _event), do: make_ref()
  defp ignore_timer(_ref), do: :ok
end
