defmodule Aesir.ZoneServer.Mmo.StatusEffect.InterpreterTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule PermanentStatus do
    use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
      id: :sc_test_permanent,
      no_dispel: false,
      properties: [:buff],
      permanent: true
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

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

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

      assert :ok = Interpreter.apply_status(:player, target_id, :sc_test_permanent)
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
      stub(Aesir.ZoneServer.Mmo.StatusEffect.Resistance, :roll_success, fn _ -> false end)

      assert {:error, :resisted} =
               Interpreter.apply_status(:player, target_id, :sc_provoke, val1: 10)

      before_ms = System.monotonic_time(:millisecond)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_provoke,
                 val1: 10,
                 duration: 12_000,
                 loaded: true
               )

      assert %{expires_at: expires_at} =
               StatusStorage.get_status(:player, target_id, :sc_provoke)

      assert expires_at >= before_ms + 12_000
    end

    test "restores a permanent status without an expiry" do
      target_id = 21

      setup_player_mock(target_id)
      Registry.register_module(PermanentStatus)

      assert :ok =
               Interpreter.apply_status(:player, target_id, :sc_test_permanent, loaded: true)

      assert %{expires_at: nil} =
               StatusStorage.get_status(:player, target_id, :sc_test_permanent)
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
