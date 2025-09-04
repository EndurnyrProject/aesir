defmodule Aesir.ZoneServer.Unit.Player.PlayerStateTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  describe "state transitions" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "initial state is idle", %{state: state} do
      assert state.action_state == :idle
    end

    test "can transition from idle to moving", %{state: state} do
      assert {:ok, new_state} = PlayerState.transition_to(state, :moving)
      assert new_state.action_state == :moving
    end

    test "can transition from idle to combat_moving", %{state: state} do
      assert {:ok, new_state} = PlayerState.transition_to(state, :combat_moving)
      assert new_state.action_state == :combat_moving
    end

    test "can transition from idle to attacking", %{state: state} do
      assert {:ok, new_state} = PlayerState.transition_to(state, :attacking)
      assert new_state.action_state == :attacking
    end

    test "can transition from combat_moving to attacking", %{state: state} do
      {:ok, combat_moving_state} = PlayerState.transition_to(state, :combat_moving)
      assert {:ok, attacking_state} = PlayerState.transition_to(combat_moving_state, :attacking)
      assert attacking_state.action_state == :attacking
    end

    test "cannot transition from dead to attacking", %{state: state} do
      {:ok, dead_state} = PlayerState.transition_to(state, :dead)
      assert {:error, :invalid_transition} = PlayerState.transition_to(dead_state, :attacking)
    end

    test "can always transition to dead", %{state: state} do
      {:ok, moving_state} = PlayerState.transition_to(state, :moving)
      assert {:ok, dead_state} = PlayerState.transition_to(moving_state, :dead)
      assert dead_state.action_state == :dead
    end

    test "can transition from dead to idle (resurrection)", %{state: state} do
      {:ok, dead_state} = PlayerState.transition_to(state, :dead)
      assert {:ok, idle_state} = PlayerState.transition_to(dead_state, :idle)
      assert idle_state.action_state == :idle
    end
  end

  describe "combat intent" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "set_combat_intent sets combat fields", %{state: state} do
      updated_state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})

      assert updated_state.combat_target_id == 12_345
      assert updated_state.combat_action_type == 0
      assert updated_state.last_target_position == {150, 150}
      assert updated_state.movement_intent == :combat
    end

    test "clear_combat_intent clears combat fields", %{state: state} do
      state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})
      cleared_state = PlayerState.clear_combat_intent(state)

      assert cleared_state.combat_target_id == nil
      assert cleared_state.combat_action_type == nil
      assert cleared_state.last_target_position == nil
      assert cleared_state.movement_intent == :none
    end

    test "clear_combat_intent preserves normal movement intent", %{state: state} do
      # Set to moving state
      state = %{state | movement_state: :moving}
      state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})

      cleared_state = PlayerState.clear_combat_intent(state)
      assert cleared_state.movement_intent == :normal
    end

    test "combat_moving? returns true for combat_moving state", %{state: state} do
      {:ok, combat_moving_state} = PlayerState.transition_to(state, :combat_moving)
      assert PlayerState.combat_moving?(combat_moving_state) == true
    end

    test "combat_moving? returns false for other states", %{state: state} do
      assert PlayerState.combat_moving?(state) == false

      {:ok, moving_state} = PlayerState.transition_to(state, :moving)
      assert PlayerState.combat_moving?(moving_state) == false
    end
  end

  describe "state transition validation" do
    test "can_transition? validates allowed transitions" do
      # From idle
      assert PlayerState.can_transition?(:idle, :moving) == true
      assert PlayerState.can_transition?(:idle, :combat_moving) == true
      assert PlayerState.can_transition?(:idle, :attacking) == true
      assert PlayerState.can_transition?(:idle, :sitting) == true

      # From moving
      assert PlayerState.can_transition?(:moving, :idle) == true
      assert PlayerState.can_transition?(:moving, :combat_moving) == true
      assert PlayerState.can_transition?(:moving, :attacking) == true

      # From combat_moving
      assert PlayerState.can_transition?(:combat_moving, :idle) == true
      assert PlayerState.can_transition?(:combat_moving, :attacking) == true
      assert PlayerState.can_transition?(:combat_moving, :moving) == true

      # From attacking
      assert PlayerState.can_transition?(:attacking, :idle) == true
      assert PlayerState.can_transition?(:attacking, :combat_moving) == true

      # Invalid transitions
      assert PlayerState.can_transition?(:sitting, :attacking) == false
      assert PlayerState.can_transition?(:dead, :moving) == false
      assert PlayerState.can_transition?(:trading, :attacking) == false

      # Special cases
      # Can always die
      assert PlayerState.can_transition?(:idle, :dead) == true
      # Resurrection
      assert PlayerState.can_transition?(:dead, :idle) == true
      # Same state
      assert PlayerState.can_transition?(:idle, :idle) == true
    end
  end

  describe "state entry handlers" do
    setup do
      character = %Character{
        id: 1,
        name: "TestPlayer",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0,
        account_id: 1
      }

      state = PlayerState.new(character)
      {:ok, %{state: state}}
    end

    test "transitioning to idle clears combat intent", %{state: state} do
      # Set combat intent
      state = PlayerState.set_combat_intent(state, 12_345, 0, {150, 150})
      {:ok, combat_state} = PlayerState.transition_to(state, :combat_moving)

      # Transition to idle should clear combat intent
      {:ok, idle_state} = PlayerState.transition_to(combat_state, :idle)

      assert idle_state.combat_target_id == nil
      assert idle_state.combat_action_type == nil
      assert idle_state.last_target_position == nil
    end

    test "transitioning to moving sets normal movement intent", %{state: state} do
      assert state.movement_intent == :none

      {:ok, moving_state} = PlayerState.transition_to(state, :moving)
      assert moving_state.movement_intent == :normal
    end

    test "transitioning to combat_moving sets combat movement intent", %{state: state} do
      {:ok, combat_moving_state} = PlayerState.transition_to(state, :combat_moving)
      assert combat_moving_state.movement_intent == :combat
    end
  end
end
