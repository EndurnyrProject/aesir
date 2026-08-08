defmodule Aesir.ZoneServer.Mmo.StatusEffect.InterpreterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  defmodule PermanentStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_permanent,
      no_dispel: false,
      properties: [:buff],
      permanent: true
  end

  defmodule AilmentResistanceStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_ailment_resistance,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def modifiers(instance, _context), do: %{ailment_resist_rate: instance.val1}
  end

  defmodule FiniteDeathSurvivor do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_finite_death_survivor,
      no_dispel: false,
      properties: [:buff],
      remove_on_death: false
  end

  defmodule RejectedStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_rejected,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def on_apply(_target, _instance, _context), do: {:error, :rejected}
  end

  defmodule RejectedReplacementStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_rejected_replacement,
      no_dispel: false,
      properties: [:buff],
      end_on_start: [:sc_provoke]

    @impl true
    def on_apply(_target, _instance, _context), do: {:error, :rejected}
  end

  defmodule ReplacementStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_replacement,
      no_dispel: false,
      properties: [:buff],
      end_on_start: [:sc_provoke]

    @impl true
    def on_apply(_target, %{state: %{barrier: {test_pid, ref}}} = instance, _context) do
      send(test_pid, {:status_apply_waiting, ref})

      receive do
        {:continue_status_apply, ^ref} -> {:ok, instance}
      end
    end

    def on_apply(_target, instance, _context), do: {:ok, instance}

    @impl true
    def on_expire(_target, %{state: %{barrier: {test_pid, ref}}}, _context) do
      send(test_pid, {:status_apply_rolled_back, ref})
      :ok
    end

    def on_expire(_target, _instance, _context), do: :ok
  end

  defmodule GenerationStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_generation,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def on_expire(_target, %{state: %{observer: observer, generation: generation}}, _context) do
      send(observer, {:generation_expired, generation})
      :ok
    end
  end

  defmodule ExactTickStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_exact_tick,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def on_tick(_target, %{state: %{observer: observer, remove?: true}}, _context) do
      send(observer, :exact_tick_removed)
      :remove
    end

    def on_tick(_target, %{state: %{observer: observer, ticks: ticks}} = instance, _context) do
      send(observer, {:exact_tick, ticks + 1})
      {:ok, %{instance | state: %{instance.state | ticks: ticks + 1}}}
    end
  end

  defmodule MovementIntentStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_movement_intent,
      no_dispel: false,
      properties: [:buff]

    alias Aesir.ZoneServer.Mmo.StatusStorage

    @impl true
    def modifiers(%{state: %{wall: true}}, _context), do: %{movement_speed: -10}
    def modifiers(_instance, _context), do: %{}

    @impl true
    def on_movement_intent(
          {:player, target_id},
          %{state: %{observer: observer, action: action}} = instance,
          position,
          _context
        ) do
      send(observer, {:movement_intent, position})
      handle_action(action, target_id, instance)
    end

    @impl true
    def on_expire(_target, %{state: %{observer: observer}}, _context) do
      send(observer, :movement_intent_expired)
      :ok
    end

    defp handle_action(:update, _target_id, instance) do
      {:ok, %{instance | state: Map.put(instance.state, :wall, true)}}
    end

    defp handle_action(:remove, _target_id, _instance), do: :remove
    defp handle_action(:unchanged, _target_id, instance), do: {:ok, instance}

    defp handle_action(:replace_then_update, target_id, instance) do
      StatusStorage.apply_status(:player, target_id, :sc_test_movement_intent,
        state: %{observer: instance.state.observer, action: :unchanged, generation: :new}
      )

      {:ok, %{instance | state: Map.put(instance.state, :generation, :stale)}}
    end

    defp handle_action(:replace_then_remove, target_id, instance) do
      StatusStorage.apply_status(:player, target_id, :sc_test_movement_intent,
        state: %{observer: instance.state.observer, action: :unchanged, generation: :new}
      )

      :remove
    end
  end

  defmodule CommittedActionStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_committed_action,
      no_dispel: false,
      properties: [:buff],
      flags: [:no_pick_item]

    alias Aesir.ZoneServer.Mmo.StatusStorage

    @impl true
    def modifiers(%{state: %{modified?: true}}, _context), do: %{cri: 10}
    def modifiers(_instance, _context), do: %{}

    @impl true
    def on_committed_action(
          {:player, target_id},
          %{state: %{observer: observer, action: action}} = instance,
          committed_action,
          _context
        ) do
      send(observer, {:committed_action, committed_action})
      handle_action(action, target_id, instance)
    end

    @impl true
    def on_expire(_target, %{state: %{observer: observer}}, _context) do
      send(observer, :committed_action_expired)
      :ok
    end

    defp handle_action(:update, _target_id, instance) do
      {:ok, %{instance | state: Map.put(instance.state, :modified?, true)}}
    end

    defp handle_action(:remove, _target_id, _instance), do: :remove

    defp handle_action(:replace_then_remove, target_id, instance) do
      StatusStorage.apply_status(:player, target_id, :sc_test_committed_action,
        state: %{observer: instance.state.observer, action: :remove, generation: :new}
      )

      :remove
    end
  end

  defmodule UnrelatedFlagStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_unrelated_flag,
      no_dispel: false,
      flags: [:unrelated]
  end

  defmodule MutuallyExclusiveX do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mutually_exclusive_x,
      no_dispel: false,
      properties: [:buff],
      end_on_start: [:sc_test_mutually_exclusive_y]

    @impl true
    def on_expire(_target, %{state: %{barrier: {test_pid, ref}}}, _context) do
      send(test_pid, {:replacement_expiring, ref, self()})

      receive do
        {:continue_replacement, ^ref} -> :ok
      end
    end

    def on_expire(_target, _instance, _context), do: :ok
  end

  defmodule MutuallyExclusiveY do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_mutually_exclusive_y,
      no_dispel: false,
      properties: [:buff],
      end_on_start: [:sc_test_mutually_exclusive_x]

    @impl true
    def on_expire(_target, %{state: %{barrier: {test_pid, ref}}}, _context) do
      send(test_pid, {:replacement_expiring, ref, self()})

      receive do
        {:continue_replacement, ^ref} -> :ok
      end
    end

    def on_expire(_target, _instance, _context), do: :ok
  end

  defmodule SelfReplacingStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_self_replacing,
      no_dispel: false,
      properties: [:buff],
      end_on_start: [:sc_test_self_replacing]

    @impl true
    def on_expire(
          _target,
          %{
            state: %{
              observer: observer,
              generation: generation,
              barrier: {test_pid, ref}
            }
          },
          _context
        ) do
      send(observer, {:self_replacement_expired, generation})
      send(test_pid, {:self_replacement_expiring, ref, self()})

      receive do
        {:continue_self_replacement, ^ref} -> :ok
      end
    end

    def on_expire(_target, %{state: %{observer: observer, generation: generation}}, _context) do
      send(observer, {:self_replacement_expired, generation})
      :ok
    end
  end

  defmodule FollowUpStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_followup,
      no_dispel: false,
      properties: [:buff]

    @impl true
    def on_damage(_target, instance, _damage_info, _context) do
      {:ok, instance, [{:sc_provoke, [val1: 10]}]}
    end
  end

  defmodule InterceptStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_intercept,
      no_dispel: false,
      properties: [:buff]

    alias Aesir.ZoneServer.Mmo.StatusStorage

    @impl true
    def before_weapon_hit({unit_type, unit_id}, _instance, attack_info, _context) do
      case StatusStorage.take_status(unit_type, unit_id, :sc_test_intercept) do
        nil -> :continue
        _claimed -> {:intercept, attack_info}
      end
    end
  end

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  describe "on_committed_action/3 and has_active_flag?/3" do
    test "indexed statuses absent from the unit leave actions unchanged" do
      assert :unchanged = Interpreter.on_committed_action(:player, 7_600, :normal_attack)
      refute Interpreter.has_active_flag?(:player, 7_600, :not_indexed)
    end

    test "updates, removes, and ignores stale replacement results" do
      target_id = 7_601
      setup_player_mock(target_id)
      Registry.register_module(CommittedActionStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_committed_action,
          state: %{observer: self(), action: :update, modified?: false}
        )

      assert :changed = Interpreter.on_committed_action(:player, target_id, :normal_attack)
      assert_receive {:committed_action, :normal_attack}

      assert %{state: %{modified?: true}} =
               StatusStorage.get_status(:player, target_id, :sc_test_committed_action)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_committed_action,
          state: %{observer: self(), action: :remove}
        )

      assert :changed = Interpreter.on_committed_action(:player, target_id, {:skill, 5})
      assert_receive {:committed_action, {:skill, 5}}
      assert_receive :committed_action_expired
      refute StatusStorage.has_status?(:player, target_id, :sc_test_committed_action)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_committed_action,
          state: %{observer: self(), action: :replace_then_remove, generation: :old}
        )

      assert :unchanged = Interpreter.on_committed_action(:player, target_id, :normal_attack)

      assert %{state: %{generation: :new}} =
               StatusStorage.get_status(:player, target_id, :sc_test_committed_action)
    end

    test "queries only statuses indexed for the requested flag" do
      target_id = 7_602
      Registry.register_module(CommittedActionStatus)
      Registry.register_module(UnrelatedFlagStatus)

      :ok = StatusStorage.apply_status(:player, target_id, :sc_test_unrelated_flag)
      refute Interpreter.has_active_flag?(:player, target_id, :no_pick_item)

      :ok = StatusStorage.apply_status(:player, target_id, :sc_test_committed_action)
      assert Interpreter.has_active_flag?(:player, target_id, :no_pick_item)
    end
  end

  describe "on_movement_intent/3" do
    test "indexed statuses absent from the unit leave movement unchanged" do
      assert :unchanged =
               Interpreter.on_movement_intent(:player, 7_604, %{
                 map: "prontera",
                 x: 50,
                 y: 50
               })
    end

    test "stores a current-generation update and reports changed stats" do
      target_id = 7_605
      setup_player_mock(target_id)
      Registry.register_module(MovementIntentStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_movement_intent,
          state: %{observer: self(), action: :update, wall: false}
        )

      assert :changed =
               Interpreter.on_movement_intent(:player, target_id, %{
                 map: "prontera",
                 x: 50,
                 y: 50
               })

      assert_receive {:movement_intent, %{map: "prontera", x: 50, y: 50}}

      assert %{state: %{wall: true}} =
               StatusStorage.get_status(:player, target_id, :sc_test_movement_intent)
    end

    test "removes the current generation through its lifecycle" do
      target_id = 7_606
      setup_player_mock(target_id)
      Registry.register_module(MovementIntentStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_movement_intent,
          state: %{observer: self(), action: :remove, wall: true}
        )

      assert :changed =
               Interpreter.on_movement_intent(:player, target_id, %{
                 map: "prontera",
                 x: 50,
                 y: 50
               })

      assert_receive :movement_intent_expired
      refute StatusStorage.has_status?(:player, target_id, :sc_test_movement_intent)
    end

    test "does not overwrite or remove a replacement generation" do
      target_id = 7_607
      setup_player_mock(target_id)
      Registry.register_module(MovementIntentStatus)

      for action <- [:replace_then_update, :replace_then_remove] do
        :ok =
          StatusStorage.apply_status(:player, target_id, :sc_test_movement_intent,
            state: %{observer: self(), action: action, generation: :old}
          )

        assert :unchanged =
                 Interpreter.on_movement_intent(:player, target_id, %{
                   map: "prontera",
                   x: 50,
                   y: 50
                 })

        assert %{state: %{generation: :new}} =
                 StatusStorage.get_status(:player, target_id, :sc_test_movement_intent)

        refute_receive :movement_intent_expired
      end
    end
  end

  describe "process_tick_if_current/4" do
    test "ticks and continues only for the current generation" do
      target_id = 7_601
      setup_player_mock(target_id)
      Registry.register_module(ExactTickStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), ticks: 0}
        )

      entry = StatusStorage.get_status(:player, target_id, :sc_test_exact_tick)

      assert :continue =
               Interpreter.process_tick_if_current(
                 :player,
                 target_id,
                 :sc_test_exact_tick,
                 entry.generation
               )

      assert_receive {:exact_tick, 1}

      assert %{state: %{ticks: 1}} =
               StatusStorage.get_status(:player, target_id, :sc_test_exact_tick)
    end

    test "a replaced generation makes the captured tick a no-op" do
      target_id = 7_602
      setup_player_mock(target_id)
      Registry.register_module(ExactTickStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), ticks: 0}
        )

      stale_generation =
        StatusStorage.get_status(:player, target_id, :sc_test_exact_tick).generation

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), ticks: 10}
        )

      assert :stop =
               Interpreter.process_tick_if_current(
                 :player,
                 target_id,
                 :sc_test_exact_tick,
                 stale_generation
               )

      refute_receive {:exact_tick, _}

      assert %{state: %{ticks: 10}} =
               StatusStorage.get_status(:player, target_id, :sc_test_exact_tick)
    end

    test "a current terminal tick removes the status and stops" do
      target_id = 7_603
      setup_player_mock(target_id)
      Registry.register_module(ExactTickStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), remove?: true}
        )

      generation = StatusStorage.get_status(:player, target_id, :sc_test_exact_tick).generation

      assert :stop =
               Interpreter.process_tick_if_current(
                 :player,
                 target_id,
                 :sc_test_exact_tick,
                 generation
               )

      assert_receive :exact_tick_removed
      refute StatusStorage.has_status?(:player, target_id, :sc_test_exact_tick)
    end

    test "a removed generation makes the captured tick a no-op" do
      target_id = 7_604
      setup_player_mock(target_id)
      Registry.register_module(ExactTickStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), ticks: 0}
        )

      generation = StatusStorage.get_status(:player, target_id, :sc_test_exact_tick).generation
      :ok = StatusStorage.remove_status(:player, target_id, :sc_test_exact_tick)

      assert :stop =
               Interpreter.process_tick_if_current(
                 :player,
                 target_id,
                 :sc_test_exact_tick,
                 generation
               )

      refute_receive {:exact_tick, _}
    end

    @tag :capture_log
    test "an unexpected target lookup error removes the current generation and stops" do
      target_id = 7_608
      setup_player_mock(target_id)
      Registry.register_module(ExactTickStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), ticks: 0}
        )

      generation = StatusStorage.get_status(:player, target_id, :sc_test_exact_tick).generation
      stub(UnitRegistry, :get_unit_info, fn :player, ^target_id -> {:error, :unavailable} end)

      assert :stop =
               Interpreter.process_tick_if_current(
                 :player,
                 target_id,
                 :sc_test_exact_tick,
                 generation
               )

      refute_receive {:exact_tick, _}
      refute StatusStorage.has_status?(:player, target_id, :sc_test_exact_tick)
    end

    @tag :capture_log
    test "an unexpected target shape stops without removing a replacement generation" do
      target_id = 7_608
      setup_player_mock(target_id)
      Registry.register_module(ExactTickStatus)

      :ok =
        StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
          state: %{observer: self(), ticks: 0}
        )

      entry = StatusStorage.get_status(:player, target_id, :sc_test_exact_tick)

      stub(UnitRegistry, :get_unit_info, fn :player, ^target_id ->
        :ok =
          StatusStorage.apply_status(:player, target_id, :sc_test_exact_tick,
            state: %{observer: self(), ticks: 10}
          )

        {:ok, %{stats: nil}}
      end)

      assert :stop =
               Interpreter.process_tick_if_current(
                 :player,
                 target_id,
                 :sc_test_exact_tick,
                 entry.generation
               )

      refute_receive {:exact_tick, _}

      assert %{generation: generation, state: %{ticks: 10}} =
               StatusStorage.get_status(:player, target_id, :sc_test_exact_tick)

      assert generation > entry.generation
    end
  end

  describe "mob status application notification" do
    test "a successful tickless application asynchronously notifies the mob session" do
      mob_id = 8_801
      Registry.register_module(PermanentStatus)
      test_pid = self()

      living =
        struct!(MobState, %{
          instance_id: mob_id,
          mob_id: 1,
          mob_data: nil,
          spawn_ref: nil,
          x: 0,
          y: 0,
          map_name: "test",
          hp: 1,
          max_hp: 1,
          sp: 0,
          max_sp: 0,
          spawned_at: 0,
          is_dead: false
        })

      stub(UnitRegistry, :get_unit, fn :mob, ^mob_id ->
        {:ok, {nil, living, test_pid}}
      end)

      stub(UnitRegistry, :get_unit_info, fn :mob, ^mob_id ->
        {:ok, %{stats: %{}, boss_flag: false}}
      end)

      assert :ok = Interpreter.apply_status(:mob, mob_id, :sc_test_permanent)
      assert_receive {:"$gen_cast", {:casting, {:status_changed, :sc_test_permanent, :apply}}}
    end
  end

  describe "before_weapon_hit/3" do
    test "intercepts a weapon hit and atomically consumes the single-use status" do
      target_id = 7_701
      setup_player_mock(target_id)
      Registry.register_module(InterceptStatus)
      :ok = StatusStorage.apply_status(:player, target_id, :sc_test_intercept)

      attack_info = %{attacker: {:mob, 44}, target: {:player, target_id}, melee?: true}

      assert {:intercept, ^attack_info} =
               Interpreter.before_weapon_hit(:player, target_id, attack_info)

      assert StatusStorage.get_status(:player, target_id, :sc_test_intercept) == nil
    end

    test "a second swing continues once the single-use status is consumed" do
      target_id = 7_702
      setup_player_mock(target_id)
      Registry.register_module(InterceptStatus)
      :ok = StatusStorage.apply_status(:player, target_id, :sc_test_intercept)

      attack_info = %{attacker: {:mob, 44}, target: {:player, target_id}}

      assert {:intercept, ^attack_info} =
               Interpreter.before_weapon_hit(:player, target_id, attack_info)

      assert :continue = Interpreter.before_weapon_hit(:player, target_id, attack_info)
    end

    test "continues in constant time when the target has no interception-capable status" do
      target_id = 7_703
      attack_info = %{attacker: {:mob, 44}, target: {:player, target_id}}

      assert :continue = Interpreter.before_weapon_hit(:player, target_id, attack_info)
    end

    test "resolves interception in explicit priority order, not storage order" do
      alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.AutoCounter
      alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autoguard

      target_id = 7_704
      setup_player_mock(target_id)
      Registry.register_module(Autoguard)
      Registry.register_module(AutoCounter)
      Mimic.copy(Autoguard)
      Mimic.copy(AutoCounter)

      # Apply Autoguard first so raw storage-iteration order would let it win;
      # the explicit precedence must still pick the higher-priority Auto Counter.
      :ok = StatusStorage.apply_status(:player, target_id, :sc_autoguard)
      :ok = StatusStorage.apply_status(:player, target_id, :sc_auto_counter)

      stub(Autoguard, :before_weapon_hit, fn _t, _i, _a, _c -> {:intercept, :blocked} end)
      stub(AutoCounter, :before_weapon_hit, fn _t, _i, _a, _c -> {:intercept, :auto_counter} end)

      attack_info = %{attacker: {:mob, 44}, target: {:player, target_id}}

      assert {:intercept, :auto_counter} =
               Interpreter.before_weapon_hit(:player, target_id, attack_info)
    end
  end

  test "Lex Aeterna atomically grants its double to one of two concurrent hits" do
    target_id = 9_001
    hit = %{dmg_type: :physical, is_short: true, element: :neutral, skill_id: 28}

    stub(UnitRegistry, :get_unit_info, fn :mob, ^target_id -> {:ok, %{stats: %{}}} end)
    :ok = StatusStorage.apply_status(:mob, target_id, :sc_aeterna)

    parent = self()

    tasks =
      for _ <- 1..2 do
        Task.async(fn ->
          send(parent, {:lex_attacker_ready, self()})

          receive do
            :deliver_hit -> Interpreter.absorb_damage(:mob, target_id, 50, hit)
          end
        end)
      end

    Enum.each(tasks, &Mimic.allow(UnitRegistry, self(), &1.pid))

    attacker_pids =
      for _ <- 1..2 do
        assert_receive {:lex_attacker_ready, attacker_pid}
        attacker_pid
      end

    Enum.each(attacker_pids, &send(&1, :deliver_hit))

    assert Enum.sort(Enum.map(tasks, &Task.await(&1))) == [50, 100]
    refute StatusStorage.has_status?(:mob, target_id, :sc_aeterna)
  end

  test "Lex Aeterna keeps its mark for real excluded skill IDs" do
    target_id = 9_002

    stub(UnitRegistry, :get_unit_info, fn :mob, ^target_id -> {:ok, %{stats: %{}}} end)

    for hit <- [
          %{dmg_type: :physical, is_short: true, element: :neutral, skill_id: 379},
          %{dmg_type: :magic, is_short: false, element: :neutral, skill_id: 375}
        ] do
      :ok = StatusStorage.apply_status(:mob, target_id, :sc_aeterna)
      assert Interpreter.absorb_damage(:mob, target_id, 50, hit) == 50
      assert StatusStorage.has_status?(:mob, target_id, :sc_aeterna)
      :ok = StatusStorage.remove_status(:mob, target_id, :sc_aeterna)
    end
  end

  describe "apply_status/9" do
    test "applies a status to a target" do
      target_id = 1
      status_id = :sc_provoke
      val1 = 10
      val2 = 20

      setup_player_mock(target_id)

      assert :ok = Interpreter.apply_status(:player, target_id, status_id, val1: val1, val2: val2)
      assert StatusStorage.has_status?(:player, target_id, status_id)
    end

    test "rejects ordinary status application to a corpse" do
      target_id = 99
      corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

      stub(UnitRegistry, :get_unit, fn :player, ^target_id ->
        {:ok, {PlayerState, corpse, self()}}
      end)

      assert {:error, :target_dead} = Interpreter.apply_status(:player, target_id, :sc_provoke)
      refute StatusStorage.has_status?(:player, target_id, :sc_provoke)
    end

    test "permanent status is stored with nil expires_at" do
      target_id = 2

      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)
      apply_ailment_resistance(target_id, 100)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_permanent,
                 resistance_roll: fn _rate -> flunk("permanent status must not roll") end
               )

      assert %{expires_at: nil} = StatusStorage.get_status(:player, target_id, :sc_test_permanent)
    end

    test "non-permanent status without duration gets a default expiry" do
      target_id = 3

      setup_player_mock(target_id)

      assert :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)
      assert %{expires_at: expires_at} = StatusStorage.get_status(:player, target_id, :sc_provoke)
      assert is_integer(expires_at)
    end

    test "raises error when player not found" do
      target_id = 9999
      status_id = :sc_provoke

      assert_raise RuntimeError, ~r/Cannot apply status effect to non-existent/, fn ->
        Interpreter.apply_status(:player, target_id, status_id, val1: 0)
      end
    end
  end

  describe "apply_status/4 explicit duration" do
    test "honors an explicit :duration param as the stored expiry" do
      target_id = 10

      setup_player_mock(target_id)

      override = 30_000
      before_ms = System.monotonic_time(:millisecond)
      assert :ok = Interpreter.apply_status(:player, target_id, :sc_hiding, duration: override)
      after_ms = System.monotonic_time(:millisecond)

      assert %{expires_at: expires_at} =
               StatusStorage.get_status(:player, target_id, :sc_hiding)

      assert expires_at >= before_ms + override
      assert expires_at <= after_ms + override
    end

    test "falls back to the definition default when :duration is omitted" do
      target_id = 11

      setup_player_mock(target_id)

      default = 10_000
      before_ms = System.monotonic_time(:millisecond)
      assert :ok = Interpreter.apply_status(:player, target_id, :sc_hiding)
      after_ms = System.monotonic_time(:millisecond)

      assert %{expires_at: expires_at} =
               StatusStorage.get_status(:player, target_id, :sc_hiding)

      assert expires_at >= before_ms + default
      assert expires_at <= after_ms + default
    end

    test "permanent status ignores a passed :duration" do
      target_id = 12

      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_permanent, duration: 30_000)

      assert %{expires_at: nil} =
               StatusStorage.get_status(:player, target_id, :sc_test_permanent)
    end

    test "ailment resistance lowers a debuff's final infliction rate" do
      target_id = 24
      test_pid = self()

      setup_player_mock(target_id, stats: %{mdef: 0})
      apply_ailment_resistance(target_id, 40)

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        final_rate >= 80
      end

      assert {:error, :resisted} =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 success_rate: 100,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, 60.0}
      refute StatusStorage.has_status?(:player, target_id, :sc_freeze)
    end

    test "ailment resistance leaves a buff's final infliction rate unchanged" do
      target_id = 25
      test_pid = self()

      setup_player_mock(target_id)
      apply_ailment_resistance(target_id, 40)

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        final_rate >= 63
      end

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_hiding,
                 success_rate: 63,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, 63.0}
      assert StatusStorage.has_status?(:player, target_id, :sc_hiding)
    end

    test "ailment resistance floors the final infliction rate at zero" do
      target_id = 26
      test_pid = self()

      setup_player_mock(target_id, stats: %{mdef: 20})
      apply_ailment_resistance(target_id, 100)

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        false
      end

      assert {:error, :resisted} =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 success_rate: 100,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, 0}
    end

    test "Freeze rolls its final skill chance once and stores its MDEF-adjusted duration" do
      target_id = 13
      test_pid = self()

      setup_player_mock(target_id, stats: %{mdef: 20})

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        true
      end

      before_ms = System.monotonic_time(:millisecond)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 38,
                 resistance_roll: resistance_roll
               )

      after_ms = System.monotonic_time(:millisecond)
      assert_received {:final_rate, 30.4}
      refute_received {:final_rate, _rate}

      assert %{expires_at: expires_at} =
               StatusStorage.get_status(:player, target_id, :sc_freeze)

      assert expires_at >= before_ms + 4_200
      assert expires_at <= after_ms + 4_200
    end

    test "application resistance bypass preserves the exact duration without rolling" do
      target_id = 21

      setup_player_mock(target_id,
        stats: %{mdef: 99},
        equip_modifiers: %{{:res_eff, :sc_freeze} => 10_000}
      )

      apply_ailment_resistance(target_id, 100)
      before_ms = System.monotonic_time(:millisecond)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 3_000,
                 success_rate: 0,
                 bypass_resistance: true,
                 resistance_roll: fn _rate -> flunk("bypassed status must not roll") end
               )

      after_ms = System.monotonic_time(:millisecond)
      assert %{expires_at: expires_at} = StatusStorage.get_status(:player, target_id, :sc_freeze)
      assert expires_at >= before_ms + 3_000
      assert expires_at <= after_ms + 3_000
    end

    test "application resistance bypass still respects hard and boss immunity" do
      setup_player_mock(22, custom_immunities: [:freeze])

      assert {:error, :immune} =
               Interpreter.apply_status(:player, 22, :sc_freeze,
                 duration: 3_000,
                 bypass_resistance: true
               )

      setup_player_mock(23, boss_flag: true)

      assert {:error, :boss_immune} =
               Interpreter.apply_status(:player, 23, :sc_hiding,
                 duration: 3_000,
                 bypass_resistance: true,
                 caster_id: 1
               )
    end

    test "Freeze rejects bosses through status immunity" do
      target_id = 14
      setup_player_mock(target_id, boss_flag: true)

      assert {:error, :immune} =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 100,
                 resistance_roll: fn _rate -> flunk("immune target must not roll") end
               )
    end

    test "Freeze respects the unit's custom freeze immunity" do
      target_id = 15
      setup_player_mock(target_id, custom_immunities: [:freeze])

      assert {:error, :immune} =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 100,
                 resistance_roll: fn _rate -> flunk("immune target must not roll") end
               )
    end

    test "res_eff equipment tolerance lowers the final infliction rate below the roll threshold" do
      target_id = 16
      test_pid = self()

      setup_player_mock(target_id,
        stats: %{mdef: 20},
        equip_modifiers: %{{:res_eff, :sc_freeze} => 500}
      )

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        final_rate >= 30
      end

      assert {:error, :resisted} =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 38,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, rate}
      assert_in_delta rate, 25.4, 0.0001
      refute StatusStorage.has_status?(:player, target_id, :sc_freeze)
    end

    test "res_eff_exempt: true skips the tolerance for sources that already subtracted it" do
      target_id = 19
      test_pid = self()

      setup_player_mock(target_id,
        stats: %{mdef: 20},
        equip_modifiers: %{{:res_eff, :sc_freeze} => 500}
      )

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        final_rate >= 30
      end

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 38,
                 res_eff_exempt: true,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, rate}
      assert_in_delta rate, 30.4, 0.0001
      assert StatusStorage.has_status?(:player, target_id, :sc_freeze)
    end

    test "the same rate with no res_eff tolerance clears the roll threshold" do
      target_id = 17
      test_pid = self()

      setup_player_mock(target_id, stats: %{mdef: 20})

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        final_rate >= 30
      end

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 38,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, rate}
      assert_in_delta rate, 30.4, 0.0001
      assert StatusStorage.has_status?(:player, target_id, :sc_freeze)
    end

    test "a res_eff for a different status leaves Freeze unaffected" do
      target_id = 18
      test_pid = self()

      setup_player_mock(target_id,
        stats: %{mdef: 20},
        equip_modifiers: %{{:res_eff, :sc_stun} => 5_000}
      )

      resistance_roll = fn final_rate ->
        send(test_pid, {:final_rate, final_rate})
        true
      end

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_freeze,
                 duration: 1_500,
                 success_rate: 38,
                 resistance_roll: resistance_roll
               )

      assert_received {:final_rate, rate}
      assert_in_delta rate, 30.4, 0.0001
    end
  end

  describe "apply_status/4 loaded (persisted restore)" do
    test "skips the resistance roll and stores the duration as-is" do
      target_id = 20

      setup_player_mock(target_id)
      apply_ailment_resistance(target_id, 100)
      stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> false end)

      assert {:error, :resisted} =
               Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)

      before_ms = System.monotonic_time(:millisecond)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_provoke,
                 val1: 10,
                 duration: 12_000,
                 loaded: true,
                 resistance_roll: fn _rate -> flunk("loaded status must not roll") end
               )

      assert %{expires_at: expires_at} =
               StatusStorage.get_status(:player, target_id, :sc_provoke)

      assert expires_at >= before_ms + 12_000
    end

    test "rejects missing, non-positive, and malformed finite durations before insertion" do
      target_id = 21
      setup_player_mock(target_id)

      for duration <- [nil, 0, -1, "12 seconds"] do
        assert {:error, :invalid_duration} =
                 Interpreter.apply_status(:player, target_id, :sc_provoke,
                   duration: duration,
                   loaded: true
                 )

        refute StatusStorage.has_status?(:player, target_id, :sc_provoke)
      end
    end

    test "restores a permanent status without an expiry" do
      target_id = 22

      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_permanent, loaded: true)

      assert %{expires_at: nil} =
               StatusStorage.get_status(:player, target_id, :sc_test_permanent)
    end
  end

  describe "application owner refresh" do
    test "notifies the player owner asynchronously only after a successful application" do
      target_id = 23
      setup_player_mock(target_id)
      Registry.register_module(RejectedStatus)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      assert {:error, :rejected} =
               Interpreter.apply_status(:player, target_id, :sc_test_rejected,
                 owner_refresh: :notify
               )

      refute_receive :recalculate_stats

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_provoke,
                 val1: 10,
                 owner_refresh: :notify
               )

      assert_receive :recalculate_stats
      refute_receive :recalculate_stats
    end

    test "a rejected replacement leaves the existing status and owner untouched" do
      target_id = 24
      setup_player_mock(target_id)
      Registry.register_module(RejectedReplacementStatus)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)

      assert {:error, :rejected} =
               Interpreter.apply_status(:player, target_id, :sc_test_rejected_replacement,
                 owner_refresh: :notify
               )

      assert StatusStorage.has_status?(:player, target_id, :sc_provoke)
      refute StatusStorage.has_status?(:player, target_id, :sc_test_rejected_replacement)
      refute_receive :recalculate_stats
    end

    test "a successful replacement emits only its final owner refresh" do
      target_id = 25
      setup_player_mock(target_id)
      Registry.register_module(ReplacementStatus)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_replacement,
                 owner_refresh: :notify
               )

      refute StatusStorage.has_status?(:player, target_id, :sc_provoke)
      assert StatusStorage.has_status?(:player, target_id, :sc_test_replacement)
      assert_receive :recalculate_stats
      refute_receive :recalculate_stats
    end

    test "death rollback leaves a newer same-type generation untouched" do
      target_id = 26
      test_pid = self()
      setup_player_mock(target_id)
      Registry.register_module(GenerationStatus)
      observe_status_display(test_pid)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      living = %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 1}}}
      dead = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}
      block_liveness_check(target_id, test_pid)

      task =
        Task.async(fn ->
          Interpreter.apply_status(:player, target_id, :sc_test_generation,
            state: %{observer: test_pid, generation: :first},
            owner_refresh: :notify
          )
        end)

      task_pid = task.pid
      allow_application_mocks(task_pid)
      assert_receive {:liveness_check, ^task_pid}
      send(task_pid, {:liveness_result, living})
      assert_receive {:liveness_check, ^task_pid}

      assert %StatusEntry{state: %{generation: :first}} =
               StatusStorage.get_status(:player, target_id, :sc_test_generation)

      {:stored, newer, _prior} =
        StatusStorage.apply_status_with_entry(:player, target_id, :sc_test_generation,
          state: %{observer: test_pid, generation: :newer}
        )

      send(task.pid, {:liveness_result, dead})

      assert {:error, :target_dead} = Task.await(task)
      assert StatusStorage.get_status(:player, target_id, :sc_test_generation) === newer
      refute_receive {:generation_expired, _generation}
      refute_receive {:status_display, _event, _generation}
      refute_receive :recalculate_stats
    end

    test "a superseded application is not displayed or refreshed as current" do
      target_id = 27
      test_pid = self()
      setup_player_mock(target_id)
      Registry.register_module(GenerationStatus)
      observe_status_display(test_pid)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      living = %PlayerState{action_state: :idle, stats: %{current_state: %{hp: 1}}}
      block_liveness_check(target_id, test_pid)

      task =
        Task.async(fn ->
          Interpreter.apply_status(:player, target_id, :sc_test_generation,
            state: %{observer: test_pid, generation: :first},
            owner_refresh: :notify
          )
        end)

      task_pid = task.pid
      allow_application_mocks(task_pid)
      assert_receive {:liveness_check, ^task_pid}
      send(task_pid, {:liveness_result, living})
      assert_receive {:liveness_check, ^task_pid}

      %StatusEntry{generation: first_generation} =
        StatusStorage.get_status(:player, target_id, :sc_test_generation)

      {:stored, newer, _prior} =
        StatusStorage.apply_status_with_entry(:player, target_id, :sc_test_generation,
          state: %{observer: test_pid, generation: :newer}
        )

      send(task_pid, {:liveness_result, living})

      assert :ok = Task.await(task)
      assert StatusStorage.get_status(:player, target_id, :sc_test_generation) === newer
      assert newer.generation > first_generation
      refute_receive {:status_display, _event, _generation}
      refute_receive {:generation_expired, _generation}
      refute_receive :recalculate_stats
    end

    test "a mutually exclusive reapplication discarded by a newer status removes its displayed icon" do
      target_id = 28
      test_pid = self()
      setup_player_mock(target_id)
      Registry.register_module(MutuallyExclusiveX)
      Registry.register_module(MutuallyExclusiveY)
      observe_status_display(test_pid)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_mutually_exclusive_x,
                 state: %{generation: :displayed}
               )

      assert_receive {:status_display, :applied, :displayed}

      {:stored, _old_y, nil} =
        StatusStorage.apply_status_with_entry(
          :player,
          target_id,
          :sc_test_mutually_exclusive_y,
          state: %{barrier: {test_pid, :old_y}, generation: :old_y}
        )

      x_task =
        Task.async(fn ->
          Interpreter.apply_status(:player, target_id, :sc_test_mutually_exclusive_x,
            state: %{generation: :reapplication}
          )
        end)

      allow_application_mocks(x_task.pid)
      assert_receive {:replacement_expiring, :old_y, x_pid}

      {:stored, newer_y, _prior_y} =
        StatusStorage.apply_status_with_entry(
          :player,
          target_id,
          :sc_test_mutually_exclusive_y,
          state: %{generation: :newer_y}
        )

      send(x_pid, {:continue_replacement, :old_y})

      assert :ok = Task.await(x_task)
      refute StatusStorage.has_status?(:player, target_id, :sc_test_mutually_exclusive_x)

      assert StatusStorage.get_status(:player, target_id, :sc_test_mutually_exclusive_y) ===
               newer_y

      assert_receive {:status_display, :removed, :reapplication}
      refute_receive {:status_display, :removed, :newer_y}
    end

    test "concurrent mutually exclusive applications leave only the highest generation" do
      target_id = 28
      test_pid = self()
      setup_player_mock(target_id)
      Registry.register_module(MutuallyExclusiveX)
      Registry.register_module(MutuallyExclusiveY)

      {:stored, _old_y, nil} =
        StatusStorage.apply_status_with_entry(
          :player,
          target_id,
          :sc_test_mutually_exclusive_y,
          state: %{barrier: {test_pid, :old_y}}
        )

      x_task =
        Task.async(fn ->
          Interpreter.apply_status(:player, target_id, :sc_test_mutually_exclusive_x)
        end)

      Mimic.allow(UnitRegistry, self(), x_task.pid)
      Mimic.allow(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, self(), x_task.pid)

      assert_receive {:replacement_expiring, :old_y, x_pid}

      x = StatusStorage.get_status(:player, target_id, :sc_test_mutually_exclusive_x)

      y_task =
        Task.async(fn ->
          Interpreter.apply_status(:player, target_id, :sc_test_mutually_exclusive_y)
        end)

      Mimic.allow(UnitRegistry, self(), y_task.pid)
      Mimic.allow(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, self(), y_task.pid)

      assert :ok = Task.await(y_task)
      send(x_pid, {:continue_replacement, :old_y})
      assert :ok = Task.await(x_task)

      refute StatusStorage.has_status?(:player, target_id, :sc_test_mutually_exclusive_x)

      assert %StatusEntry{} =
               y =
               StatusStorage.get_status(:player, target_id, :sc_test_mutually_exclusive_y)

      assert y.generation > x.generation
    end

    test "same-status end_on_start expires the exact prior generation without deleting the new one" do
      target_id = 29
      test_pid = self()
      setup_player_mock(target_id)
      Registry.register_module(SelfReplacingStatus)
      observe_status_display(test_pid)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_self_replacing,
                 state: %{observer: test_pid, generation: :first}
               )

      assert_receive {:status_display, :applied, :first}

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_self_replacing,
                 state: %{observer: test_pid, generation: :second},
                 owner_refresh: :notify
               )

      assert_receive {:self_replacement_expired, :first}
      assert_receive {:status_display, :applied, :second}
      assert_receive :recalculate_stats

      refute_receive {:self_replacement_expired, :first}
      refute_receive {:status_display, :removed, :first}
      refute_receive :recalculate_stats

      assert %StatusEntry{state: %{generation: :second}} =
               StatusStorage.get_status(:player, target_id, :sc_test_self_replacing)
    end

    test "three same-status replacements do not finish a superseded middle generation" do
      target_id = 30
      test_pid = self()
      setup_player_mock(target_id)
      Registry.register_module(SelfReplacingStatus)
      observe_status_display(test_pid)
      PubSub.subscribe(Aesir.PubSub, "player:#{target_id}")

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_self_replacing,
                 state: %{
                   observer: test_pid,
                   generation: :a,
                   barrier: {test_pid, :a}
                 }
               )

      assert_receive {:status_display, :applied, :a}

      b_task =
        Task.async(fn ->
          Interpreter.apply_status(:player, target_id, :sc_test_self_replacing,
            state: %{observer: test_pid, generation: :b},
            owner_refresh: :notify
          )
        end)

      allow_application_mocks(b_task.pid)
      assert_receive {:self_replacement_expired, :a}
      assert_receive {:self_replacement_expiring, :a, b_pid}

      assert %StatusEntry{state: %{generation: :b}} =
               StatusStorage.get_status(:player, target_id, :sc_test_self_replacing)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_self_replacing,
                 state: %{observer: test_pid, generation: :c}
               )

      assert_receive {:self_replacement_expired, :b}
      assert_receive {:status_display, :applied, :c}
      refute_receive {:status_display, :removed, :b}

      send(b_pid, {:continue_self_replacement, :a})
      assert :ok = Task.await(b_task)
      refute_receive {:status_display, :removed, :a}

      assert %StatusEntry{state: %{generation: :c}} =
               StatusStorage.get_status(:player, target_id, :sc_test_self_replacing)

      refute_receive {:self_replacement_expired, :a}
      refute_receive {:self_replacement_expired, :b}
      refute_receive {:status_display, :applied, :b}
      refute_receive :recalculate_stats
    end
  end

  describe "remove_status/2" do
    test "removes a status from a target" do
      target_id = 1
      status_id = :sc_provoke
      val1 = 10

      # Mock player session
      setup_player_mock(target_id)

      # First apply the status
      :ok = Interpreter.apply_status(:player, target_id, status_id, val1: val1)
      assert StatusStorage.has_status?(:player, target_id, status_id)

      # Then remove it
      :ok = Interpreter.remove_status(:player, target_id, status_id)
      refute StatusStorage.has_status?(:player, target_id, status_id)
    end
  end

  describe "remove_on_death/2" do
    test "removes default statuses while preserving permanent and finite opt-outs" do
      target_id = 30
      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)
      Registry.register_module(FiniteDeathSurvivor)

      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_permanent)

      :ok =
        Interpreter.apply_status(:player, target_id, :sc_test_finite_death_survivor,
          duration: 12_000
        )

      :ok = Interpreter.remove_on_death(:player, target_id)

      refute StatusStorage.has_status?(:player, target_id, :sc_provoke)
      assert StatusStorage.has_status?(:player, target_id, :sc_test_permanent)

      assert %{expires_at: expires_at} =
               StatusStorage.get_status(:player, target_id, :sc_test_finite_death_survivor)

      assert is_integer(expires_at)
    end
  end

  describe "remove_all_statuses/3" do
    test "removes every active status by default, permanent included" do
      target_id = 30

      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)

      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_permanent)

      :ok = Interpreter.remove_all_statuses(:player, target_id)

      refute StatusStorage.has_status?(:player, target_id, :sc_provoke)
      refute StatusStorage.has_status?(:player, target_id, :sc_test_permanent)
    end

    test "except_permanent: true clears everything but permanent statuses" do
      target_id = 31

      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)

      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)
      :ok = Interpreter.apply_status(:player, target_id, :sc_test_permanent)

      :ok = Interpreter.remove_all_statuses(:player, target_id, except_permanent: true)

      refute StatusStorage.has_status?(:player, target_id, :sc_provoke)
      assert StatusStorage.has_status?(:player, target_id, :sc_test_permanent)
    end
  end

  describe "on_damage/2" do
    test "processes damage events for all statuses" do
      target_id = 1

      # Mock player session
      setup_player_mock(target_id)

      # First apply some status
      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)

      # Trigger damage event
      damage_info = %{damage: 100, element: :neutral, dmg_type: :physical}
      Interpreter.on_damage(:player, target_id, damage_info)

      # We can't easily assert effects here without mocking,
      # but we can at least verify it doesn't crash
    end

    test "drains follow-up applications requested by an on_damage callback" do
      target_id = 1

      setup_player_mock(target_id)
      Registry.register_module(FollowUpStatus)

      :ok = Interpreter.apply_status(:player, target_id, :sc_test_followup)
      refute StatusStorage.has_status?(:player, target_id, :sc_provoke)

      damage_info = %{damage: 100, element: :neutral, hp_after: 50, max_hp: 1000}
      Interpreter.on_damage(:player, target_id, damage_info)

      assert StatusStorage.has_status?(:player, target_id, :sc_provoke)
    end
  end

  describe "toggle_status/4" do
    test "first call applies the status, second call removes it" do
      target_id = 1
      status_id = :sc_provoke

      setup_player_mock(target_id)

      assert {:ok, :applied} = Interpreter.toggle_status(:player, target_id, status_id, val1: 10)
      assert StatusStorage.has_status?(:player, target_id, status_id)

      assert {:ok, :removed} = Interpreter.toggle_status(:player, target_id, status_id, val1: 10)
      refute StatusStorage.has_status?(:player, target_id, status_id)
    end

    @tag :capture_log
    test "propagates error when apply_status fails" do
      target_id = 1
      status_id = :sc_nonexistent_status

      assert {:error, :unknown_status} =
               Interpreter.toggle_status(:player, target_id, status_id, val1: 10)
    end
  end

  describe "get_all_modifiers/1" do
    test "returns modifiers for all active statuses" do
      target_id = 1

      # Mock player session
      setup_player_mock(target_id)

      # Status with modifiers
      :ok = Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10, val2: 20)

      modifiers = Interpreter.get_all_modifiers(:player, target_id)

      # The provoke status adds HIT=val3 (which is 0 in this case)
      assert is_map(modifiers)
      assert Map.has_key?(modifiers, :hit)
    end
  end

  defp observe_status_display(test_pid) do
    Mimic.copy(StatusDisplay)

    stub(StatusDisplay, :on_applied, fn _unit_type, _unit_id, _status_id, instance ->
      send(test_pid, {:status_display, :applied, instance.state.generation})
      :ok
    end)

    stub(StatusDisplay, :on_removed, fn _unit_type, _unit_id, _status_id, instance ->
      send(test_pid, {:status_display, :removed, instance.state.generation})
      :ok
    end)
  end

  defp block_liveness_check(target_id, test_pid) do
    stub(UnitRegistry, :get_unit, fn :player, ^target_id ->
      send(test_pid, {:liveness_check, self()})

      receive do
        {:liveness_result, state} -> {:ok, {PlayerState, state, self()}}
      end
    end)
  end

  defp allow_application_mocks(task_pid) do
    Mimic.allow(UnitRegistry, self(), task_pid)
    Mimic.allow(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, self(), task_pid)
    Mimic.allow(StatusDisplay, self(), task_pid)
  end

  defp apply_ailment_resistance(target_id, rate) do
    Registry.register_module(AilmentResistanceStatus)

    StatusStorage.apply_status(:player, target_id, :sc_test_ailment_resistance, val1: rate)
  end

  # Helper to set up player mock with stats
  defp setup_player_mock(player_id, overrides \\ []) do
    # Copy and stub necessary modules
    Mimic.copy(Aesir.ZoneServer.Mmo.StatusEffect.Resistance)
    Mimic.copy(UnitRegistry)

    # Mock UnitRegistry to return entity info
    stats =
      Map.merge(
        %{
          max_hp: 1000,
          max_sp: 100,
          hp: 800,
          sp: 80,
          level: 50,
          base_level: 50,
          str: 10,
          agi: 10,
          vit: 10,
          int: 10,
          dex: 10,
          luk: 10,
          mdef: 5
        },
        Keyword.get(overrides, :stats, %{})
      )

    entity_info =
      Map.merge(
        %{
          unit_id: player_id,
          unit_type: :player,
          race: :human,
          element: :neutral,
          element_level: 1,
          boss_flag: false,
          size: :medium,
          stats: stats
        },
        Map.new(Keyword.delete(overrides, :stats))
      )

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok, entity_info}
    end)

    # Stub resistance roll to always succeed for predictable tests
    stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> true end)
  end
end
