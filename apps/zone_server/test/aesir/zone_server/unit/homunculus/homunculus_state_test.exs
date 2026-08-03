defmodule Aesir.ZoneServer.Unit.Homunculus.HomunculusStateTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime
  alias Aesir.ZoneServer.Unit.Homunculus.StateCommit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  test "exposes active Homunculus state through every Unit callback" do
    state = homunculus()

    assert HomunculusState.get_unit_id(state) == 70_001
    assert HomunculusState.get_unit_type(state) == :homunculus
    assert HomunculusState.get_process_pid(state) == self()
    assert HomunculusState.get_race(state) == :demi_human
    assert HomunculusState.get_element(state) == {:neutral, 1}
    assert HomunculusState.get_size(state) == :medium
    refute HomunculusState.is_boss?(state)
    assert HomunculusState.get_custom_immunities(state) == []

    assert %{str: 30, agi: 25, vit: 20, int: 15, dex: 35, luk: 10, hp: 950, max_hp: 1_000} =
             HomunculusState.get_stats(state)

    assert Unit.living?(state)
    refute Unit.corpse?(state)

    assert %{
             entity_type: :homunculus,
             unit_id: 70_001,
             unit_type: :homunculus,
             stats: %{hp: 950, max_hp: 1_000, sp: 150, max_sp: 200}
           } = HomunculusState.get_entity_info(state)
  end

  test "uses owner roots and Combatant relationship defaults" do
    assert %Combatant{
             unit_id: 70_001,
             unit_type: :homunculus,
             social_root: {:player, 42},
             reward_root: {:player, 42},
             party_id: 0,
             guild_id: 0,
             base_stats: %{str: 30, agi: 25, vit: 20, int: 15, dex: 35, luk: 10},
             position: {100, 120},
             map_name: "prontera"
           } = HomunculusState.to_combatant(homunculus())
  end

  test "fails closed for inconsistent lifecycle, action, and HP snapshots" do
    assert not Unit.living?(%{homunculus() | lifecycle: :rested, world_gid: nil})
    assert not Unit.living?(%{homunculus() | action_state: :dead})
    assert not Unit.living?(%{homunculus() | hp: 0})

    assert Unit.corpse?(%{homunculus() | lifecycle: :dead, action_state: :dead, hp: 0})
    assert not Unit.corpse?(%{homunculus() | lifecycle: :dead, hp: 0})
    assert not Unit.corpse?(%{homunculus() | lifecycle: :dead, action_state: :dead, hp: 1})
    assert not Unit.corpse?(%{homunculus() | action_state: :dead, hp: 0})
  end

  test "session defaults to no companion and fresh runtime bookkeeping" do
    session = %SessionState{game_state: %PlayerState{character_id: 42}, connection_pid: self()}

    assert session.homunculus == nil

    assert %Runtime{
             active_expiry_timer_ref: nil,
             hunger_timer_ref: nil,
             ai_timer_ref: nil,
             cast_timer_ref: nil,
             movement_timer_ref: nil,
             checkpoint_timer_ref: nil,
             separation_timer_ref: nil,
             cooldown_timer_ref: nil,
             movement_path: [],
             private_dirty: false
           } = session.homunculus_runtime
  end

  test "StateCommit is the nested Homunculus replacement path" do
    session = %SessionState{game_state: %PlayerState{character_id: 42}, connection_pid: self()}
    homunculus = homunculus()

    assert %SessionState{
             homunculus: ^homunculus,
             homunculus_runtime: %Runtime{private_dirty: true}
           } = StateCommit.commit(session, homunculus)
  end

  test "StateCommit deletes the nested Homunculus and marks the private view dirty" do
    session = %SessionState{
      game_state: %PlayerState{character_id: 42},
      connection_pid: self(),
      homunculus: homunculus()
    }

    assert %SessionState{
             homunculus: nil,
             homunculus_runtime: %Runtime{private_dirty: true}
           } = StateCommit.commit(session, nil)
  end

  defp homunculus do
    %HomunculusState{
      id: 123,
      owner_character_id: 42,
      owner_session_pid: self(),
      class_id: 6_001,
      name: "Lif",
      lifecycle: :active,
      level: 50,
      exp: 1_000,
      skill_points: 3,
      hp: 950,
      max_hp: 1_000,
      sp: 150,
      max_sp: 200,
      str: 30,
      agi: 25,
      vit: 20,
      int: 15,
      dex: 35,
      luk: 10,
      hunger: 80,
      intimacy_hundredths: 9_500,
      active_remaining_ms: 1_000_000,
      learned_skills: %{8001 => 3},
      cooldowns: %{},
      ai_config: %{},
      world_gid: 70_001,
      map_name: "prontera",
      x: 100,
      y: 120,
      dir: 4,
      action_state: :idle,
      movement_state: :standing,
      target: {:mob, 2_001},
      casting: nil,
      race: :demi_human,
      element: {:neutral, 1},
      size: :medium,
      attack_range: 1,
      attack_delay_ms: 500,
      combat_stats: %{
        atk: 100,
        def: 50,
        hit: 175,
        flee: 120,
        perfect_dodge: 5,
        matk: 80,
        matk_min: 70,
        matk_max: 90,
        mdef: 30,
        soft_mdef: 15
      }
    }
  end
end
