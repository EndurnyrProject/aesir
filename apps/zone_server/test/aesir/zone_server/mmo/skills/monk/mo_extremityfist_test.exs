defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfistTest do
  use ExUnit.Case, async: false

  import Mimic
  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Combo
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoExtremityfist
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
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

  @tag game_mode: :renewal
  test "declares Asura's Renewal targeting, timing, and recovery" do
    {:ok, definition} = Catalog.by_id(271)

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
    test "a normal cast costs its listed SP, requires five spheres and records those held" do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      assert %Cost{hp: 0, sp: 1, spheres: 5, spheres_old: 5} =
               MoExtremityfist.dynamic_cost(
                 caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end

    test "a Root follow-up against the caught peer costs one fewer sphere and records none" do
      link_pair(@caster_id, {:mob, @target_id}, 5)
      stub(ModifierCalculator, :get_all_modifiers, fn :player, @caster_id -> %{} end)

      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      assert %Cost{sp: 1, spheres: 4, spheres_old: nil} =
               MoExtremityfist.dynamic_cost(
                 caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end

    @tag game_mode: :renewal
    test "a combo follow-up consumes every held sphere, and at least one" do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      held = combo_caster(sp: 250, spheres: 3)

      assert %Cost{sp: 1, spheres: 3, spheres_old: 3} =
               MoExtremityfist.dynamic_cost(held, {:unit, @target_id}, 5, definition())

      empty = combo_caster(sp: 250, spheres: 0)

      assert %Cost{sp: 1, spheres: 1, spheres_old: 0} =
               MoExtremityfist.dynamic_cost(empty, {:unit, @target_id}, 5, definition())
    end
  end

  describe "validate/4" do
    test "rejects a non-unit target" do
      assert {:error, :invalid_target} =
               MoExtremityfist.validate(caster(sp: 100), {:ground, 5, 5}, 5, definition())
    end

    test "requires Fury to be active when the cast begins" do
      assert {:error, :requires_explosion_spirits} =
               MoExtremityfist.begin_attempt(
                 caster(sp: 100),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end

    test "requires one spirit point, the SP the cast begin checks" do
      assert %{sp_requirement: 1} =
               MoExtremityfist.dynamic_cost(caster(sp: 0), {:unit, @target_id}, 5, definition())
    end

    test "passes with Fury active and spirit points to spend" do
      apply_fury(@caster_id)

      assert {:ok, _caster} =
               MoExtremityfist.begin_attempt(caster(sp: 1), {:unit, @target_id}, 5, definition())

      assert :ok = MoExtremityfist.validate(caster(sp: 1), {:unit, @target_id}, 5, definition())
    end

    test "a rooted caster below Root level five is refused silently and at the cast end" do
      apply_fury(@caster_id)
      link_pair(@caster_id, {:mob, @target_id}, 4)

      assert {:error, :caster_restricted} =
               MoExtremityfist.skilluse_check(
                 caster(sp: 100),
                 {:unit, @target_id},
                 5,
                 definition()
               )

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

      expected =
        mode_value(%{cast_time: 1_000, fixed_cast_time: 1_000}, %{
          cast_time: 2_000,
          fixed_cast_time: 0
        })

      assert ^expected =
               MoExtremityfist.dynamic_cast_time(
                 caster(sp: 250, spheres: 5),
                 {:unit, @target_id},
                 5,
                 definition()
               )
    end
  end

  describe "after Chain Crush" do
    setup do
      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      :ok
    end

    test "Asura casts instantly and spends every held sphere, at least one" do
      held = window_caster(:chain_crush, sp: 250, spheres: 3)

      assert %Cost{spheres: 3} =
               MoExtremityfist.dynamic_cost(held, {:unit, @target_id}, 5, definition())

      assert %{cast_time: 0, fixed_cast_time: 0} =
               MoExtremityfist.dynamic_cast_time(held, {:unit, @target_id}, 5, definition())

      empty = window_caster(:chain_crush, sp: 250, spheres: 0)

      assert %Cost{spheres: 1} =
               MoExtremityfist.dynamic_cost(empty, {:unit, @target_id}, 5, definition())
    end

    test "a Glacier Fist window is not an Asura window" do
      caster = window_caster(:tiger_fist, sp: 250, spheres: 5)

      assert %Cost{spheres: 5} =
               MoExtremityfist.dynamic_cost(caster, {:unit, @target_id}, 5, definition())

      refute MoExtremityfist.dynamic_cast_time(caster, {:unit, @target_id}, 5, definition()) ==
               %{cast_time: 0, fixed_cast_time: 0}
    end
  end

  describe "cast/4" do
    @tag game_mode: :renewal
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
        assert opts[:skip_crit]
        assert opts[:ignore_flee]
        assert opts[:simple_defense]
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

  defp window_caster(stage, opts) do
    caster = caster(opts)
    %{caster | combo: Combo.open(Combo.new(), stage, {:mob, @target_id}, future())}
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

  @tag game_mode: :pre_renewal
  test "classic carries the source's data" do
    {:ok, definition} = Catalog.by_id(271)
    assert definition.cast_time == [4_000, 3_500, 3_000, 2_500, 2_000]
    assert definition.fixed_cast_time == []
    assert definition.after_cast_delay == [3_000, 2_500, 2_000, 1_500, 1_000]
  end

  @tag game_mode: :pre_renewal
  test "classic combo follow-up costs four spheres" do
    stub(Combat, :resolve_target_position, fn @target_id ->
      {:ok, :mob, {12, 10, "prontera"}}
    end)

    held = combo_caster(sp: 250, spheres: 5)

    assert %Cost{sp: 1, spheres: 4, spheres_old: 5} =
             MoExtremityfist.dynamic_cost(held, {:unit, @target_id}, 5, definition())
  end

  @tag game_mode: :pre_renewal
  test "classic strike is neutral element and halts SP regeneration for five minutes" do
    stub(Cell, :traversable?, fn "prontera", 13, 10 -> true end)

    stub(Combat, :resolve_target_position, fn @target_id ->
      {:ok, :mob, {12, 10, "prontera"}}
    end)

    expect(Combat, :execute_skill_attack, fn _caster, @target_id, opts ->
      assert opts[:skill_ratio] == 3_300
      assert opts[:bonus_atk] == 1_000
      assert opts[:element] == :neutral
      refute Keyword.has_key?(opts, :simple_defense)
      assert opts[:ignore_defense]
      :ok
    end)

    stub(StatusInterpreter, :remove_status, fn :player, @caster_id, _status -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_extremityfist, params ->
      assert params[:duration] == 300_000
      :ok
    end)

    caster = combo_caster(sp: 250, spheres: 5)
    assert {:ok, _updated} = MoExtremityfist.cast(caster, {:unit, @target_id}, 5, definition())
  end

  defp mode_value(renewal, pre_renewal),
    do: %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]

  describe "requirement timing" do
    setup do
      stub(Cell, :traversable?, fn "prontera", 13, 10 -> true end)

      stub(Combat, :resolve_target_position, fn @target_id ->
        {:ok, :mob, {12, 10, "prontera"}}
      end)

      :ok
    end

    test "the strike reads the SP left after its cost and the recorded spheres, then empties the pool" do
      stub(StatusInterpreter, :remove_status, fn :player, @caster_id, _status -> :ok end)

      stub(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_extremityfist, _ ->
        :ok
      end)

      expect(Combat, :execute_skill_attack, fn _caster, @target_id, opts ->
        assert opts[:skill_ratio] == 800 + 249 * 10
        assert opts[:spirit_spheres] == 5
        :ok
      end)

      paid = %{combo_caster(sp: 249, spheres: 0) | spirit_spheres_old: 5}

      assert {:ok, updated} = MoExtremityfist.cast(paid, {:unit, @target_id}, 5, definition())
      assert updated.stats.current_state.sp == 0
    end

    test "the cost is the listed SP and records the spheres held, except as a Root follow-up" do
      cost =
        MoExtremityfist.dynamic_cost(
          caster(sp: 250, spheres: 5),
          {:unit, @target_id},
          5,
          definition()
        )

      assert %Cost{sp: 1, sp_requirement: 1, spheres: 5, spheres_old: 5} = cost
    end

    test "a refused cast end spends the requirement, empties SP, ends Fury and Root and lunges" do
      expect(StatusInterpreter, :remove_status, 2, fn :player, @caster_id, status ->
        assert status in [:sc_explosionspirits, :sc_bladestop]
        :ok
      end)

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_extremityfist,
                                                  params ->
        assert params[:val1] == 5
        :ok
      end)

      monk = %{real_caster(sp: 250, spheres: 5) | act_delay_until: 99_999}

      assert {:ok, failed} =
               MoExtremityfist.castend_failed(monk, {:unit, @target_id}, 5, definition())

      assert failed.stats.current_state.sp == 0
      assert SpiritSpheres.count(failed.spirit_spheres) == 0
      assert failed.act_delay_until == 0
      assert %ForcedMovement{map_name: "prontera", x: 13, y: 10} = failed.pending_forced_movement
    end

    test "a Monk in a Fog Wall fails without the reaction" do
      reject(&StatusInterpreter.apply_status/4)
      monk = real_caster(sp: 250, spheres: 5)
      :ok = StatusStorage.apply_status(:player, @caster_id, :sc_fogwall, duration: 10_000)

      assert :none = MoExtremityfist.castend_failed(monk, {:unit, @target_id}, 5, definition())
    end
  end

  defp real_caster(opts) do
    base =
      PlayerState.new(%Aesir.Commons.Models.Character{
        id: @caster_id,
        account_id: @caster_id,
        name: "Monk",
        last_map: "prontera",
        last_x: 10,
        last_y: 10,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 90,
        job_level: 50,
        class: 15
      })

    paid = put_in(base.stats.current_state.sp, Keyword.fetch!(opts, :sp))
    %{paid | spirit_spheres: spheres(Keyword.fetch!(opts, :spheres))}
  end
end
