defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfistTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfist
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Cell)
    Mimic.copy(Combat)
    Mimic.copy(StatusInterpreter)
    :ok
  end

  @caster_id 7_000
  @target_id 8_000

  test "declares Asura's Renewal targeting, timing, and recovery" do
    {:ok, definition} = Catalog.by_id(271)

    assert definition.name == :mo_extremityfist
    assert definition.display_name == "Asura Strike"
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.max_level == 5
    assert definition.range == -2
    assert definition.status == :sc_extremityfist
    assert definition.sphere_cost == [5, 5, 5, 5, 5]
    assert definition.cast_time == [2_000, 1_750, 1_500, 1_250, 1_000]
    assert definition.fixed_cast_time == [2_000, 1_750, 1_500, 1_250, 1_000]
    assert definition.after_cast_delay == [3_000, 2_500, 2_000, 1_500, 1_000]
  end

  describe "dynamic_cost/4" do
    test "a normal cast drains every spirit point and requires five spheres" do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      assert %Cost{hp: 0, sp: 250, spheres: 5} =
               MoExtremityfist.dynamic_cost(
                 caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end

    test "a Root follow-up against the caught peer costs one fewer sphere" do
      link_pair(@caster_id, {:mob, @target_id}, 5)

      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      assert %Cost{sp: 250, spheres: 4} =
               MoExtremityfist.dynamic_cost(
                 caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end

    test "a combo follow-up consumes every held sphere, and at least one" do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      held = combo_caster(sp: 250, spheres: 3)

      assert %Cost{sp: 250, spheres: 3} =
               MoExtremityfist.dynamic_cost(held, {:unit, @target_id}, 5, definition())

      empty = combo_caster(sp: 250, spheres: 0)

      assert %Cost{sp: 250, spheres: 1} =
               MoExtremityfist.dynamic_cost(empty, {:unit, @target_id}, 5, definition())
    end
  end

  describe "validate/4" do
    test "rejects a non-unit target" do
      assert {:error, :invalid_target} =
               MoExtremityfist.validate(caster(sp: 100), {:ground, 5, 5}, 5, definition())
    end

    test "requires Fury to be active" do
      assert {:error, :requires_explosion_spirits} =
               MoExtremityfist.validate(caster(sp: 100), {:unit, @target_id}, 5, definition())
    end

    test "requires at least one spirit point" do
      apply_fury(@caster_id)

      assert {:error, :insufficient_sp} =
               MoExtremityfist.validate(caster(sp: 0), {:unit, @target_id}, 5, definition())
    end

    test "passes with Fury active and spirit points to spend" do
      apply_fury(@caster_id)

      assert :ok = MoExtremityfist.validate(caster(sp: 1), {:unit, @target_id}, 5, definition())
    end

    test "a rooted caster below Root level five is rejected outright" do
      apply_fury(@caster_id)
      link_pair(@caster_id, {:mob, @target_id}, 4)

      assert {:error, :insufficient_root_level} =
               MoExtremityfist.validate(caster(sp: 100), {:unit, @target_id}, 5, definition())
    end

    test "a rooted caster at Root level five passes the gate" do
      apply_fury(@caster_id)
      link_pair(@caster_id, {:mob, @target_id}, 5)

      assert :ok = MoExtremityfist.validate(caster(sp: 100), {:unit, @target_id}, 5, definition())
    end
  end

  describe "dynamic_cast_time/4" do
    test "a combo follow-up casts instantly" do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      assert %{cast_time: 0, fixed_cast_time: 0} =
               MoExtremityfist.dynamic_cast_time(
                 combo_caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end

    test "a normal cast keeps the definition's cast-time table" do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      assert %{cast_time: 1_000, fixed_cast_time: 1_000} =
               MoExtremityfist.dynamic_cast_time(
                 caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end
  end

  describe "cast/4" do
    test "deals pre-drain damage once, ends Fury/Root/combo, applies recovery, and stages the move" do
      stub(Cell, :traversable?, fn "prontera", 13, 10 -> true end)

      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      expect(Combat, :execute_skill_attack, fn _caster, @target_id, opts ->
        assert opts[:skill_id] == 271
        assert opts[:skill_level] == 5
        assert opts[:skill_ratio] == 3_300
        assert opts[:bonus_atk] == 1_000
        assert opts[:element] == :neutral
        assert opts[:hit_count] == 1
        assert opts[:skip_crit]
        :ok
      end)

      expect(StatusInterpreter, :remove_status, 2, fn :player, @caster_id, status ->
        assert status in [:sc_explosionspirits, :sc_bladestop]
        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_extremityfist,
                                                  params ->
        assert params[:val1] == 5
        assert params[:duration] == 3_000
        :ok
      end)

      caster = combo_caster(sp: 250, spheres: 5)

      assert {:ok, updated} = MoExtremityfist.cast(caster, {:unit, @target_id}, 5, definition())
      assert updated.combo.stage == :idle
      assert %ForcedMovement{map_name: "prontera", x: 13, y: 10} = updated.pending_forced_movement
      assert updated.x == 10 and updated.y == 10
    end

    test "an unwalkable destination still lands the strike but stages no movement" do
      stub(Cell, :traversable?, fn "prontera", 13, 10 -> false end)

      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      expect(Combat, :execute_skill_attack, fn _caster, @target_id, _opts -> :ok end)

      expect(StatusInterpreter, :remove_status, 2, fn :player, @caster_id, status ->
        assert status in [:sc_explosionspirits, :sc_bladestop]
        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_extremityfist,
                                                  _params ->
        :ok
      end)

      caster = combo_caster(sp: 250, spheres: 5)

      assert {:ok, updated} = MoExtremityfist.cast(caster, {:unit, @target_id}, 5, definition())
      assert updated.pending_forced_movement == nil
      assert updated.combo.stage == :idle
    end

    test "a rejected strike commits no status change or movement" do
      stub(Cell, :traversable?, fn "prontera", 13, 10 -> true end)

      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
        {:error, :dead_target}
      end)

      reject(&StatusInterpreter.apply_status/4)
      reject(&StatusInterpreter.remove_status/3)

      caster = caster(sp: 250, spheres: 5)

      assert {:error, :dead_target} =
               MoExtremityfist.cast(caster, {:unit, @target_id}, 5, definition())

      assert caster.pending_forced_movement == nil
    end
  end

  defp definition, do: MoExtremityfist.definition()

  defp caster(opts) do
    %PlayerState{
      character_id: @caster_id,
      map_name: "prontera",
      x: 10,
      y: 10,
      stats: %{current_state: %{sp: Keyword.get(opts, :sp, 100)}},
      spirit_spheres: spheres(Keyword.get(opts, :spheres, 0)),
      combo: Combo.new()
    }
  end

  defp combo_caster(opts) do
    caster = caster(opts)
    %{caster | combo: Combo.open(Combo.new(), :extremity, {:mob, @target_id}, future())}
  end

  defp spheres(0), do: SpiritSpheres.new()

  defp spheres(count) do
    Enum.reduce(1..count, SpiritSpheres.new(), fn _, acc ->
      {updated, _entry} = SpiritSpheres.summon(acc, future(), 5)
      updated
    end)
  end

  defp apply_fury(caster_id) do
    :ok = StatusStorage.apply_status(:player, caster_id, :sc_explosionspirits, duration: 180_000)
  end

  defp link_pair(monk_id, {caught_type, caught_id} = caught, monk_level) do
    link_id = make_ref()

    :ok =
      StatusStorage.apply_status(:player, monk_id, :sc_bladestop,
        state: %{peer: caught, link_id: link_id, root_level: monk_level}
      )

    :ok =
      StatusStorage.apply_status(caught_type, caught_id, :sc_bladestop,
        state: %{peer: {:player, monk_id}, link_id: link_id, root_level: 0}
      )
  end

  defp future, do: System.monotonic_time(:millisecond) + 600_000
end
