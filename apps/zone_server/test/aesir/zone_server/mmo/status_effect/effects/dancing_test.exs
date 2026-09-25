defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DancingTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Dancing
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
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

  test "lock blocks movement and attacks but allows strike, arrow and adaptation" do
    player = player(17)
    :ok = UnitRegistry.register_player(player, self())

    assert :ok =
             Interpreter.apply_status(:player, 17, :sc_dancing,
               caster_id: 17,
               val1: 315,
               val2: 42,
               duration: 60_000,
               state: %{upkeep: 5, ticks: 0}
             )

    refute Interpreter.can_move?(:player, 17)
    refute Interpreter.can_attack?(:player, 17)
    for skill <- [316, 324, 304], do: assert(Interpreter.can_use_skill?(:player, 17, skill))
    refute Interpreter.can_use_skill?(:player, 17, 305)
    assert Registry.get_definition(:sc_dancing).icon == :bdplaying
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
