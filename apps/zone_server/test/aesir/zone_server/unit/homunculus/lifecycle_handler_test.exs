defmodule Aesir.ZoneServer.Unit.Homunculus.LifecycleHandlerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Homunculus.Clock
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  test "fresh active clocks last thirty minutes" do
    assert Clock.fresh_active_deadline(12_345) == 1_812_345
    assert Clock.pause_remaining(1_812_345, 12_345) == 1_800_000
    assert Clock.resume_deadline(1_800_000, 12_345) == 1_812_345
  end

  test "online clocks snapshot current durable remainders without changing timers" do
    assert {:ok, %{active_remaining_ms: 750, cooldowns: %{8001 => 500, 8002 => 0}}} =
             Clock.durable_snapshot(:active, 1_750, %{8001 => 1_500, 8002 => 900}, 1_000)

    assert {:ok, %{active_remaining_ms: 0, cooldowns: %{8001 => 500}}} =
             Clock.durable_snapshot(:rested, nil, %{8001 => 1_500}, 1_000)

    assert {:ok, %{active_remaining_ms: 0}} =
             Clock.durable_snapshot(:rested, nil, %{}, -1_000)

    assert {:error, :invalid_clock_state} =
             Clock.durable_snapshot(:dead, 1_500, %{}, 1_000)
  end

  test "default zero-delay timers deliver their reference and documented event shape" do
    ref = Clock.arm_active(1_000, 1_000)
    assert_receive {:timeout, ^ref, {:homunculus, :active_expired}}
  end

  test "cooldown clocks convert remainders, choose one nearest timer, and cancel by ref" do
    assert Clock.resume_cooldowns(%{8001 => 500, 8002 => 200}, 1_000) == %{
             8001 => 1_500,
             8002 => 1_200
           }

    assert Clock.pause_cooldowns(%{8001 => 1_500, 8002 => 900}, 1_000) == %{
             8001 => 500,
             8002 => 0
           }

    opts = timer_opts(1_000)
    ref = Clock.arm_nearest_cooldown(%{8001 => 1_500, 8002 => 1_200}, 1_000, opts)
    assert_receive {:timer_started, ^ref, 200, :cooldowns_expired}
    assert Clock.current_timer?(ref, ref)
    refute Clock.current_timer?(make_ref(), ref)
    refute Clock.current_timer?(nil, nil)
    refute Clock.current_timer?(nil, ref)

    assert :ok = Clock.cancel(ref, opts)
    assert_receive {:timer_cancelled, ^ref}
  end

  test "first creation preflight and activation require an empty slot and start fresh" do
    homunculus =
      homunculus(%{lifecycle: :rested, hp: 1_000, cooldowns: %{8001 => 500}})

    runtime = runtime()

    assert {:ok, active, online} =
             LifecycleHandler.first_creation(nil, homunculus, runtime, timer_opts(1_000))

    assert active.lifecycle == :active
    assert active.active_remaining_ms == 1_800_000
    assert active.cooldowns == %{8001 => 1_500}
    assert online.active_deadline_ms == 1_801_000
    assert online.clocks_online
    assert is_reference(online.active_expiry_timer_ref)
    assert is_reference(online.cooldown_timer_ref)

    assert_receive {:timer_started, active_ref, 1_800_000, :active_expired}
    assert active_ref == online.active_expiry_timer_ref
    assert_receive {:timer_started, cooldown_ref, 500, :cooldowns_expired}
    assert cooldown_ref == online.cooldown_timer_ref

    assert {:error, :companion_exists} =
             LifecycleHandler.first_creation(active, homunculus, online, timer_opts(2_000))

    assert online.active_deadline_ms == 1_801_000
    refute_receive {:timer_started, _ref, _delay, _event}
    refute_receive {:timer_cancelled, _ref}
  end

  test "first creation rejects dead and not-fully-healed candidates without arming timers" do
    opts = timer_opts(1_000)

    assert {:error, :invalid_creation_state} =
             LifecycleHandler.first_creation(
               nil,
               homunculus(%{lifecycle: :dead}),
               runtime(),
               opts
             )

    assert {:error, :invalid_creation_state} =
             LifecycleHandler.first_creation(nil, homunculus(%{hp: 999}), runtime(), opts)

    refute_receive {:timer_started, _ref, _delay, _event}
    refute_receive {:timer_cancelled, _ref}
  end

  test "Call only recalls living Rested state and starts fresh without resetting cooldowns" do
    cooldowns = %{8001 => 5_000}
    rested = homunculus(%{lifecycle: :rested, cooldowns: cooldowns})
    online = runtime(%{clocks_online: true, cooldown_timer_ref: make_ref()})

    assert {:ok, active, next_runtime} =
             LifecycleHandler.call(rested, online, timer_opts(2_000))

    assert active.lifecycle == :active
    assert active.active_remaining_ms == 1_800_000
    assert active.cooldowns == cooldowns
    assert next_runtime.active_deadline_ms == 1_802_000

    assert {:error, :dead} =
             LifecycleHandler.call(homunculus(%{lifecycle: :dead, cooldowns: cooldowns}), online)

    assert {:error, :invalid_lifecycle} =
             LifecycleHandler.call(homunculus(), online_runtime(3_000))
  end

  test "voluntary Rest requires active living 80 percent HP and discards remainder" do
    active_ref = make_ref()
    cooldown_ref = make_ref()

    runtime =
      runtime(%{
        active_expiry_timer_ref: active_ref,
        active_deadline_ms: 50_000,
        cooldown_timer_ref: cooldown_ref,
        clocks_online: true
      })

    cooldowns = %{8001 => 20_000}
    at_gate = homunculus(%{hp: 800, max_hp: 1_000, cooldowns: cooldowns})

    assert {:ok, rested, next_runtime} =
             LifecycleHandler.voluntary_rest(at_gate, runtime, timer_opts(1_000))

    assert rested.lifecycle == :rested
    assert rested.active_remaining_ms == 0
    assert rested.cooldowns == cooldowns
    assert next_runtime.active_expiry_timer_ref == nil
    assert next_runtime.cooldown_timer_ref == cooldown_ref
    assert_receive {:timer_cancelled, ^active_ref}
    refute_receive {:timer_cancelled, ^cooldown_ref}

    assert {:error, :hp_gate} =
             LifecycleHandler.voluntary_rest(%{at_gate | hp: 799}, runtime)

    dead = %{
      at_gate
      | lifecycle: :dead,
        hp: 0,
        active_remaining_ms: 0,
        action_state: :dead
    }

    assert {:error, :dead} = LifecycleHandler.voluntary_rest(dead, next_runtime)
  end

  test "death discards active time, preserves intimacy and cooldowns, and cannot be bypassed" do
    active = homunculus(%{intimacy_hundredths: 44_444, cooldowns: %{8001 => 9_000}})
    runtime = online_runtime(10_000, %{cooldown_timer_ref: make_ref()})

    assert {:ok, dead, next_runtime} = LifecycleHandler.die(active, runtime)
    assert dead.lifecycle == :dead
    assert dead.hp == 0
    assert dead.active_remaining_ms == 0
    assert dead.intimacy_hundredths == 44_444
    assert dead.cooldowns == active.cooldowns
    assert next_runtime.active_deadline_ms == nil

    assert {:error, :dead} = LifecycleHandler.call(dead, next_runtime)
    assert {:error, :dead} = LifecycleHandler.voluntary_rest(dead, next_runtime)
  end

  test "Resurrection only accepts dead state and supplied valid restored HP" do
    dead =
      homunculus(%{lifecycle: :dead, hp: 0, action_state: :dead, cooldowns: %{8001 => 5_000}})

    runtime = runtime(%{clocks_online: true, cooldown_timer_ref: make_ref()})

    assert {:ok, active, next_runtime} =
             LifecycleHandler.resurrect(dead, 400, runtime, timer_opts(1_000))

    assert active.lifecycle == :active
    assert active.hp == 400
    assert active.active_remaining_ms == 1_800_000
    assert active.cooldowns == dead.cooldowns
    assert next_runtime.active_deadline_ms == 1_801_000

    assert {:error, :invalid_lifecycle} =
             LifecycleHandler.resurrect(homunculus(), 400, online_runtime(2_000))

    assert {:error, :invalid_restored_hp} = LifecycleHandler.resurrect(dead, 0, runtime)
  end

  test "natural expiry ignores stale refs and rearms current premature delivery" do
    current_ref = make_ref()
    stale_ref = make_ref()
    low_hp = homunculus(%{hp: 1})

    runtime =
      runtime(%{
        active_expiry_timer_ref: current_ref,
        active_deadline_ms: 1_000,
        clocks_online: true
      })

    assert {:noop, ^low_hp, ^runtime} =
             LifecycleHandler.expire(low_hp, runtime, stale_ref, now_ms: 1_000)

    assert {:ok, ^low_hp, rearmed_runtime} =
             LifecycleHandler.expire(low_hp, runtime, current_ref, timer_opts(999))

    new_ref = rearmed_runtime.active_expiry_timer_ref
    assert is_reference(new_ref)
    assert new_ref != current_ref
    assert_receive {:timer_started, ^new_ref, 1, :active_expired}

    assert {:ok, rested, next_runtime} =
             LifecycleHandler.expire(low_hp, rearmed_runtime, new_ref, now_ms: 1_000)

    assert rested.lifecycle == :rested
    assert rested.active_remaining_ms == 0
    assert next_runtime.active_expiry_timer_ref == nil
  end

  test "stale timer events still fail closed when state or runtime is inconsistent" do
    stale_ref = make_ref()

    assert {:error, :invalid_state} =
             LifecycleHandler.expire(
               homunculus(),
               runtime(%{clocks_online: true}),
               stale_ref,
               now_ms: 1_000
             )

    assert {:error, :invalid_state} =
             LifecycleHandler.cooldowns_expired(
               homunculus(%{cooldowns: %{8001 => 1_500}}),
               online_runtime(2_000),
               stale_ref,
               now_ms: 1_000
             )
  end

  test "confirmed deletion is explicit and cancels owned lifecycle timers" do
    active_ref = make_ref()
    cooldown_ref = make_ref()

    runtime =
      online_runtime(5_000, %{
        active_expiry_timer_ref: active_ref,
        cooldown_timer_ref: cooldown_ref
      })

    homunculus = homunculus(%{cooldowns: %{8001 => 6_000}})

    assert {:error, :confirmation_required} =
             LifecycleHandler.delete(homunculus, runtime, false)

    assert {:ok, nil, cleared} =
             LifecycleHandler.delete(homunculus, runtime, true, timer_opts(1_000))

    refute cleared.clocks_online
    assert cleared.active_expiry_timer_ref == nil
    assert cleared.cooldown_timer_ref == nil
    assert_receive {:timer_cancelled, ^active_ref}
    assert_receive {:timer_cancelled, ^cooldown_ref}
  end

  test "logout pauses active and cooldown time and reconnect resumes by lifecycle" do
    active_ref = make_ref()
    cooldown_ref = make_ref()
    active = homunculus(%{active_remaining_ms: 99, cooldowns: %{8001 => 1_500, 8002 => 900}})

    online =
      runtime(%{
        active_expiry_timer_ref: active_ref,
        active_deadline_ms: 2_000,
        cooldown_timer_ref: cooldown_ref,
        clocks_online: true
      })

    assert {:ok, paused, offline} =
             LifecycleHandler.pause_offline(active, online, timer_opts(1_000))

    assert paused.lifecycle == :active
    assert paused.active_remaining_ms == 1_000
    assert paused.cooldowns == %{8001 => 500, 8002 => 0}
    refute offline.clocks_online

    assert {:ok, resumed, resumed_runtime} =
             LifecycleHandler.resume_online(paused, offline, timer_opts(5_000))

    assert resumed.lifecycle == :active
    assert resumed.cooldowns == %{8001 => 5_500, 8002 => 5_000}
    assert resumed_runtime.active_deadline_ms == 6_000
    assert resumed_runtime.clocks_online

    for lifecycle <- [:rested, :dead] do
      state =
        homunculus(%{lifecycle: lifecycle, active_remaining_ms: 0, cooldowns: %{8001 => 250}})

      assert {:ok, resumed, resumed_runtime} =
               LifecycleHandler.resume_online(state, runtime(), timer_opts(8_000))

      assert resumed.cooldowns == %{8001 => 8_250}
      assert resumed_runtime.active_expiry_timer_ref == nil
      assert resumed_runtime.active_deadline_ms == nil
      assert is_reference(resumed_runtime.cooldown_timer_ref)
    end
  end

  test "offline pause fails closed when active online state has no deadline" do
    assert {:error, :invalid_state} =
             LifecycleHandler.pause_offline(
               homunculus(),
               runtime(%{clocks_online: true}),
               now_ms: 1_000
             )
  end

  test "every transition rejects malformed lifecycle and clock snapshots" do
    malformed = [
      {homunculus(%{max_hp: 0}), runtime()},
      {homunculus(%{hp: 1_001}), runtime()},
      {homunculus(%{action_state: :dead}), runtime()},
      {homunculus(%{lifecycle: :rested, target: {:mob, 1}}), runtime()},
      {homunculus(%{lifecycle: :dead, active_remaining_ms: 1}), runtime()},
      {homunculus(%{active_remaining_ms: "1000"}), runtime()},
      {homunculus(%{cooldowns: %{8001 => -1}}), runtime()},
      {homunculus(%{cooldowns: %{8001 => "1000"}}),
       online_runtime(2_000, %{cooldown_timer_ref: make_ref()})},
      {homunculus(), runtime(%{active_expiry_timer_ref: make_ref()})},
      {homunculus(), runtime(%{clocks_online: true})},
      {homunculus(%{lifecycle: :rested}),
       runtime(%{
         clocks_online: true,
         active_deadline_ms: 1_000,
         active_expiry_timer_ref: make_ref()
       })},
      {homunculus(%{cooldowns: %{8001 => 1_000}}),
       online_runtime(2_000, %{cooldown_timer_ref: nil})},
      {homunculus(), online_runtime(2_000, %{cooldown_timer_ref: make_ref()})}
    ]

    for {homunculus, runtime} <- malformed do
      assert {:error, :invalid_state} = LifecycleHandler.transfer(homunculus, runtime)
    end

    assert {:error, :invalid_state} =
             LifecycleHandler.first_creation(
               nil,
               homunculus(%{lifecycle: :rested, hp: 0}),
               runtime()
             )
  end

  test "owner death rests at the exact HP gate and keeps lower HP active" do
    runtime = online_runtime(10_000)
    at_gate = homunculus(%{hp: 800, max_hp: 1_000})
    below_gate = %{at_gate | hp: 799}

    assert {:ok, %{lifecycle: :rested}, _runtime} =
             LifecycleHandler.owner_died(at_gate, runtime)

    assert {:noop, ^below_gate, ^runtime} =
             LifecycleHandler.owner_died(below_gate, runtime)
  end

  test "transfer preserves state and both timer refs exactly" do
    homunculus = homunculus(%{cooldowns: %{8001 => 10_000}})
    runtime = online_runtime(20_000, %{cooldown_timer_ref: make_ref()})

    assert {:ok, ^homunculus, ^runtime} = LifecycleHandler.transfer(homunculus, runtime)
  end

  test "cooldown expiry ignores stale refs and removes only entries actually due" do
    current_ref = make_ref()
    stale_ref = make_ref()
    homunculus = homunculus(%{cooldowns: %{8001 => 900, 8002 => 1_000, 8003 => 1_500}})

    runtime =
      runtime(%{
        active_expiry_timer_ref: make_ref(),
        active_deadline_ms: 2_000,
        cooldown_timer_ref: current_ref,
        clocks_online: true
      })

    assert {:noop, ^homunculus, ^runtime} =
             LifecycleHandler.cooldowns_expired(homunculus, runtime, stale_ref, now_ms: 1_000)

    assert {:ok, ^homunculus, rearmed_runtime} =
             LifecycleHandler.cooldowns_expired(
               homunculus,
               runtime,
               current_ref,
               timer_opts(800)
             )

    rearmed_ref = rearmed_runtime.cooldown_timer_ref
    assert rearmed_ref != current_ref
    assert_receive {:timer_started, ^rearmed_ref, 100, :cooldowns_expired}

    assert {:ok, next, next_runtime} =
             LifecycleHandler.cooldowns_expired(
               homunculus,
               rearmed_runtime,
               rearmed_ref,
               timer_opts(1_000)
             )

    assert next.cooldowns == %{8003 => 1_500}
    assert is_reference(next_runtime.cooldown_timer_ref)
    assert_receive {:timer_started, timer_ref, 500, :cooldowns_expired}
    assert timer_ref == next_runtime.cooldown_timer_ref
  end

  defp timer_opts(now_ms) do
    test_pid = self()

    [
      now_ms: now_ms,
      timer_start: fn delay_ms, event ->
        ref = make_ref()
        send(test_pid, {:timer_started, ref, delay_ms, event})
        ref
      end,
      timer_cancel: fn ref -> send(test_pid, {:timer_cancelled, ref}) end
    ]
  end

  defp runtime(attrs \\ %{}) do
    struct!(%Runtime{private_dirty: false}, attrs)
  end

  defp online_runtime(deadline_ms, attrs \\ %{}) do
    runtime(
      Map.merge(
        %{
          active_expiry_timer_ref: make_ref(),
          active_deadline_ms: deadline_ms,
          clocks_online: true
        },
        attrs
      )
    )
  end

  defp homunculus(attrs \\ %{}) do
    lifecycle = Map.get(attrs, :lifecycle, :active)

    lifecycle_defaults =
      case lifecycle do
        :active -> %{hp: 800, active_remaining_ms: 1_000, action_state: :idle}
        :rested -> %{hp: 800, active_remaining_ms: 0, action_state: :idle}
        :dead -> %{hp: 0, active_remaining_ms: 0, action_state: :dead}
      end

    defaults = %{
      id: 1,
      owner_character_id: 42,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Lif",
      lifecycle: lifecycle,
      max_hp: 1_000,
      sp: 100,
      max_sp: 100,
      intimacy_hundredths: 2_100,
      cooldowns: %{},
      movement_state: :standing,
      target: nil,
      casting: nil
    }

    struct!(HomunculusState, defaults |> Map.merge(lifecycle_defaults) |> Map.merge(attrs))
  end
end
