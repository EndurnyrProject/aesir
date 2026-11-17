defmodule Aesir.ZoneServer.Unit.Pet.StateCommit do
  @moduledoc """
  The only writer of `SessionState.pet`: replaces the pet and keeps its world
  presence (registry, spatial index, observers) in step.
  """

  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Player.Handlers.EquipProcHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit, as: PlayerStateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.WorldId

  @world_id_range 2..1_999_999

  @doc """
  Stores the pet and, while it is in the world, publishes its position and
  snapshot. A pet held off the map (before its first map load or during an
  owner warp) is only stored. The owner's `pet_bonus` follows the pet without
  a recompute; `sync_owner_bonus/1` recomputes.
  """
  @spec commit(SessionState.t(), PetState.t()) :: SessionState.t()
  def commit(
        %SessionState{pet: %PetState{world_gid: gid} = previous} = session,
        %PetState{world_gid: gid} = pet
      )
      when is_integer(gid) do
    if in_world?(gid), do: Movement.set_position(:pet, gid, pet, pet.map_name)
    session = %{session | pet: pet}

    if pet_info(pet) != pet_info(previous),
      do: put_owner_bonus(session),
      else: session
  end

  defp pet_info(%PetState{} = pet),
    do:
      Map.take(pet, [:pet_id, :class_id, :name, :intimate, :hungry, :rename_flag, :level, :egg_id])

  @doc """
  Stores the pet moved by a warp: it vanishes with the teleport reason and
  appears on its new cell (`Movement.warp_position/4`).
  """
  @spec commit_warp(SessionState.t(), PetState.t()) :: SessionState.t()
  def commit_warp(
        %SessionState{pet: %PetState{world_gid: gid}} = session,
        %PetState{world_gid: gid} = pet
      )
      when is_integer(gid) do
    Movement.warp_position(:pet, gid, pet, pet.map_name)
    %{session | pet: pet}
  end

  @doc """
  Claims a world id for the pet, registers it on its cell and shows it to the
  players in view, then publishes the owner's recompute (see
  `sync_owner_bonus/1`).
  """
  @spec spawn(SessionState.t(), PetState.t()) :: {:ok, SessionState.t()} | {:error, :exhausted}
  def spawn(
        %SessionState{pet: nil, game_state: %{stats: %Stats{} = previous}} = session,
        %PetState{world_gid: nil} = pet
      ) do
    with {:ok, session} <- restore(session, pet),
         do: {:ok, session |> attach() |> publish_owner_bonus(previous)}
  end

  @doc """
  Stores a pet held off the map: its world id is claimed but it is not in the
  world until `attach/1`. The owner is recomputed but nothing is published:
  the login that restores it reconciles the equipment statuses and sends the
  skill list on map load.
  """
  @spec restore(SessionState.t(), PetState.t()) ::
          {:ok, SessionState.t()} | {:error, :exhausted}
  def restore(%SessionState{pet: nil} = session, %PetState{world_gid: nil} = pet) do
    with {:ok, gid} <- WorldId.allocate(@world_id_range, :pet) do
      session = %{session | pet: %{pet | world_gid: gid}}

      if definition(pet).bonus_program == [],
        do: {:ok, put_owner_bonus(session)},
        else: {:ok, recompute_owner(session)}
    end
  end

  @doc """
  Writes the owner's `pet_bonus` from the pet (`nil` with no pet) and
  recomputes the owner's stats as a full recalculation, then publishes it: a
  changed set of granted skills resends the skill list, and the equipment
  statuses are reconciled with the ones the programs now start.
  """
  @spec sync_owner_bonus(SessionState.t()) :: SessionState.t()
  def sync_owner_bonus(%SessionState{game_state: %{stats: %Stats{} = previous}} = session),
    do: session |> recompute_owner() |> publish_owner_bonus(previous)

  defp recompute_owner(%SessionState{game_state: %{stats: %Stats{} = stats} = owner} = session) do
    stats = %{stats | pet_bonus: pet_bonus(session.pet)}

    session
    |> PlayerStateCommit.commit(%{owner | stats: Stats.force_full_recalculation(stats)})
    |> StatusManager.recalculate_after_status_change()
  end

  defp publish_owner_bonus(%SessionState{game_state: %{stats: stats}} = session, previous) do
    if Stats.granted_skills(stats) != Stats.granted_skills(previous),
      do: SkillLearningHandler.refresh_skill_list(session)

    {:noreply, session} = EquipProcHandler.reconcile_inventory_change(session)
    session
  end

  defp put_owner_bonus(%SessionState{game_state: %{stats: %Stats{} = stats} = owner} = session) do
    case pet_bonus(session.pet) do
      unchanged when unchanged == stats.pet_bonus ->
        session

      pet_bonus ->
        PlayerStateCommit.commit(session, %{owner | stats: %{stats | pet_bonus: pet_bonus}})
    end
  end

  defp pet_bonus(nil), do: nil

  defp pet_bonus(%PetState{} = pet) do
    definition = definition(pet)

    %{
      program: definition.bonus_program,
      inputs: %{
        pet: %{
          id: pet.pet_id,
          class: pet.class_id,
          name: pet.name,
          intimate: pet.intimate,
          hungry: pet.hungry,
          renamed: pet.rename_flag,
          level: pet.level,
          block_id: pet.world_gid,
          egg_id: pet.egg_id,
          food_id: definition.food_item_id
        }
      },
      skill_bonus: nil
    }
  end

  defp definition(%PetState{class_id: class_id}) do
    {:ok, definition} = Catalog.by_mob(class_id)
    definition
  end

  @doc "Puts a pet held off the map into the world on its cell."
  @spec attach(SessionState.t()) :: SessionState.t()
  def attach(%SessionState{pet: %PetState{world_gid: gid} = pet} = session)
      when is_integer(gid) do
    UnitRegistry.register_unit(:pet, gid, PetState, pet, self())
    Movement.set_position(:pet, gid, pet, pet.map_name)
    session
  end

  @doc """
  Takes the pet out of the world out of sight, keeping its world id, and
  stores it as `pet` (an owner warp moves it to the destination meanwhile).
  """
  @spec detach(SessionState.t(), PetState.t()) :: SessionState.t()
  def detach(
        %SessionState{pet: %PetState{world_gid: gid} = current} = session,
        %PetState{world_gid: gid} = pet
      )
      when is_integer(gid) do
    leave_world(current, DespawnReason.out_of_sight())
    UnitRegistry.detach_unit(:pet, gid)
    %{session | pet: pet}
  end

  @doc """
  Takes the pet out of the world with `reason` for every observer, releases
  its world id and clears `session.pet`, then recomputes and publishes the
  owner without the pet bonus (`sync_owner_bonus/1`). Every pet timer
  is cancelled and the runtime reset with a bumped generation, so stale timer
  events are dropped; the owner's catch process is kept.
  """
  @spec remove(SessionState.t(), DespawnReason.t()) :: SessionState.t()
  def remove(
        %SessionState{pet: %PetState{world_gid: gid} = pet, pet_runtime: %Runtime{} = runtime} =
          session,
        reason
      )
      when is_integer(gid) do
    leave_world(pet, reason)
    UnitRegistry.unregister_unit(:pet, gid)

    sync_owner_bonus(%{session | pet: nil, pet_runtime: free_runtime(runtime)})
  end

  defp leave_world(%PetState{world_gid: gid} = pet, reason) do
    if in_world?(gid) do
      SpawnView.notify_despawn(pet, reason)
      Movement.clear_dirty(pet.map_name, :pet, gid)
      SpatialIndex.remove_unit(:pet, gid)
    end
  end

  defp in_world?(gid), do: match?({:ok, _}, SpatialIndex.get_unit_position(:pet, gid))

  defp free_runtime(%Runtime{} = runtime) do
    timers = [
      runtime.hunger_timer_ref,
      runtime.ai_timer_ref,
      runtime.movement_timer_ref,
      runtime.teleport_timer_ref,
      runtime.skill_bonus_timer_ref,
      runtime.recovery_timer_ref,
      runtime.support_skill_timer_ref
      | Map.values(runtime.autobonus_timers)
    ]

    Enum.each(timers, &Clock.cancel/1)
    %Runtime{generation: runtime.generation + 1, catch_process: runtime.catch_process}
  end
end
