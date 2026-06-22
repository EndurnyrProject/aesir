defmodule Aesir.ZoneServer.Unit.MovementInterruptsTest do
  @moduledoc """
  Locks two interrupt behaviors under the snapshot netcode model
  (design Part 4.2 mid-path speed change, Part 4.4 chase stop-at-target):

    * A mid-path `walk_speed` change retimes the next cell from the live
      `walk_speed` without clearing or rebuilding `walk_path`.
    * A chasing mob stops at a cell within attack range of its target (it
      does not path onto the target's exact cell) and re-paths toward the
      target once it has moved out of attack range.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  setup :set_mimic_from_context

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.MovementEngine
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  @map_name "prontera"

  describe "mid-path speed change (player)" do
    test "stepping shortens walk_path by one cell and never rebuilds it" do
      walk_path = [{51, 50}, {52, 50}, {53, 50}]

      game_state = %{
        PlayerState.new(character())
        | walk_path: walk_path,
          movement_state: :moving,
          walk_speed: 150
      }

      char_id = game_state.character_id

      UnitRegistry.register_unit(:player, char_id, MovementHandler, game_state, nil)
      SpatialIndex.add_unit(:player, char_id, 50, 50, @map_name)

      {:noreply, stepped} = MovementHandler.handle_movement_tick(%{game_state: game_state})

      assert stepped.game_state.walk_path == tl(walk_path)
      assert {stepped.game_state.x, stepped.game_state.y} == {51, 50}
      assert stepped.game_state.movement_state == :moving
    end

    test "the stepper schedules the next cell from the live walk_speed, not a cached one" do
      # Capture the walk_speed the REAL stepper passes into step_delay when it
      # schedules the next :movement_tick, while still letting the real timer
      # value through. If the stepper cached walk_speed at path start instead of
      # reading it live, the captured speed (and interval) would not change
      # between the two steps below, and the assertions would fail.
      test_pid = self()

      stub(MovementEngine, :step_delay, fn walk_speed, from, to ->
        interval = call_original(MovementEngine, :step_delay, [walk_speed, from, to])
        send(test_pid, {:scheduled, walk_speed, interval})
        interval
      end)

      walk_path = [{51, 50}, {52, 50}, {53, 50}]
      slow_speed = 200
      fast_speed = 80

      slow_state = %{
        PlayerState.new(character())
        | walk_path: walk_path,
          movement_state: :moving,
          walk_speed: slow_speed
      }

      char_id = slow_state.character_id

      UnitRegistry.register_unit(:player, char_id, MovementHandler, slow_state, nil)
      SpatialIndex.add_unit(:player, char_id, 50, 50, @map_name)

      {:noreply, _stepped} = MovementHandler.handle_movement_tick(%{game_state: slow_state})

      cost = MovementEngine.get_movement_cost({50, 50}, {51, 50})

      assert_received {:scheduled, ^slow_speed, slow_interval}
      assert slow_interval == round(slow_speed * cost)

      # Speed changes mid-path (Agi Up, Quagmire, mount, etc). The path and
      # position are identical to the slow step; only the live walk_speed differs.
      # An equivalent step at a different live speed must reschedule differently.
      fast_state = %{slow_state | walk_speed: fast_speed}

      {:noreply, _stepped} = MovementHandler.handle_movement_tick(%{game_state: fast_state})

      assert_received {:scheduled, ^fast_speed, fast_interval}
      assert fast_interval == round(fast_speed * cost)

      assert slow_interval != fast_interval
    end
  end

  describe "chase stop-at-target (mob)" do
    test "a mob already in attack range switches to combat and does not path toward the target" do
      collector = start_move_collector()
      target_id = 5001

      SpatialIndex.add_unit(:player, target_id, 101, 100, @map_name)

      mob_state = %{
        chasing_mob_state(collector)
        | x: 100,
          y: 100,
          ai_state: :chase,
          target_id: target_id,
          movement_state: :standing,
          last_movement_end_time: nil
      }

      result = AIStateMachine.process_ai(mob_state)

      assert result.ai_state == :combat
      assert collected_moves() == []
    end

    test "after the target moves out of attack range the mob re-paths toward the target's new cell" do
      collector = start_move_collector()
      target_id = 5002

      mob_state = %{
        chasing_mob_state(collector)
        | x: 100,
          y: 100,
          ai_state: :chase,
          target_id: target_id,
          movement_state: :standing,
          last_movement_end_time: nil
      }

      # Target starts adjacent (in attack range): the mob stops and engages.
      SpatialIndex.add_unit(:player, target_id, 101, 100, @map_name)
      in_range = AIStateMachine.process_ai(mob_state)

      assert in_range.ai_state == :combat
      assert collected_moves() == []

      # Target flees out of attack range but stays within chase range: the
      # mob must re-path toward the target's new cell.
      SpatialIndex.update_position(target_id, 108, 100, @map_name)
      chasing = AIStateMachine.process_ai(%{mob_state | ai_state: :chase})

      assert chasing.ai_state == :chase
      assert collected_moves() == [{108, 100}]
    end
  end

  defp start_move_collector do
    test_pid = self()

    spawn_link(fn -> move_collector_loop(test_pid) end)
  end

  defp move_collector_loop(test_pid) do
    receive do
      {:"$gen_cast", {:move_to, x, y}} ->
        send(test_pid, {:move_to, x, y})
        move_collector_loop(test_pid)

      _ ->
        move_collector_loop(test_pid)
    end
  end

  defp collected_moves do
    collect_moves([])
  end

  defp collect_moves(acc) do
    receive do
      {:move_to, x, y} -> collect_moves([{x, y} | acc])
    after
      50 -> Enum.reverse(acc)
    end
  end

  defp chasing_mob_state(process_pid) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 3,
      hp: 60,
      sp: 0,
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 5,
      stats: %{str: 1, agi: 1, vit: 1, int: 0, dex: 6, luk: 30},
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 672,
      client_attack_motion: 500,
      damage_motion: 480,
      ai_type: 0,
      modes: [],
      drops: []
    }

    %MobState{
      instance_id: 42,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: nil,
      process_pid: process_pid,
      map_name: @map_name,
      x: 100,
      y: 100,
      dir: 0,
      hp: mob_data.hp,
      max_hp: mob_data.hp,
      sp: 0,
      max_sp: 0,
      spawned_at: System.system_time(:second),
      walk_speed: mob_data.walk_speed,
      view_range: 12,
      is_dead: false
    }
  end

  defp character do
    %Character{
      id: 1001,
      account_id: 100,
      name: "Mover",
      last_map: @map_name,
      last_x: 50,
      last_y: 50,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }
  end
end
