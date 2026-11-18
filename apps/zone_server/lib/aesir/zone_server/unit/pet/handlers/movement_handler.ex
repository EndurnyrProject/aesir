defmodule Aesir.ZoneServer.Unit.Pet.Handlers.MovementHandler do
  @moduledoc """
  Walks the owner's pet: path stepping, the follow cell, random walk, the
  slide to the owner when the owner moves instantly, and the 3 s owner recall.
  """

  require Logger

  alias Aesir.Net.Knockback
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.StateCommit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @min_random_walk_ms 4_000
  @random_walk_tries 20
  @hold_after_fails 1_000
  @hold_ms 60_000
  @recall_delay_ms 3_000
  @calc_pos_tries 12
  @owner_chase_range 3

  @doc """
  Starts a walk to `goal`. A pet already walking takes the
  new goal on its next cell and succeeds. Fails while the pet cannot move
  (`opts[:now]` before `can_move_at_ms`) or when no walk path exists.
  `chase_owner: true` chases the owner at `goal` with chase range 3: the walk
  goes to the cell next to the owner, its path end trimmed to the range, and
  at the path end the chase stops within the range or out of sight, else
  chases again.
  """
  @spec walk_to(SessionState.t(), {integer(), integer()}, keyword()) ::
          {:ok, SessionState.t()} | {:error, :unreachable}
  def walk_to(%SessionState{pet: %PetState{} = pet, pet_runtime: runtime} = session, goal, opts) do
    now = Keyword.fetch!(opts, :now)
    chase? = Keyword.get(opts, :chase_owner, false)

    with true <- can_move?(runtime, now),
         {:ok, map} <- MapCache.get(pet.map_name),
         {:ok, goal} <- walk_goal(map, pet, goal, chase?),
         {:ok, session} <- begin_walk(session, map, goal, chase?) do
      {:ok, session}
    else
      _unreachable -> {:error, :unreachable}
    end
  end

  @doc "Whether a step timer is running."
  @spec walking?(SessionState.t()) :: boolean()
  def walking?(%SessionState{pet_runtime: runtime}), do: is_reference(runtime.movement_timer_ref)

  @doc "Where the current walk ends: the pending goal, else the path's last cell."
  @spec destination(SessionState.t()) :: {integer(), integer()} | nil
  def destination(%SessionState{pet_runtime: runtime}),
    do: runtime.walk_target || List.last(runtime.movement_path)

  @doc "Takes the step whose timer is `ref`; any other timer is stale and ignored."
  @spec step(reference(), SessionState.t()) :: SessionState.t()
  def step(ref, %SessionState{pet_runtime: %{movement_timer_ref: ref} = runtime} = session)
      when is_reference(ref),
      do: advance(%{session | pet_runtime: %{runtime | movement_timer_ref: nil}})

  def step(_ref, %SessionState{} = session), do: session

  @doc "Stops the walk where the pet stands."
  @spec stop(SessionState.t()) :: SessionState.t()
  def stop(%SessionState{pet_runtime: runtime} = session) do
    Clock.cancel(runtime.movement_timer_ref)

    runtime = %{
      runtime
      | movement_timer_ref: nil,
        movement_path: [],
        path_pos: 0,
        walk_target: nil,
        chase_owner: false
    }

    session = %{session | pet_runtime: runtime}

    case session.pet do
      %PetState{} = pet ->
        StateCommit.commit(session, %{pet | movement_state: :standing, action_state: :idle})

      nil ->
        session
    end
  end

  @doc """
  The follow cell: 2 cells behind the
  owner's facing, else 1, else up to 12 random directions (2 cells, then 1).
  When all fail it tries `(tx, tx)`, and its caller then walks to
  the owner's cell when that is unreachable too.
  """
  @spec calc_pos(PetState.t(), PlayerState.t()) :: {integer(), integer()}
  def calc_pos(%PetState{} = pet, %PlayerState{x: tx, y: ty, dir: dir}) do
    with :error <- behind(pet, tx, ty, dir),
         :error <- random_behind(pet, tx, ty, @calc_pos_tries) do
      if reachable?(pet, {tx, tx}), do: {tx, tx}, else: {tx, ty}
    else
      {:ok, cell} -> cell
    end
  end

  @doc """
  Random walk once the next walk time has
  passed and the pet can move: 20 tries within `max(12 - fails, 5)` cells; a
  total failure counts a fail, and past 1000 fails the pet holds for 60 s.
  The next walk is `now + 4000 + path cost + rnd(0..999)`.
  """
  @spec random_walk(SessionState.t(), integer()) :: SessionState.t()
  def random_walk(%SessionState{pet: %PetState{}, pet_runtime: runtime} = session, now)
      when (is_nil(runtime.next_walk_at_ms) or runtime.next_walk_at_ms < now) and
             (is_nil(runtime.can_move_at_ms) or runtime.can_move_at_ms <= now) do
    radius = max(12 - runtime.move_fail_count, 5)

    case try_random_walk(session, radius, now, @random_walk_tries) do
      {:ok, walked} ->
        walked |> put_runtime(move_fail_count: 0) |> schedule_next_walk(now)

      :failed when runtime.move_fail_count + 1 > @hold_after_fails ->
        Logger.warning("Pet can't move. Holding position #{session.pet.world_gid}")
        put_runtime(session, move_fail_count: 0, can_move_at_ms: now + @hold_ms)

      :failed ->
        session
        |> put_runtime(move_fail_count: runtime.move_fail_count + 1)
        |> schedule_next_walk(now)
    end
  end

  def random_walk(%SessionState{} = session, _now), do: session

  @doc """
  The pet check of an owner's instant move: a pet with
  intimacy above 0 moves to the owner's cell with a slide when the move was
  made without a path check (`checkpath? == false`) and the pet has no path to
  the owner, or when the pet is farther than the view range.
  """
  @spec slide_to_owner(SessionState.t(), boolean()) :: SessionState.t()
  def slide_to_owner(
        %SessionState{pet: %PetState{intimate: intimate} = pet, game_state: owner} = session,
        checkpath?
      )
      when intimate > 0 do
    if pet.map_name == owner.map_name and
         ((not checkpath? and not path?(pet, {owner.x, owner.y})) or far?(session)) do
      slide(session, owner)
    else
      session
    end
  end

  def slide_to_owner(session, _checkpath?), do: session

  @doc """
  The pet check at an owner walk start:
  a pet farther than the view range arms the 3 s recall unless one is armed;
  otherwise an armed recall is cancelled.
  """
  @spec check_recall(SessionState.t()) :: SessionState.t()
  def check_recall(%SessionState{pet: %PetState{}, pet_runtime: runtime} = session) do
    cond do
      not far?(session) ->
        Clock.cancel(runtime.teleport_timer_ref)
        put_runtime(session, teleport_timer_ref: nil)

      is_reference(runtime.teleport_timer_ref) ->
        session

      true ->
        ref = Clock.arm(@recall_delay_ms, :recall, runtime.generation)
        put_runtime(session, teleport_timer_ref: ref)
    end
  end

  def check_recall(session), do: session

  @doc """
  The recall firing: a pet still farther than the view
  range warps to the owner's cell; otherwise the recall just clears.
  """
  @spec recall_timeout(reference(), SessionState.t()) :: SessionState.t()
  def recall_timeout(ref, %SessionState{pet_runtime: %{teleport_timer_ref: ref}} = session)
      when is_reference(ref) do
    session = put_runtime(session, teleport_timer_ref: nil)

    if match?(%PetState{}, session.pet) and far?(session) do
      owner = session.game_state
      session = stop(session)
      StateCommit.commit_warp(session, %{session.pet | x: owner.x, y: owner.y})
    else
      session
    end
  end

  def recall_timeout(_ref, %SessionState{} = session), do: session

  # `max_walk_path` limits a plain walk only; a chase keeps the 14-step rule
  # alone.
  defp request_path(map, from, goal, true), do: Pathfinding.rewalk_path(map, from, goal)
  defp request_path(map, from, goal, false), do: Pathfinding.walk_path(map, from, goal)

  defp begin_walk(%SessionState{pet_runtime: runtime} = session, map, goal, chase?) do
    if walking?(session) do
      {:ok, %{session | pet_runtime: %{runtime | walk_target: goal, chase_owner: chase?}}}
    else
      with {:ok, cells} <- request_path(map, {session.pet.x, session.pet.y}, goal, chase?),
           do: {:ok, start_path(session, cells, chase?)}
    end
  end

  defp walk_goal(_map, _pet, goal, false), do: {:ok, goal}

  # The owner's neighbour on the pet's side, else the first passable neighbour
  # in direction order, with a CELL_CHKNOREACH path to it.
  defp walk_goal(map, %PetState{} = pet, {tx, ty}, true) do
    side = {sign(tx - pet.x), sign(ty - pet.y)}

    with {:ok, {dx, dy}} <- reach_offset(pet.map_name, tx, ty, side),
         cell = {tx - dx, ty - dy},
         {:ok, _cells} <- Pathfinding.rewalk_path(map, {pet.x, pet.y}, cell, cells: :noreach) do
      {:ok, cell}
    end
  end

  defp reach_offset(map_name, tx, ty, {dx, dy} = side) do
    if Cell.traversable?(map_name, tx - dx, ty - dy) do
      {:ok, side}
    else
      0..7
      |> Enum.map(&Geometry.facing_delta/1)
      |> Enum.find(fn {x, y} -> Cell.traversable?(map_name, tx - x, ty - y) end)
      |> then(&if(&1, do: {:ok, &1}, else: :error))
    end
  end

  defp can_move?(%{can_move_at_ms: nil}, _now), do: true
  defp can_move?(%{can_move_at_ms: at}, now), do: at <= now

  defp start_path(session, [], _chase?), do: session

  defp start_path(%SessionState{pet: pet, pet_runtime: runtime} = session, cells, chase?) do
    from = {pet.x, pet.y}
    cells = if chase?, do: trim(cells, from), else: cells

    runtime = %{
      runtime
      | movement_path: [from | cells],
        path_pos: 0,
        walk_target: nil,
        chase_owner: chase?
    }

    %{session | pet_runtime: runtime}
    |> StateCommit.commit(%{pet | movement_state: :moving, action_state: :moving})
    |> arm_step()
  end

  # A chase drops path cells from the end while the range
  # budget lasts, a diagonal costing twice a straight step, keeping one step.
  defp trim(cells, from), do: do_trim(Enum.reverse([from | cells]), @owner_chase_range * 10 - 10)

  defp do_trim([last, prev | _rest] = reversed, budget) when budget > 0 and length(reversed) > 2,
    do: do_trim(tl(reversed), budget - if(diagonal?(prev, last), do: 20, else: 10))

  defp do_trim(reversed, _budget), do: reversed |> Enum.reverse() |> tl()

  defp arm_step(%SessionState{pet: pet, pet_runtime: runtime} = session) do
    [from, next] = Enum.slice(runtime.movement_path, runtime.path_pos, 2)
    delay = MovementEngine.step_delay(pet.walk_speed, from, next)
    put_runtime(session, movement_timer_ref: Clock.arm(delay, :move_step, runtime.generation))
  end

  defp advance(%SessionState{pet: nil} = session), do: stop(session)

  defp advance(%SessionState{pet: pet, pet_runtime: runtime} = session) do
    case Enum.at(runtime.movement_path, runtime.path_pos + 1) do
      {x, y} = next ->
        if Cell.traversable?(pet.map_name, x, y),
          do: session |> move_onto(next) |> continue_walk(),
          else: stop(session)

      nil ->
        stop(session)
    end
  end

  defp move_onto(%SessionState{pet: pet, pet_runtime: runtime} = session, {x, y}) do
    dir = Geometry.calculate_direction(pet.x, pet.y, x, y)

    %{session | pet_runtime: %{runtime | path_pos: runtime.path_pos + 1}}
    |> StateCommit.commit(%{pet | x: x, y: y, dir: dir})
  end

  defp continue_walk(%SessionState{pet_runtime: runtime} = session) do
    cond do
      runtime.walk_target != nil -> redirect(session)
      runtime.path_pos + 1 < length(runtime.movement_path) -> arm_step(session)
      runtime.chase_owner -> update_chase(session)
      true -> stop(session)
    end
  end

  # At the path end: stop within the chase range or with
  # the owner out of sight, else chase again once the pet can move.
  defp update_chase(%SessionState{pet: pet, game_state: owner} = session) do
    now = System.monotonic_time(:millisecond)

    with true <- distance(pet, owner) > @owner_chase_range and owner_visible?(pet, owner),
         {:ok, chased} <- walk_to(session, {owner.x, owner.y}, now: now, chase_owner: true) do
      chased
    else
      _stop -> stop(session)
    end
  end

  # Visibility from a pet: same map, within its `range2`, and the owner not
  # concealed from it. A pet has no mob modes or class, so it is never a boss
  # or detector.
  defp owner_visible?(%PetState{} = pet, %PlayerState{} = owner) do
    {:ok, mob} = Mobs.by_id(pet.mob_db_id)
    viewer = %{class: :normal, detector: false}

    pet.map_name == owner.map_name and distance(pet, owner) <= mob.skill_range and
      Targeting.attack_visible?(viewer, %{unit_type: :player, unit_id: owner.character_id})
  end

  defp redirect(%SessionState{pet: pet, pet_runtime: runtime} = session) do
    goal = runtime.walk_target

    with {:ok, map} <- MapCache.get(pet.map_name),
         {:ok, [_ | _] = cells} <- Pathfinding.rewalk_path(map, {pet.x, pet.y}, goal) do
      start_path(put_runtime(session, walk_target: nil), cells, runtime.chase_owner)
    else
      _blocked -> stop(session)
    end
  end

  defp try_random_walk(_session, _radius, _now, 0), do: :failed

  defp try_random_walk(%SessionState{pet: pet} = session, radius, now, tries) do
    x = pet.x + Enum.random(-radius..radius)
    y = pet.y + Enum.random(-radius..radius)

    with true <- x >= 0 and y >= 0 and Cell.traversable?(pet.map_name, x, y),
         {:ok, walked} <- walk_to(session, {x, y}, now: now) do
      {:ok, walked}
    else
      _failed -> try_random_walk(session, radius, now, tries - 1)
    end
  end

  defp schedule_next_walk(%SessionState{pet: pet, pet_runtime: runtime} = session, now) do
    cost =
      runtime.movement_path
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [from, to] -> MovementEngine.step_delay(pet.walk_speed, from, to) end)
      |> Enum.sum()

    put_runtime(session,
      next_walk_at_ms: now + @min_random_walk_ms + cost + Enum.random(0..999)
    )
  end

  defp slide(session, %PlayerState{x: x, y: y}) do
    session = stop(session)
    pet = session.pet
    dir = Geometry.calculate_direction(pet.x, pet.y, x, y)
    session = StateCommit.commit(session, %{pet | x: x, y: y, dir: dir})
    packet = %Knockback{unit_id: pet.world_gid, dst_x: x, dst_y: y}
    Broadcast.to_in_range(pet.map_name, x, y, Config.view_range(), packet)
    session
  end

  defp behind(pet, tx, ty, dir) do
    {face_x, face_y} = Geometry.facing_delta(dir)
    dx = -face_x * 2
    dy = -face_y * 2
    far_cell = {tx + dx, ty + dy}
    near_cell = {tx + dx - sign(dx), ty + dy - sign(dy)}

    cond do
      reachable?(pet, far_cell) -> {:ok, far_cell}
      reachable?(pet, near_cell) -> {:ok, near_cell}
      true -> :error
    end
  end

  defp random_behind(_pet, _tx, _ty, 0), do: :error

  defp random_behind(pet, tx, ty, tries) do
    with :error <- behind(pet, tx, ty, Enum.random(0..7)),
         do: random_behind(pet, tx, ty, tries - 1)
  end

  # `unit_can_reach_pos(bl, x, y, 0)`: the same cell, or a path over CELL_CHKNOREACH.
  defp reachable?(%PetState{x: x, y: y}, {x, y}), do: true

  defp reachable?(pet, cell) do
    with {:ok, map} <- MapCache.get(pet.map_name),
         {:ok, _cells} <- Pathfinding.find_path(map, {pet.x, pet.y}, cell, cells: :noreach) do
      true
    else
      _unreachable -> false
    end
  end

  defp path?(pet, cell) do
    with {:ok, map} <- MapCache.get(pet.map_name),
         {:ok, _cells} <- Pathfinding.find_path(map, {pet.x, pet.y}, cell) do
      true
    else
      _unreachable -> false
    end
  end

  defp far?(%SessionState{pet: pet, game_state: owner}),
    do: distance(pet, owner) > Config.view_range()

  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}), do: Geometry.chebyshev_distance(x1, y1, x2, y2)

  defp diagonal?({x1, y1}, {x2, y2}), do: x1 != x2 and y1 != y2

  defp sign(n) when n > 0, do: 1
  defp sign(n) when n < 0, do: -1
  defp sign(_n), do: 0

  defp put_runtime(%SessionState{pet_runtime: runtime} = session, fields),
    do: %{session | pet_runtime: struct!(runtime, fields)}
end
