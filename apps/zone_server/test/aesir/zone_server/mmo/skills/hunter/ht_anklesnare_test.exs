defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnareTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_runtime_tables

  @player_id 10_001
  @mob_id 20_001
  @map "prontera"
  @cell {50, 50}

  describe "definition and duration" do
    test "capture duration scales with level, target AGI, and caster level" do
      assert Enum.map(1..5, &HtAnklesnare.capture_duration(&1, 0, 1)) ==
               [4_000, 8_000, 12_000, 16_000, 20_000]

      assert HtAnklesnare.capture_duration(5, 100, 50) == 10_000
      assert HtAnklesnare.capture_duration(1, 200, 50) == 4_500
    end

    test "a status-immune target is held for a fifth of the base time" do
      assert HtAnklesnare.capture_duration(5, 0, 1, true) == 4_000
      assert HtAnklesnare.capture_duration(5, 100, 1, true) == 3_030
    end
  end

  describe "placement and capture" do
    @tag game_mode: :renewal
    test "places one hidden armed cell with paid natural return metadata" do
      register_player(@player_id, base_level: 50)

      placed = %{
        group(:player, @player_id, level: 3)
        | state: %{cast_origin: :normal, paid_return?: true}
      }

      assert {:ok, placement} = HtAnklesnare.on_place(placed)
      assert placement.cells == [{50, 50}]
      assert placement.visibility == :party_only
      assert placement.duration == 150_000
      assert placement.unit_range == 1
      assert placement.state.ignore_land_protector

      assert %{__struct__: TrapState, phase: :armed, return_item_on_expiry?: true} =
               placement.state.trap
    end

    test "a player-owned snare catches a monster, holds it, and pulls it onto the snare" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, level: 20, agi: 100)
      expect(Knockback, :pull_to, fn :mob, @mob_id, 50, 50, [blown_immunity: true] -> :ok end)
      armed = group(:player, @player_id, level: 5)
      now = System.monotonic_time(:millisecond)

      assert [{:mob, @mob_id}] = HtAnklesnare.unit_targets(armed, @cell, [{:mob, @mob_id}])
      assert {:ok, captured} = HtAnklesnare.on_unit_hit(armed, @cell, {:mob, @mob_id}, now)

      assert %Group{
               visibility: :public,
               state: %{caught: {:mob, @mob_id}, trap: %TrapState{phase: :captured}}
             } = captured

      assert captured.expires_at > now + 9_000 and captured.expires_at <= now + 10_000

      assert %{val1: 5, val2: 1} = StatusStorage.get_status(:mob, @mob_id, :sc_ankle)
    end

    test "a catch never lasts past the snare's own lifetime" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, level: 20, agi: 0)
      stub(Knockback, :pull_to, fn _type, _id, _x, _y, _opts -> :ok end)
      now = System.monotonic_time(:millisecond)
      armed = %{group(:player, @player_id, level: 5) | expires_at: now + 2_000}

      assert {:ok, %Group{expires_at: expires_at, state: %{trap: %TrapState{phase: :captured}}}} =
               HtAnklesnare.on_unit_hit(armed, @cell, {:mob, @mob_id}, now)

      assert expires_at == now + 2_000
    end

    test "a hold that cannot start spends the snare, public, for 3 seconds at most" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, level: 20, agi: 0)

      expect(Interpreter, :apply_status, fn :mob, @mob_id, :sc_ankle, _opts ->
        {:error, :blocked}
      end)

      reject(&Knockback.pull_to/5)

      armed = %{group(:player, @player_id, level: 5) | expires_at: 260_000}

      assert {:ok, %Group{visibility: :public, expires_at: 13_000, state: state}} =
               HtAnklesnare.on_unit_hit(armed, @cell, {:mob, @mob_id}, 10_000)

      assert %TrapState{phase: :spent} = state.trap
      refute Map.has_key?(state, :caught)

      expect(Interpreter, :apply_status, fn :mob, @mob_id, :sc_ankle, _opts ->
        {:error, :blocked}
      end)

      short = %{armed | expires_at: 11_000}

      assert {:ok, %Group{expires_at: 11_000}} =
               HtAnklesnare.on_unit_hit(short, @cell, {:mob, @mob_id}, 10_000)
    end

    test "a stronger hold already held is kept and the snare lasts as long as it" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, level: 20, agi: 0)
      stub(Knockback, :pull_to, fn _type, _id, _x, _y, _opts -> :ok end)

      :ok =
        Interpreter.apply_status(:mob, @mob_id, :sc_ankle,
          val1: 10,
          val2: 99,
          duration: 40_000,
          caster_id: 1
        )

      now = System.monotonic_time(:millisecond)

      assert {:ok, %Group{expires_at: expires_at, state: %{trap: %TrapState{phase: :captured}}}} =
               HtAnklesnare.on_unit_hit(
                 group(:player, @player_id, level: 1),
                 @cell,
                 {:mob, @mob_id},
                 now
               )

      assert expires_at > now + 39_000 and expires_at <= now + 40_000
      assert %{val1: 10, val2: 99} = StatusStorage.get_status(:mob, @mob_id, :sc_ankle)
    end

    test "the snare ending removes its target's hold, whoever applied it" do
      register_mob(@mob_id, level: 20, agi: 0)

      :ok =
        Interpreter.apply_status(:mob, @mob_id, :sc_ankle,
          val1: 10,
          val2: 99,
          duration: 40_000,
          caster_id: 1
        )

      captured = %{group(:player, @player_id) | state: %{caught: {:mob, @mob_id}}}

      assert :ok = HtAnklesnare.on_expire(captured)
      refute StatusStorage.has_status?(:mob, @mob_id, :sc_ankle)
    end

    test "a mob-owned snare captures a player and ignores same-side contacts" do
      register_mob(@mob_id, level: 80, agi: 30)
      register_player(@player_id, base_level: 50, agi: 100)
      register_mob(@mob_id + 1, level: 20, agi: 0)
      stub(Knockback, :pull_to, fn _type, _id, _x, _y, _opts -> :ok end)

      mob_group = group(:mob, @mob_id, level: 1)

      assert [{:player, @player_id}] ==
               HtAnklesnare.unit_targets(mob_group, @cell, [
                 {:player, @player_id},
                 {:mob, @mob_id + 1}
               ])

      assert {:ok, captured} =
               HtAnklesnare.on_unit_hit(mob_group, @cell, {:player, @player_id}, 10_000)

      assert captured.state.caught == {:player, @player_id}
      assert StatusStorage.has_status?(:player, @player_id, :sc_ankle)
    end

    @tag game_mode: :renewal
    test "bosses and status-immune monsters do not set it off" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, modes: [:status_immune])
      register_mob(@mob_id + 1, modes: [:boss])
      register_mob(@mob_id + 2)
      armed = group(:player, @player_id, level: 5)

      assert [{:mob, 20_003}] =
               HtAnklesnare.unit_targets(armed, @cell, [
                 {:mob, @mob_id},
                 {:mob, @mob_id + 1},
                 {:mob, @mob_id + 2}
               ])
    end

    @tag game_mode: :pre_renewal
    test "a pre-renewal boss is caught for a fifth of the base time" do
      register_player(@player_id, base_level: 1)
      register_mob(@mob_id, agi: 0, modes: [:boss])
      stub(Knockback, :pull_to, fn _type, _id, _x, _y, _opts -> :ok end)
      armed = group(:player, @player_id, level: 5)
      now = System.monotonic_time(:millisecond)

      assert [{:mob, @mob_id}] = HtAnklesnare.unit_targets(armed, @cell, [{:mob, @mob_id}])
      assert {:ok, captured} = HtAnklesnare.on_unit_hit(armed, @cell, {:mob, @mob_id}, now)

      assert captured.expires_at > now + 3_000 and captured.expires_at <= now + 4_000
    end

    test "a missing target leaves the armed trap unchanged" do
      register_player(@player_id, base_level: 50)
      armed = group(:player, @player_id)

      assert {:ok, ^armed} = HtAnklesnare.on_unit_hit(armed, @cell, {:mob, @mob_id}, 10_000)
    end
  end

  defp setup_runtime_tables(context) do
    apply(Elixir.Aesir.TestEtsSetup, :setup_ets_tables, [context])
  end

  defp group(caster_type, caster_id, opts \\ []) do
    %Group{
      group_id: 1,
      skill_id: 117,
      skill_name: :ht_anklesnare,
      level: Keyword.get(opts, :level, 1),
      caster_id: caster_id,
      caster_type: caster_type,
      map_name: @map,
      center: {50, 50},
      cells: [{50, 50}],
      next_tick_at: 0,
      expires_at: System.monotonic_time(:millisecond) + 250_000,
      interval: 1_000,
      visibility: :party_only,
      state: %{trap: %TrapState{reclaim_item_id: 1065}}
    }
  end

  defp register_player(id, opts) do
    state =
      %Character{
        id: id,
        account_id: id,
        name: "Ankle#{id}",
        last_map: @map,
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: Keyword.get(opts, :agi, 1),
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: Keyword.fetch!(opts, :base_level),
        job_level: 1,
        class: 0
      }
      |> PlayerState.new()

    :ok = UnitRegistry.register_player(state, self())
    :ok = SpatialIndex.add_unit(:player, id, 50, 50, @map)
    state
  end

  defp register_mob(id, opts \\ []) do
    level = Keyword.get(opts, :level, 20)
    agi = Keyword.get(opts, :agi, 20)

    definition =
      %MobDefinition{
        id: 1002,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: level,
        hp: 1_000,
        sp: 50,
        atk: 10,
        matk: 0,
        def: 5,
        mdef: 3,
        stats: %{str: 10, agi: agi, vit: 10, int: 5, dex: 10, luk: 5},
        attack_range: 1,
        element: {:neutral, 1},
        race: :formless,
        size: :medium,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 400,
        modes: Keyword.get(opts, :modes, []),
        drops: []
      }

    spawn =
      %MobSpawn{
        mob: definition.id,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50}
      }

    state = MobState.new(id, definition, spawn, @map, 50, 50)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, 50, 50, @map)
    state
  end
end
