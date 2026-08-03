defmodule Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler do
  @moduledoc """
  Owned Homunculus lifecycle transitions with small OTP timer seams.

  The caller owns persistence, world removal/publication, status cleanup, and
  committing the returned Homunculus through `StateCommit`.
  """

  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  @type transition_result ::
          {:ok, HomunculusState.t() | nil, Runtime.t()}
          | {:noop, HomunculusState.t(), Runtime.t()}
          | {:error, atom()}
  @type opts :: keyword()

  @doc "Activates a newly-created state only when the aggregate slot is empty."
  @spec first_creation(
          HomunculusState.t() | nil,
          HomunculusState.t(),
          Runtime.t(),
          opts()
        ) :: transition_result()
  def first_creation(current, created, runtime, opts \\ [])

  def first_creation(nil, %HomunculusState{} = created, %Runtime{} = runtime, opts) do
    with :ok <- valid_state(created, runtime),
         :ok <- valid_creation_candidate(created) do
      activate_fresh(created, runtime, opts)
    end
  end

  def first_creation(
        %HomunculusState{} = current,
        %HomunculusState{},
        %Runtime{} = runtime,
        _opts
      ) do
    with :ok <- valid_state(current, runtime) do
      {:error, :companion_exists}
    end
  end

  @doc "Validates Call from Rest against the complete current snapshot."
  @spec preflight_call(HomunculusState.t(), Runtime.t()) :: :ok | {:error, atom()}
  def preflight_call(%HomunculusState{} = homunculus, %Runtime{} = runtime) do
    with :ok <- valid_state(homunculus, runtime) do
      preflight_valid_call(homunculus)
    end
  end

  @doc "Recalls a living Rested Homunculus with a fresh active clock."
  @spec call(HomunculusState.t(), Runtime.t(), opts()) :: transition_result()
  def call(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts \\ []) do
    with :ok <- preflight_call(homunculus, runtime) do
      activate_fresh(homunculus, runtime, opts)
    end
  end

  @doc "Validates voluntary Rest, including the exact 80 percent HP gate."
  @spec preflight_rest(HomunculusState.t(), Runtime.t()) :: :ok | {:error, atom()}
  def preflight_rest(%HomunculusState{} = homunculus, %Runtime{} = runtime) do
    with :ok <- valid_state(homunculus, runtime) do
      preflight_valid_rest(homunculus)
    end
  end

  @doc "Voluntarily Rests an active living Homunculus and discards active remainder."
  @spec voluntary_rest(HomunculusState.t(), Runtime.t(), opts()) :: transition_result()
  def voluntary_rest(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts \\ []) do
    with :ok <- preflight_rest(homunculus, runtime) do
      {:ok, rest_state(homunculus), stop_active_clock(runtime, opts)}
    end
  end

  @doc "Transitions an active Homunculus to dead without changing intimacy or cooldowns."
  @spec die(HomunculusState.t(), Runtime.t(), opts()) :: transition_result()
  def die(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts \\ []) do
    with :ok <- valid_state(homunculus, runtime),
         :ok <- preflight_death(homunculus) do
      dead = %{
        homunculus
        | lifecycle: :dead,
          hp: 0,
          active_remaining_ms: 0,
          action_state: :dead,
          movement_state: :standing,
          target: nil,
          casting: nil
      }

      {:ok, dead, stop_active_clock(runtime, opts)}
    end
  end

  @doc "Validates Resurrection with an already-computed positive restored HP."
  @spec preflight_resurrection(HomunculusState.t(), integer(), Runtime.t()) ::
          :ok | {:error, atom()}
  def preflight_resurrection(
        %HomunculusState{} = homunculus,
        restored_hp,
        %Runtime{} = runtime
      ) do
    with :ok <- valid_state(homunculus, runtime) do
      preflight_valid_resurrection(homunculus, restored_hp)
    end
  end

  @doc "Resurrects from dead with supplied HP and a fresh active clock."
  @spec resurrect(HomunculusState.t(), pos_integer(), Runtime.t(), opts()) :: transition_result()
  def resurrect(
        %HomunculusState{} = homunculus,
        restored_hp,
        %Runtime{} = runtime,
        opts \\ []
      ) do
    with :ok <- preflight_resurrection(homunculus, restored_hp, runtime) do
      homunculus
      |> Map.put(:hp, restored_hp)
      |> activate_fresh(runtime, opts)
    end
  end

  @doc "Handles natural expiry only for the current active timer."
  @spec expire(HomunculusState.t(), Runtime.t(), reference(), opts()) :: transition_result()
  def expire(
        %HomunculusState{} = homunculus,
        %Runtime{} = runtime,
        received_ref,
        opts \\ []
      ) do
    with :ok <- valid_state(homunculus, runtime) do
      if Clock.current_timer?(runtime.active_expiry_timer_ref, received_ref) do
        expire_current(homunculus, runtime, now_ms(opts), opts)
      else
        {:noop, homunculus, runtime}
      end
    end
  end

  @doc "Permanently removes a companion only after explicit confirmation."
  @spec delete(HomunculusState.t(), Runtime.t(), boolean(), opts()) :: transition_result()
  def delete(%HomunculusState{} = homunculus, %Runtime{} = runtime, confirmed, opts \\ []) do
    with :ok <- valid_state(homunculus, runtime),
         :ok <- require_confirmation(confirmed) do
      Clock.cancel(runtime.active_expiry_timer_ref, opts)
      Clock.cancel(runtime.cooldown_timer_ref, opts)

      {:ok, nil,
       %{
         runtime
         | active_expiry_timer_ref: nil,
           active_deadline_ms: nil,
           cooldown_timer_ref: nil,
           clocks_online: false
       }}
    end
  end

  @doc "Pauses active and cooldown clocks for logout or loss of online ownership."
  @spec pause_offline(HomunculusState.t(), Runtime.t(), opts()) :: transition_result()
  def pause_offline(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts \\ []) do
    with :ok <- valid_state(homunculus, runtime) do
      pause_valid_state(homunculus, runtime, opts)
    end
  end

  @doc "Resumes online clocks after reconnect for every owned lifecycle."
  @spec resume_online(HomunculusState.t(), Runtime.t(), opts()) :: transition_result()
  def resume_online(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts \\ []) do
    with :ok <- valid_state(homunculus, runtime) do
      resume_valid_state(homunculus, runtime, opts)
    end
  end

  @doc "Applies owner-death Rest at 80 percent HP, otherwise leaves state active."
  @spec owner_died(HomunculusState.t(), Runtime.t(), opts()) :: transition_result()
  def owner_died(%HomunculusState{} = homunculus, %Runtime{} = runtime, opts \\ []) do
    with :ok <- valid_state(homunculus, runtime) do
      owner_died_valid(homunculus, runtime, opts)
    end
  end

  @doc "Preserves all lifecycle clocks during owner map transfer."
  @spec transfer(HomunculusState.t(), Runtime.t()) :: transition_result()
  def transfer(%HomunculusState{} = homunculus, %Runtime{} = runtime) do
    with :ok <- valid_state(homunculus, runtime) do
      {:ok, homunculus, runtime}
    end
  end

  @doc "Expires actually-due cooldowns only for the current singleton timer."
  @spec cooldowns_expired(HomunculusState.t(), Runtime.t(), reference(), opts()) ::
          transition_result()
  def cooldowns_expired(
        %HomunculusState{} = homunculus,
        %Runtime{} = runtime,
        received_ref,
        opts \\ []
      ) do
    with :ok <- valid_state(homunculus, runtime) do
      if Clock.current_timer?(runtime.cooldown_timer_ref, received_ref) do
        expire_current_cooldowns(homunculus, runtime, now_ms(opts), opts)
      else
        {:noop, homunculus, runtime}
      end
    end
  end

  defp valid_creation_candidate(%HomunculusState{} = homunculus) do
    if homunculus.lifecycle in [:active, :rested] and homunculus.hp == homunculus.max_hp and
         homunculus.action_state == :idle and homunculus.movement_state == :standing and
         is_nil(homunculus.target) and is_nil(homunculus.casting) do
      :ok
    else
      {:error, :invalid_creation_state}
    end
  end

  defp preflight_valid_call(%HomunculusState{lifecycle: :rested}), do: :ok
  defp preflight_valid_call(%HomunculusState{lifecycle: :dead}), do: {:error, :dead}
  defp preflight_valid_call(%HomunculusState{}), do: {:error, :invalid_lifecycle}

  defp preflight_valid_rest(%HomunculusState{lifecycle: :dead}), do: {:error, :dead}

  defp preflight_valid_rest(%HomunculusState{lifecycle: :active, hp: hp, max_hp: max_hp}) do
    if hp * 100 >= max_hp * 80, do: :ok, else: {:error, :hp_gate}
  end

  defp preflight_valid_rest(%HomunculusState{}), do: {:error, :invalid_lifecycle}

  defp preflight_death(%HomunculusState{lifecycle: :active}), do: :ok
  defp preflight_death(%HomunculusState{lifecycle: :dead}), do: {:error, :dead}
  defp preflight_death(%HomunculusState{}), do: {:error, :invalid_lifecycle}

  defp preflight_valid_resurrection(
         %HomunculusState{lifecycle: :dead, max_hp: max_hp},
         restored_hp
       )
       when restored_hp > 0 and restored_hp <= max_hp,
       do: :ok

  defp preflight_valid_resurrection(%HomunculusState{lifecycle: :dead}, _restored_hp),
    do: {:error, :invalid_restored_hp}

  defp preflight_valid_resurrection(%HomunculusState{}, _restored_hp),
    do: {:error, :invalid_lifecycle}

  defp require_confirmation(true), do: :ok
  defp require_confirmation(false), do: {:error, :confirmation_required}

  defp expire_current(homunculus, runtime, now_ms, opts) do
    if runtime.active_deadline_ms <= now_ms do
      {:ok, rest_state(homunculus), clear_active_clock(runtime)}
    else
      timer_ref = Clock.arm_active(runtime.active_deadline_ms, now_ms, opts)
      {:ok, homunculus, %{runtime | active_expiry_timer_ref: timer_ref}}
    end
  end

  defp expire_current_cooldowns(homunculus, runtime, now_ms, opts) do
    if cooldown_due?(homunculus.cooldowns, now_ms) do
      cooldowns = Clock.remove_due_cooldowns(homunculus.cooldowns, now_ms)
      timer_ref = Clock.arm_nearest_cooldown(cooldowns, now_ms, opts)

      {:ok, %{homunculus | cooldowns: cooldowns}, %{runtime | cooldown_timer_ref: timer_ref}}
    else
      timer_ref = Clock.arm_nearest_cooldown(homunculus.cooldowns, now_ms, opts)
      {:ok, homunculus, %{runtime | cooldown_timer_ref: timer_ref}}
    end
  end

  defp pause_valid_state(homunculus, %Runtime{clocks_online: false} = runtime, _opts),
    do: {:noop, homunculus, runtime}

  defp pause_valid_state(homunculus, runtime, opts) do
    now_ms = now_ms(opts)

    {:ok, snapshot} =
      Clock.durable_snapshot(
        homunculus.lifecycle,
        runtime.active_deadline_ms,
        homunculus.cooldowns,
        now_ms
      )

    Clock.cancel(runtime.active_expiry_timer_ref, opts)
    Clock.cancel(runtime.cooldown_timer_ref, opts)

    paused = %{
      homunculus
      | active_remaining_ms: snapshot.active_remaining_ms,
        cooldowns: snapshot.cooldowns
    }

    paused_runtime = %{
      runtime
      | active_expiry_timer_ref: nil,
        active_deadline_ms: nil,
        cooldown_timer_ref: nil,
        clocks_online: false
    }

    {:ok, paused, paused_runtime}
  end

  defp resume_valid_state(homunculus, %Runtime{clocks_online: true} = runtime, _opts),
    do: {:noop, homunculus, runtime}

  defp resume_valid_state(homunculus, runtime, opts) do
    now_ms = now_ms(opts)
    cooldowns = Clock.resume_cooldowns(homunculus.cooldowns, now_ms)
    cooldown_timer_ref = Clock.arm_nearest_cooldown(cooldowns, now_ms, opts)

    {homunculus, runtime} =
      resume_active_clock(%{homunculus | cooldowns: cooldowns}, runtime, now_ms, opts)

    {:ok, homunculus, %{runtime | clocks_online: true, cooldown_timer_ref: cooldown_timer_ref}}
  end

  defp owner_died_valid(
         %HomunculusState{lifecycle: :active, hp: hp, max_hp: max_hp} = homunculus,
         runtime,
         opts
       ) do
    if hp * 100 >= max_hp * 80 do
      {:ok, rest_state(homunculus), stop_active_clock(runtime, opts)}
    else
      {:noop, homunculus, runtime}
    end
  end

  defp owner_died_valid(homunculus, runtime, _opts), do: {:noop, homunculus, runtime}

  defp activate_fresh(homunculus, runtime, opts) do
    now_ms = now_ms(opts)
    deadline_ms = Clock.fresh_active_deadline(now_ms)
    Clock.cancel(runtime.active_expiry_timer_ref, opts)
    active_timer_ref = Clock.arm_active(deadline_ms, now_ms, opts)

    {cooldowns, runtime} = ensure_online_cooldowns(homunculus.cooldowns, runtime, now_ms, opts)

    active = %{
      homunculus
      | lifecycle: :active,
        active_remaining_ms: 1_800_000,
        cooldowns: cooldowns,
        action_state: :idle,
        movement_state: :standing,
        target: nil,
        casting: nil
    }

    {:ok, active,
     %{
       runtime
       | active_expiry_timer_ref: active_timer_ref,
         active_deadline_ms: deadline_ms,
         clocks_online: true
     }}
  end

  defp ensure_online_cooldowns(cooldowns, %Runtime{clocks_online: true} = runtime, _now, _opts),
    do: {cooldowns, runtime}

  defp ensure_online_cooldowns(cooldowns, runtime, now_ms, opts) do
    deadlines = Clock.resume_cooldowns(cooldowns, now_ms)
    timer_ref = Clock.arm_nearest_cooldown(deadlines, now_ms, opts)
    {deadlines, %{runtime | cooldown_timer_ref: timer_ref}}
  end

  defp rest_state(homunculus) do
    %{
      homunculus
      | lifecycle: :rested,
        active_remaining_ms: 0,
        action_state: :idle,
        movement_state: :standing,
        target: nil,
        casting: nil
    }
  end

  defp stop_active_clock(runtime, opts) do
    Clock.cancel(runtime.active_expiry_timer_ref, opts)
    clear_active_clock(runtime)
  end

  defp clear_active_clock(runtime) do
    %{runtime | active_expiry_timer_ref: nil, active_deadline_ms: nil}
  end

  defp resume_active_clock(
         %HomunculusState{lifecycle: :active} = homunculus,
         runtime,
         now_ms,
         opts
       ) do
    deadline_ms = Clock.resume_deadline(homunculus.active_remaining_ms, now_ms)
    timer_ref = Clock.arm_active(deadline_ms, now_ms, opts)

    {homunculus,
     %{
       runtime
       | active_deadline_ms: deadline_ms,
         active_expiry_timer_ref: timer_ref
     }}
  end

  defp resume_active_clock(homunculus, runtime, _now_ms, _opts), do: {homunculus, runtime}

  defp cooldown_due?(cooldowns, now_ms) do
    case Clock.nearest_cooldown(cooldowns) do
      nil -> false
      deadline_ms -> deadline_ms <= now_ms
    end
  end

  defp valid_state(%HomunculusState{} = homunculus, %Runtime{} = runtime) do
    with true <- valid_resources?(homunculus),
         true <- valid_lifecycle?(homunculus),
         true <- valid_cooldowns?(homunculus.cooldowns, runtime.clocks_online),
         true <- valid_clock_representation?(homunculus, runtime) do
      :ok
    else
      _invalid -> {:error, :invalid_state}
    end
  end

  defp valid_resources?(%HomunculusState{
         hp: hp,
         max_hp: max_hp,
         active_remaining_ms: active_remaining_ms
       }) do
    is_integer(max_hp) and max_hp > 0 and is_integer(hp) and hp >= 0 and hp <= max_hp and
      is_integer(active_remaining_ms) and active_remaining_ms >= 0
  end

  defp valid_lifecycle?(%HomunculusState{lifecycle: :active} = homunculus),
    do: Unit.living?(homunculus)

  defp valid_lifecycle?(%HomunculusState{lifecycle: :rested} = homunculus) do
    homunculus.hp > 0 and homunculus.action_state == :idle and
      homunculus.movement_state == :standing and is_nil(homunculus.target) and
      is_nil(homunculus.casting) and homunculus.active_remaining_ms == 0
  end

  defp valid_lifecycle?(%HomunculusState{lifecycle: :dead} = homunculus) do
    homunculus.hp == 0 and homunculus.action_state == :dead and
      homunculus.movement_state == :standing and is_nil(homunculus.target) and
      is_nil(homunculus.casting) and homunculus.active_remaining_ms == 0
  end

  defp valid_lifecycle?(%HomunculusState{}), do: false

  defp valid_cooldowns?(cooldowns, false) when is_map(cooldowns),
    do: Enum.all?(cooldowns, fn {_skill_id, value} -> is_integer(value) and value >= 0 end)

  defp valid_cooldowns?(cooldowns, true) when is_map(cooldowns),
    do: Enum.all?(cooldowns, fn {_skill_id, value} -> is_integer(value) end)

  defp valid_cooldowns?(_cooldowns, _online), do: false

  defp valid_clock_representation?(homunculus, %Runtime{clocks_online: false} = runtime) do
    is_nil(runtime.active_deadline_ms) and is_nil(runtime.active_expiry_timer_ref) and
      is_nil(runtime.cooldown_timer_ref) and homunculus.active_remaining_ms >= 0
  end

  defp valid_clock_representation?(homunculus, %Runtime{clocks_online: true} = runtime) do
    valid_active_online?(homunculus.lifecycle, runtime) and
      valid_cooldown_timer?(homunculus.cooldowns, runtime.cooldown_timer_ref)
  end

  defp valid_clock_representation?(_homunculus, %Runtime{}), do: false

  defp valid_active_online?(:active, runtime),
    do: is_integer(runtime.active_deadline_ms) and is_reference(runtime.active_expiry_timer_ref)

  defp valid_active_online?(lifecycle, runtime) when lifecycle in [:rested, :dead],
    do: is_nil(runtime.active_deadline_ms) and is_nil(runtime.active_expiry_timer_ref)

  defp valid_cooldown_timer?(cooldowns, nil), do: map_size(cooldowns) == 0

  defp valid_cooldown_timer?(cooldowns, timer_ref),
    do: map_size(cooldowns) > 0 and is_reference(timer_ref)

  defp now_ms(opts), do: Keyword.get_lazy(opts, :now_ms, &Clock.now_ms/0)
end
