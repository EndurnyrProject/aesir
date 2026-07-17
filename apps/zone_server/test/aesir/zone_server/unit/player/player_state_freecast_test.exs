defmodule Aesir.ZoneServer.Unit.Player.PlayerStateFreecastTest do
  @moduledoc """
  The `casting` field's lifecycle once Free Cast makes a cast an overlay over
  walking and attacking, rather than an action state of its own.

  `Player.PlayerStateCastingFieldTest` pins the pre-Free-Cast lifecycle; these
  cover the transitions the overlay rides through, where the cast must survive.
  """
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    character = %Character{
      id: 1000,
      account_id: 2000,
      name: "FreecastTester",
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

    state = PlayerState.new(character)
    context = %{skill_id: 89, token: make_ref()}
    {:ok, casting_state} = PlayerState.transition_to(state, :casting, context)

    {:ok, state: state, casting_state: casting_state, context: context}
  end

  describe ":casting -> :moving" do
    test "is a permitted transition", %{casting_state: casting_state} do
      assert {:ok, %{action_state: :moving}} =
               PlayerState.transition_to(casting_state, :moving, %{})
    end

    test "keeps the cast in flight", %{casting_state: casting_state, context: context} do
      {:ok, moving_state} = PlayerState.transition_to(casting_state, :moving, %{})

      assert moving_state.casting == context
    end
  end

  describe "the cast survives the states the overlay rides through" do
    setup %{casting_state: casting_state} do
      {:ok, moving_state} = PlayerState.transition_to(casting_state, :moving, %{})
      {:ok, moving_state: moving_state}
    end

    test "arriving at the destination does not wipe a cast still in flight",
         %{moving_state: moving_state, context: context} do
      assert {:ok, arrived} = PlayerState.transition_to(moving_state, :idle)
      assert arrived.casting == context
    end

    test "attacking mid-walk does not wipe a cast still in flight",
         %{moving_state: moving_state, context: context} do
      assert {:ok, attacking} = PlayerState.transition_to(moving_state, :attacking, %{})
      assert attacking.casting == context
    end
  end

  describe "attacking while casting" do
    # Architecture 5.4 reaches `attacking_while_casting` only from
    # `moving_while_casting`: the cast stops owning `action_state` when the
    # caster walks, and that is what frees the attack. A standing cast still owns
    # it, so it still blocks attacking — for Free Cast knowers too.
    test "a standing cast blocks attacking, whoever the caster is",
         %{casting_state: casting_state} do
      assert PlayerState.transition_to(casting_state, :attacking, %{}) ==
               {:error, :invalid_transition}
    end

    test "a cast overlaid on a walker does not block attacking",
         %{casting_state: casting_state} do
      {:ok, moving_state} = PlayerState.transition_to(casting_state, :moving, %{})

      assert {:ok, %{action_state: :attacking}} =
               PlayerState.transition_to(moving_state, :attacking, %{})
    end
  end

  describe "clear_casting/1" do
    test "ends the cast regardless of the action state it is overlaid on",
         %{casting_state: casting_state} do
      {:ok, moving_state} = PlayerState.transition_to(casting_state, :moving, %{})

      assert PlayerState.clear_casting(moving_state).casting == nil
    end
  end

  describe "relocate/3" do
    test "a warp drops a cast in flight rather than carrying a dead timer across maps",
         %{casting_state: casting_state} do
      relocated = PlayerState.relocate(casting_state, "geffen", 120, 100)

      assert relocated.casting == nil
      assert relocated.action_state == :idle
    end
  end
end
