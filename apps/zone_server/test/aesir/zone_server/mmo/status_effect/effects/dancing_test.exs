defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DancingTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Dancing
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  test "upkeep pays on every fifth tick and ends when payment fails" do
    player = player(17)
    :ok = UnitRegistry.register_player(player, self())
    test_pid = self()

    stub(PlayerSession, :try_consume_sp, fn _pid, 1 ->
      send(test_pid, :paid)
      :ok
    end)

    entry = %StatusEntry{type: :sc_dancing, state: %{upkeep: 5, ticks: 0}}

    updated =
      Enum.reduce(1..4, entry, fn _, current ->
        assert {:ok, next} = Dancing.on_tick({:player, 17}, current, %{})
        refute_received :paid
        next
      end)

    assert {:ok, paid} = Dancing.on_tick({:player, 17}, updated, %{})
    assert_received :paid
    assert paid.state.ticks == 5

    updated =
      Enum.reduce(1..4, paid, fn _, current ->
        assert {:ok, next} = Dancing.on_tick({:player, 17}, current, %{})
        refute_received :paid
        next
      end)

    assert {:ok, twice} = Dancing.on_tick({:player, 17}, updated, %{})
    assert_received :paid
    assert twice.state.ticks == 10

    stub(PlayerSession, :try_consume_sp, fn _pid, 1 -> {:error, :insufficient_sp} end)

    assert :remove =
             Dancing.on_tick({:player, 17}, %{twice | state: %{upkeep: 1, ticks: 10}}, %{})
  end

  test "a single hit above a quarter of maximum HP ends the performance" do
    entry = %StatusEntry{type: :sc_dancing}
    context = %{target: %{max_hp: 100}}
    assert :ok = Dancing.after_damage_taken({:player, 17}, entry, %{damage: 25}, context)
    assert :remove = Dancing.after_damage_taken({:player, 17}, entry, %{damage: 26}, context)
  end

  test "expiry requests asynchronous group teardown" do
    test_pid = self()

    stub(Unit, :destroy_async, fn group_id ->
      send(test_pid, {:destroyed, group_id})
      :ok
    end)

    assert :ok = Dancing.on_expire({:player, 17}, %StatusEntry{val2: 42}, %{})
    assert_received {:destroyed, 42}
  end

  test "solo lock allows walking but blocks attacks and all but strike, arrow and adaptation" do
    player = player(17)
    :ok = UnitRegistry.register_player(player, self())

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_dancing,
               caster_id: 17,
               val1: 315,
               val2: 42,
               val4: nil,
               duration: 60_000,
               state: %{upkeep: 5, ticks: 0}
             )

    assert Interpreter.can_move?(:player, 17)
    refute Interpreter.can_attack?(:player, 17)
    for skill <- [316, 324, 304], do: assert(Interpreter.can_use_skill?(:player, 17, skill))
    refute Interpreter.can_use_skill?(:player, 17, 305)
    assert Registry.get_definition(:sc_dancing).icon == :bdplaying
    assert Registry.get_definition(:sc_dancing).bypass_resistance
  end

  @tag game_mode: :pre_renewal
  test "classic Adaptation cannot end a Wand of Hermode performance" do
    player = player(17)
    :ok = UnitRegistry.register_player(player, self())

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_dancing,
               caster_id: 17,
               val1: 488,
               val2: 42,
               duration: 60_000,
               state: %{upkeep: 5, ticks: 0, root: :always}
             )

    refute Interpreter.can_use_skill?(:player, 17, 304)
    assert Interpreter.can_use_skill?(:player, 17, 316)
  end

  test "an ensemble lock roots its performer" do
    player = player(17)
    :ok = UnitRegistry.register_player(player, self())

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_dancing,
               caster_id: 17,
               val1: 306,
               val2: 42,
               val4: 18,
               duration: 60_000,
               state: %{upkeep: 5, ticks: 0}
             )

    refute Interpreter.can_move?(:player, 17)
  end

  test "walking slows by 500% less 40 per Lesson level" do
    assert %{movement_speed: 500} = Dancing.modifiers(%StatusEntry{val3: 0}, %{})
    assert %{movement_speed: 100} = Dancing.modifiers(%StatusEntry{val3: 10}, %{})
  end

  test "a monster performer is not slowed" do
    assert %{movement_speed: 0} =
             Dancing.modifiers(%StatusEntry{val3: 0}, %{unit_type: :mob, target_id: 42})
  end

  test "a player whose upkeep leaves no SP stops performing" do
    player = put_in(player(17).stats.current_state.sp, 0)
    :ok = UnitRegistry.register_player(player, self())
    stub(PlayerSession, :try_consume_sp, fn _pid, 1 -> :ok end)

    entry = %StatusEntry{type: :sc_dancing, state: %{upkeep: 1, ticks: 0}}
    assert :remove = Dancing.on_tick({:player, 17}, entry, %{})
  end

  test "a monster pays no upkeep and stops on the upkeep beat only without SP" do
    reject(&PlayerSession.try_consume_sp/2)
    entry = %StatusEntry{type: :sc_dancing, state: %{upkeep: 3, ticks: 0}}

    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(42, 0), self())
    assert {:ok, first} = Dancing.on_tick({:mob, 42}, entry, %{})
    assert {:ok, second} = Dancing.on_tick({:mob, 42}, first, %{})
    assert :remove = Dancing.on_tick({:mob, 42}, second, %{})

    :ok = UnitRegistry.update_unit_state(:mob, 42, mob(42, 1))
    assert {:ok, %{state: %{ticks: 3}}} = Dancing.on_tick({:mob, 42}, second, %{})
  end

  test "configured upkeep pays four SP on the tenth tick" do
    :ok = UnitRegistry.register_player(player(17), self())

    expect(PlayerSession, :try_consume_sp, fn _pid, amount ->
      assert amount == 4
      :ok
    end)

    entry = %StatusEntry{type: :sc_dancing, state: %{upkeep: 10, upkeep_sp: 4, ticks: 0}}

    updated =
      Enum.reduce(1..9, entry, fn _, current ->
        assert {:ok, next} = Dancing.on_tick({:player, 17}, current, %{})
        next
      end)

    assert {:ok, %{state: %{ticks: 10}}} = Dancing.on_tick({:player, 17}, updated, %{})
  end

  test "Longing triples upkeep and removes the lock's walk slow in pre-renewal" do
    :ok = UnitRegistry.register_player(player(17), self())
    :ok = StatusStorage.apply_status(:player, 17, :sc_longing, val1: 1)

    expect(PlayerSession, :try_consume_sp, fn _pid, amount ->
      assert amount == 12
      :ok
    end)

    entry = %StatusEntry{
      type: :sc_dancing,
      val3: 10,
      state: %{upkeep: 10, upkeep_sp: 4, ticks: 9}
    }

    assert {:ok, _} = Dancing.on_tick({:player, 17}, entry, %{})

    # Renewal's speed recipe has no Longing term: only Ensemble Fatigue lifts
    # the performing slow there.
    slow = %{renewal: 100, pre_renewal: 0}[GameMode.mode()]

    assert %{movement_speed: ^slow} =
             Dancing.modifiers(entry, %{unit_type: :player, target_id: 17})
  end

  @tag game_mode: :renewal
  test "Ensemble Fatigue removes the lock's walk slow in renewal" do
    :ok = UnitRegistry.register_player(player(17), self())
    :ok = StatusStorage.apply_status(:player, 17, :sc_ensemblefatigue, val1: 1)

    entry = %StatusEntry{type: :sc_dancing, val3: 10, state: %{upkeep: 10, ticks: 0}}

    assert %{movement_speed: 0} = Dancing.modifiers(entry, %{unit_type: :player, target_id: 17})
  end

  test "Longing frees an ensemble but not an always-rooted field" do
    :ok = UnitRegistry.register_player(player(17), self())

    :ok =
      StatusStorage.apply_status(:player, 17, :sc_dancing,
        val1: 306,
        state: %{root: :ensemble, upkeep: 10, ticks: 0}
      )

    assert Interpreter.can_use_skill?(:player, 17, 487)
    refute Interpreter.can_move?(:player, 17)
    refute Interpreter.can_attack?(:player, 17)

    :ok = StatusStorage.apply_status(:player, 17, :sc_longing, val1: 5)
    assert Interpreter.can_move?(:player, 17)
    assert Interpreter.can_attack?(:player, 17)
    assert Interpreter.can_use_skill?(:player, 17, 1)
    refute Interpreter.can_use_skill?(:player, 17, 305)
    refute Interpreter.can_use_skill?(:player, 17, 306)
    refute Interpreter.can_use_skill?(:player, 17, 319)

    :ok =
      StatusStorage.apply_status(:player, 17, :sc_dancing,
        state: %{root: :always, upkeep: 10, ticks: 0}
      )

    refute Interpreter.can_move?(:player, 17)
    assert Interpreter.can_attack?(:player, 17)
  end

  test "Longing does not free a solo lock or override another restriction" do
    :ok = UnitRegistry.register_player(player(17), self())
    :ok = StatusStorage.apply_status(:player, 17, :sc_longing, val1: 5)
    :ok = StatusStorage.apply_status(:player, 17, :sc_dancing, state: %{root: :none})
    refute Interpreter.can_attack?(:player, 17)
    refute Interpreter.can_use_skill?(:player, 17, 1)
    :ok = StatusStorage.apply_status(:player, 17, :sc_stun)
    refute Interpreter.can_move?(:player, 17)
    refute Interpreter.can_use_skill?(:player, 17, 1)
  end

  defp mob(id, sp) do
    %MobState{
      instance_id: id,
      mob_id: 1002,
      mob_data: nil,
      spawn_ref: nil,
      x: 100,
      y: 100,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: sp,
      max_sp: 1,
      spawned_at: 0
    }
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Dancer #{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "F",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 20
    })
  end
end
