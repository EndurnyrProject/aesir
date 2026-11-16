defmodule Aesir.ZoneServer.Unit.Pet.StateCommit do
  @moduledoc """
  The only writer of `SessionState.pet`: replaces the pet and keeps its world
  presence (registry, spatial index, observers) in step.
  """

  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Pet.SpawnView
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.WorldId

  @world_id_range 2..1_999_999

  @doc "Stores the pet already in the world and publishes its position and snapshot."
  @spec commit(SessionState.t(), PetState.t()) :: SessionState.t()
  def commit(
        %SessionState{pet: %PetState{world_gid: gid}} = session,
        %PetState{world_gid: gid} = pet
      )
      when is_integer(gid) do
    Movement.set_position(:pet, gid, pet, pet.map_name)
    %{session | pet: pet}
  end

  @doc """
  Claims a world id for the pet, registers it on its cell and shows it to the
  players in view.
  """
  @spec spawn(SessionState.t(), PetState.t()) :: {:ok, SessionState.t()} | {:error, :exhausted}
  def spawn(%SessionState{pet: nil} = session, %PetState{world_gid: nil} = pet) do
    with {:ok, gid} <- WorldId.allocate(@world_id_range, :pet) do
      pet = %{pet | world_gid: gid}
      UnitRegistry.register_unit(:pet, gid, PetState, pet, self())
      Movement.set_position(:pet, gid, pet, pet.map_name)
      {:ok, %{session | pet: pet}}
    end
  end

  @doc """
  Takes the pet out of the world with `reason` for every observer, clears
  `session.pet` and bumps the runtime generation so its timers go stale.
  """
  @spec remove(SessionState.t(), DespawnReason.t()) :: SessionState.t()
  def remove(
        %SessionState{pet: %PetState{world_gid: gid} = pet, pet_runtime: %Runtime{} = runtime} =
          session,
        reason
      )
      when is_integer(gid) do
    SpawnView.notify_despawn(pet, reason)
    Movement.clear_dirty(pet.map_name, :pet, gid)
    SpatialIndex.remove_unit(:pet, gid)
    UnitRegistry.unregister_unit(:pet, gid)

    %{session | pet: nil, pet_runtime: %{runtime | generation: runtime.generation + 1}}
  end
end
