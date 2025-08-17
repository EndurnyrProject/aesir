defmodule Aesir.ZoneServer.Unit.Player.PlayerStateTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.JobData
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup_all do
    JobData.init()
    :ok
  end

  describe "new/1" do
    test "creates PlayerState from Character with stats initialized" do
      character = %Character{
        id: 12_345,
        name: "TestPlayer",
        account_id: 67_890,
        last_map: "prontera",
        last_x: 155,
        last_y: 183,
        str: 25,
        agi: 30,
        vit: 35,
        int: 40,
        dex: 20,
        luk: 15,
        base_level: 60,
        job_level: 40,
        base_exp: 2000,
        job_exp: 1500,
        hp: 1200,
        sp: 800
      }

      state = PlayerState.new(character)

      # Position and map should be from character
      assert state.map_name == "prontera"
      assert state.x == 155
      assert state.y == 183
      assert state.dir == 0

      # Movement defaults
      assert state.walk_path == []
      assert state.walk_speed == 150
      assert state.is_walking == false

      # Visibility defaults
      assert state.view_range == 14
      assert state.subscribed_cells == []

      # State defaults
      assert state.is_sitting == false
      assert state.is_dead == false
      assert state.target_id == nil
      assert state.is_trading == false
      assert state.is_vending == false
      assert state.is_chatting == false

      # Stats should be initialized from character
      assert %Stats{} = state.stats
      assert state.stats.base_stats.str == 25
      assert state.stats.base_stats.agi == 30
      assert state.stats.base_stats.vit == 35
      assert state.stats.base_stats.int == 40
      assert state.stats.base_stats.dex == 20
      assert state.stats.base_stats.luk == 15

      assert state.stats.progression.base_level == 60
      assert state.stats.progression.job_level == 40
      assert state.stats.progression.base_exp == 2000
      assert state.stats.progression.job_exp == 1500

      assert state.stats.current_state.hp == 1200
      assert state.stats.current_state.sp == 800

      # Derived stats should be calculated
      assert state.stats.derived_stats.max_hp > 0
      assert state.stats.derived_stats.max_sp > 0
    end

    test "works with minimal character data" do
      character = %Character{
        id: 1,
        name: "MinChar",
        account_id: 1,
        last_map: "novice",
        last_x: 50,
        last_y: 50,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 1,
        job_level: 1,
        base_exp: 0,
        job_exp: 0,
        hp: 40,
        sp: 11
      }

      state = PlayerState.new(character)

      assert state.map_name == "novice"
      assert state.x == 50
      assert state.y == 50
      assert %Stats{} = state.stats
      assert state.stats.base_stats.str == 1
      assert state.stats.progression.base_level == 1
      assert state.stats.current_state.hp == 40
      assert state.stats.current_state.sp == 11
    end
  end

  describe "update_position/3" do
    test "updates x and y coordinates" do
      character = %Character{
        last_map: "payon",
        last_x: 100,
        last_y: 100,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      }

      state = PlayerState.new(character)
      updated_state = PlayerState.update_position(state, 200, 150)

      assert updated_state.x == 200
      assert updated_state.y == 150
      # Should remain unchanged
      assert updated_state.map_name == "payon"

      # Stats should remain unchanged
      assert updated_state.stats == state.stats
    end
  end

  describe "set_path/2" do
    test "sets walking path and starts walking" do
      character = %Character{
        last_map: "geffen",
        last_x: 120,
        last_y: 120,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      }

      state = PlayerState.new(character)
      path = [{125, 120}, {130, 120}, {135, 125}]
      updated_state = PlayerState.set_path(state, path)

      assert updated_state.walk_path == path
      assert updated_state.is_walking == true

      # Stats should remain unchanged
      assert updated_state.stats == state.stats
    end

    test "sets empty path and stops walking" do
      character = %Character{
        last_map: "geffen",
        last_x: 120,
        last_y: 120,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      }

      state = PlayerState.new(character)
      updated_state = PlayerState.set_path(state, [])

      assert updated_state.walk_path == []
      assert updated_state.is_walking == false
    end
  end

  describe "stop_walking/1" do
    test "clears path and stops walking" do
      character = %Character{
        last_map: "morocc",
        last_x: 160,
        last_y: 100,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      }

      state = PlayerState.new(character)
      walking_state = %{state | walk_path: [{165, 100}, {170, 105}], is_walking: true}
      stopped_state = PlayerState.stop_walking(walking_state)

      assert stopped_state.walk_path == []
      assert stopped_state.is_walking == false

      # Stats should remain unchanged
      assert stopped_state.stats == state.stats
    end
  end

  describe "update_direction/2" do
    test "updates direction with valid values" do
      character = %Character{
        last_map: "alberta",
        last_x: 100,
        last_y: 100,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      }

      state = PlayerState.new(character)

      for direction <- 0..7 do
        updated_state = PlayerState.update_direction(state, direction)
        assert updated_state.dir == direction

        # Stats should remain unchanged
        assert updated_state.stats == state.stats
      end
    end
  end

  describe "stats integration" do
    test "stats are properly initialized and remain consistent during state changes" do
      character = %Character{
        last_map: "aldebaran",
        last_x: 140,
        last_y: 130,
        str: 45,
        agi: 50,
        vit: 55,
        int: 60,
        dex: 35,
        luk: 25,
        base_level: 85,
        job_level: 50,
        base_exp: 5000,
        job_exp: 3000,
        hp: 2500,
        sp: 1800
      }

      initial_state = PlayerState.new(character)

      # Verify stats are properly calculated
      assert initial_state.stats.base_stats.str == 45
      assert initial_state.stats.base_stats.agi == 50
      assert initial_state.stats.base_stats.vit == 55
      assert initial_state.stats.base_stats.int == 60
      assert initial_state.stats.base_stats.dex == 35
      assert initial_state.stats.base_stats.luk == 25

      assert initial_state.stats.progression.base_level == 85
      assert initial_state.stats.progression.job_level == 50

      # Check derived stats are calculated correctly
      # JobData.get_base_hp(0, 85) = 460
      # Job bonuses at level 50 add +1 to all stats, so VIT 55 -> 56
      # 460 * 1.56 = 717.6 -> 717
      assert initial_state.stats.derived_stats.max_hp == 717

      # Novice SP is 11 at all levels
      # Job bonuses at level 50 add +1 to all stats, so INT 60 -> 61
      # 11 * 1.61 = 17.71 -> 17
      assert initial_state.stats.derived_stats.max_sp == 17

      # Test that position changes don't affect stats
      moved_state = PlayerState.update_position(initial_state, 200, 200)
      assert moved_state.stats == initial_state.stats

      # Test that walking changes don't affect stats
      walking_state = PlayerState.set_path(moved_state, [{205, 200}, {210, 205}])
      assert walking_state.stats == initial_state.stats

      # Test that direction changes don't affect stats
      directed_state = PlayerState.update_direction(walking_state, 3)
      assert directed_state.stats == initial_state.stats
    end
  end
end
