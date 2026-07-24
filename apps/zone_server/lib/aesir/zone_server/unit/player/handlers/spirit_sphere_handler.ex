defmodule Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler do
  @moduledoc """
  Applies spirit-sphere changes inside the owning player session.
  """

  alias Aesir.Net.SpiritSphereUpdate
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.StateCommit

  @type session_state :: SessionState.t()

  defmodule TimerPlan do
    @moduledoc false

    use TypedStruct

    typedstruct do
      field :generation, non_neg_integer(), enforce: true
      field :expires_at, integer(), enforce: true
    end
  end

  defmodule SkillCostPlan do
    @moduledoc false

    use TypedStruct

    typedstruct do
      field :previous_timer, reference() | nil, enforce: true
      field :timer_plan, TimerPlan.t() | nil, enforce: true
    end
  end

  @spec summon(session_state(), pos_integer(), pos_integer()) :: {:noreply, session_state()}
  def summon(%{game_state: game_state} = state, duration, cap) when duration > 0 and cap > 0 do
    now = System.monotonic_time(:millisecond)

    {spheres, %SpiritSpheres.Entry{}} =
      SpiritSpheres.summon(game_state.spirit_spheres, now + duration, cap)

    {:noreply, commit(state, spheres, now, true)}
  end

  @spec receive_sphere(session_state(), pos_integer(), pos_integer()) ::
          {:ok, session_state()} | {:error, :full}
  def receive_sphere(%{game_state: game_state} = state, duration, cap)
      when duration > 0 and cap > 0 do
    now = System.monotonic_time(:millisecond)

    case SpiritSpheres.add_if_below_cap(game_state.spirit_spheres, now + duration, cap) do
      {:ok, spheres, _entry} -> {:ok, commit(state, spheres, now, true)}
      {:error, :full} = error -> error
    end
  end

  @spec consume(session_state(), pos_integer()) ::
          {:ok, session_state()} | {:error, :insufficient}
  def consume(%{game_state: game_state} = state, count) when count > 0 do
    case SpiritSpheres.consume(game_state.spirit_spheres, count) do
      {:ok, spheres, _entries} ->
        {:ok, commit(state, spheres, System.monotonic_time(:millisecond), true)}

      {:error, :insufficient} = error ->
        error
    end
  end

  @doc false
  @spec prepare_skill_cost(PlayerState.t(), SpiritSpheres.t()) ::
          {PlayerState.t(), SkillCostPlan.t() | nil}
  def prepare_skill_cost(game_state, previous_spheres) do
    if previous_spheres == game_state.spirit_spheres do
      {game_state, nil}
    else
      generation = game_state.spirit_sphere_timer_generation + 1
      previous_timer = game_state.spirit_sphere_timer
      timer_plan = timer_plan(game_state.spirit_spheres, generation)

      game_state = %{
        game_state
        | spirit_sphere_timer: nil,
          spirit_sphere_timer_plan: timer_plan,
          spirit_sphere_timer_generation: generation,
          spirit_sphere_revision: game_state.spirit_sphere_revision + 1
      }

      {game_state, %SkillCostPlan{previous_timer: previous_timer, timer_plan: timer_plan}}
    end
  end

  @doc false
  @spec apply_skill_cost_effects(session_state(), SkillCostPlan.t() | nil) :: session_state()
  def apply_skill_cost_effects(state, nil), do: state

  def apply_skill_cost_effects(%{game_state: game_state} = state, %SkillCostPlan{} = plan) do
    cancel_timer(plan.previous_timer)

    game_state = %{
      game_state
      | spirit_sphere_timer: arm_timer(plan.timer_plan, System.monotonic_time(:millisecond))
    }

    state = %{state | game_state: game_state}
    broadcast(state)
    state
  end

  @spec expire(session_state(), non_neg_integer()) :: {:noreply, session_state()}
  def expire(%{game_state: %{spirit_sphere_timer_generation: generation}} = state, generation) do
    now = System.monotonic_time(:millisecond)
    {spheres, expired} = SpiritSpheres.expire_due(state.game_state.spirit_spheres, now)
    {:noreply, commit(state, spheres, now, expired != [])}
  end

  def expire(state, _stale_generation), do: {:noreply, state}

  @spec clear(session_state()) :: session_state()
  def clear(%{game_state: game_state} = state) do
    {spheres, cleared} = SpiritSpheres.clear(game_state.spirit_spheres)
    commit(state, spheres, System.monotonic_time(:millisecond), cleared != [])
  end

  @spec discard(session_state()) :: session_state()
  def discard(%{game_state: game_state} = state) do
    cancel_timer(game_state.spirit_sphere_timer)

    game_state =
      %{
        game_state
        | spirit_spheres: SpiritSpheres.new(),
          spirit_sphere_timer: nil,
          spirit_sphere_timer_plan: nil,
          spirit_sphere_timer_generation: game_state.spirit_sphere_timer_generation + 1
      }

    %{state | game_state: game_state}
  end

  defp commit(%{game_state: game_state} = state, spheres, now, notify?) do
    generation = game_state.spirit_sphere_timer_generation + 1
    cancel_timer(game_state.spirit_sphere_timer)
    timer_plan = timer_plan(spheres, generation)
    timer_ref = arm_timer(timer_plan, now)

    game_state = %{
      game_state
      | spirit_spheres: spheres,
        spirit_sphere_timer: timer_ref,
        spirit_sphere_timer_plan: timer_plan,
        spirit_sphere_timer_generation: generation,
        spirit_sphere_revision:
          if(notify?,
            do: game_state.spirit_sphere_revision + 1,
            else: game_state.spirit_sphere_revision
          )
    }

    state = StateCommit.commit(state, game_state)
    if notify?, do: broadcast(state)
    state
  end

  defp timer_plan(spheres, generation) do
    case SpiritSpheres.next_expiry(spheres) do
      nil -> nil
      expires_at -> %TimerPlan{generation: generation, expires_at: expires_at}
    end
  end

  defp arm_timer(nil, _now), do: nil

  defp arm_timer(%TimerPlan{generation: generation, expires_at: expires_at}, now) do
    Process.send_after(self(), {:spirit_sphere_expire, generation}, max(expires_at - now, 0))
  end

  defp cancel_timer(nil), do: :ok

  defp cancel_timer(timer_ref) when is_reference(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end

  defp broadcast(%{connection_pid: connection_pid, game_state: game_state}) do
    update = %SpiritSphereUpdate{
      unit_id: game_state.character_id,
      count: SpiritSpheres.count(game_state.spirit_spheres),
      revision: game_state.spirit_sphere_revision
    }

    MessageRouter.send_to(connection_pid, update)
    Broadcast.to_visible_players(game_state, update, exclude_id: game_state.character_id)
  end
end
