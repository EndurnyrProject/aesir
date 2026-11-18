defmodule Aesir.ZoneServer.Unit.Pet.Handlers.AiHandler do
  @moduledoc "The pet's 100 ms think."

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @think_ms 100
  @follow_range 3

  @doc "Arms exactly one think timer while a pet is out."
  @spec arm(SessionState.t()) :: SessionState.t()
  def arm(%SessionState{pet_runtime: runtime} = session) do
    Clock.cancel(runtime.ai_timer_ref)
    ref = if session.pet, do: Clock.arm(@think_ms, :ai_tick, runtime.generation)
    %{session | pet_runtime: %{runtime | ai_timer_ref: ref}}
  end

  @doc "Thinks once for the think timer `ref` and rearms; any other timer is ignored."
  @spec tick(reference(), SessionState.t()) :: SessionState.t()
  def tick(ref, %SessionState{pet_runtime: %{ai_timer_ref: ref} = runtime} = session)
      when is_reference(ref) do
    %{session | pet_runtime: %{runtime | ai_timer_ref: nil}}
    |> think(System.monotonic_time(:millisecond))
    |> arm()
  end

  def tick(_ref, %SessionState{} = session), do: session

  @doc """
  One think: nothing while busy, on another map, or two steps into a walk;
  random walk at intimacy 0; chase an owner beyond the mob's chase range at
  half the owner's speed; back in range restore the normal speed once the
  walk ends; then the target step; else follow to `MovementHandler.calc_pos/2`
  unless within 3 cells of the owner or already walking there.
  """
  @spec think(SessionState.t(), integer()) :: SessionState.t()
  def think(%SessionState{pet: %PetState{} = pet, game_state: owner} = session, now_ms) do
    cond do
      pet.action_state in [:attacking, :casting] or pet.map_name != owner.map_name ->
        session

      MovementHandler.walking?(session) and session.pet_runtime.path_pos <= 2 ->
        session

      pet.intimate <= 0 ->
        MovementHandler.random_walk(session, now_ms)

      distance(pet, owner) > chase_range(pet) ->
        chase(session, now_ms)

      true ->
        in_range(session, now_ms)
    end
  end

  def think(%SessionState{} = session, _now_ms), do: session

  @doc "The target and loot step of the think; pets act on nothing yet."
  @spec target_step(SessionState.t(), integer()) :: {:none | :acted, SessionState.t()}
  def target_step(%SessionState{} = session, _now_ms), do: {:none, session}

  defp chase(%SessionState{pet: pet, game_state: owner, pet_runtime: runtime} = session, now_ms) do
    cond do
      MovementHandler.walking?(session) and runtime.chase_owner ->
        session

      is_integer(runtime.can_move_at_ms) and now_ms < runtime.can_move_at_ms ->
        session

      true ->
        speed = max(div(StatusManager.current_walk_speed(owner), 2), 1)
        session = StateCommit.commit(session, %{pet | walk_speed: speed})

        session
        |> MovementHandler.walk_to({owner.x, owner.y}, now: now_ms, chase_owner: true)
        |> or_random_walk(session, now_ms)
    end
  end

  defp in_range(%SessionState{pet: pet, game_state: owner} = session, now_ms) do
    base = PetState.base_walk_speed(pet.mob_db_id, owner)

    cond do
      pet.walk_speed == base ->
        target_or_follow(session, now_ms)

      MovementHandler.walking?(session) ->
        session

      true ->
        session |> StateCommit.commit(%{pet | walk_speed: base}) |> target_or_follow(now_ms)
    end
  end

  defp target_or_follow(session, now_ms) do
    {_none, session} = target_step(session, now_ms)
    follow(session, now_ms)
  end

  defp follow(%SessionState{pet: pet, game_state: owner} = session, now_ms) do
    cond do
      distance(pet, owner) <= @follow_range ->
        session

      MovementHandler.walking?(session) and walking_to_owner?(session) ->
        session

      true ->
        session
        |> MovementHandler.walk_to(MovementHandler.calc_pos(pet, owner), now: now_ms)
        |> or_random_walk(session, now_ms)
    end
  end

  defp walking_to_owner?(%SessionState{game_state: owner} = session) do
    {x, y} = MovementHandler.destination(session)
    Geometry.chebyshev_distance(owner.x, owner.y, x, y) <= @follow_range
  end

  defp or_random_walk({:ok, session}, _before, _now_ms), do: session

  defp or_random_walk({:error, :unreachable}, session, now_ms),
    do: MovementHandler.random_walk(session, now_ms)

  defp chase_range(%PetState{mob_db_id: mob_db_id}) do
    {:ok, mob} = Mobs.by_id(mob_db_id)
    mob.chase_range
  end

  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}), do: Geometry.chebyshev_distance(x1, y1, x2, y2)
end
