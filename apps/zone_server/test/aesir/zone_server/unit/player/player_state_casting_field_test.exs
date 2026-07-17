defmodule Aesir.ZoneServer.Unit.Player.PlayerStateCastingFieldTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    character = %Character{
      id: 1000,
      account_id: 2000,
      name: "CastFieldTester",
      class: 0,
      base_level: 1,
      job_level: 1,
      zeny: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      hp: 40,
      max_hp: 40,
      sp: 11,
      max_sp: 11,
      status_point: 0,
      skill_point: 0,
      last_map: "prontera",
      last_x: 150,
      last_y: 150
    }

    {:ok, state: PlayerState.new(character)}
  end

  test "a fresh state has no cast in flight", %{state: state} do
    assert state.casting == nil
  end

  test "entering :casting stores the descriptor in the casting field", %{state: state} do
    context = %{skill_id: 29, token: make_ref()}

    assert {:ok, casting_state} = PlayerState.transition_to(state, :casting, context)
    assert casting_state.casting == context
  end

  test "leaving :casting clears the casting field", %{state: state} do
    context = %{skill_id: 29, token: make_ref()}
    {:ok, casting_state} = PlayerState.transition_to(state, :casting, context)

    assert {:ok, idle_state} = PlayerState.transition_to(casting_state, :idle)
    assert idle_state.casting == nil

    assert {:ok, dead_state} = PlayerState.transition_to(casting_state, :dead)
    assert dead_state.casting == nil
  end

  test "transitions to non-casting states never populate the casting field", %{state: state} do
    assert {:ok, moving_state} = PlayerState.transition_to(state, :moving, %{some: :context})
    assert moving_state.casting == nil
  end
end
