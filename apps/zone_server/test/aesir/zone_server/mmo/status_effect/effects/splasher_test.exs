defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SplasherTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Splasher
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpecialEffect

  setup :verify_on_exit!

  test "is tickless to the global poll and decrements only exact callbacks" do
    metadata = Splasher.metadata()
    assert metadata.no_save
    assert metadata.remove_on_map_change
    refute metadata.no_dispel
    assert metadata.remove_on_death
    assert metadata.icon == :splasher
    assert metadata.immunity == [:status_immune]
    assert metadata.tick_interval == nil

    instance = entry(remaining_ms: 1_000)

    assert {:ok, %{state: %{remaining_ms: 500}}} =
             Splasher.on_tick({:mob, 2_000}, instance, %{})
  end

  test "a player terminal tick uses the current target cell and snapshotted passive ratio" do
    expect(StatusInterpreter, :expire_status_if_current, fn
      :mob, 2_000, :sc_splasher, _instance -> true
    end)

    source = %PlayerState{
      character_id: 1_000,
      map_name: "prontera",
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    expect(TargetResolver, :resolve, fn :player, 1_000 -> {:ok, self(), source, :player} end)

    expect(TargetResolver, :resolve_target_position, fn {:mob, 2_000} ->
      {:ok, :mob, {120, 121, "prontera"}}
    end)

    expect(Combat, :execute_forced_no_card_splash, fn ^source, {120, 121}, 2, opts ->
      assert opts == [skill_id: 141, skill_level: 10, skill_ratio: 1_600, typed_results: true]
      [{:mob, 2_001}, {:player, 2_002}]
    end)

    expect(StatusInterpreter, :apply_status, 2, fn unit_type, unit_id, :sc_poison, params ->
      assert {unit_type, unit_id} in [{:mob, 2_001}, {:player, 2_002}]
      assert params == [duration: 18_000, caster_id: 1_000, source_type: :player]
      :ok
    end)

    expect(SpecialEffect, :play, fn {:mob, 2_000}, :splasher -> :ok end)

    assert :remove =
             Splasher.on_tick(
               {:mob, 2_000},
               entry(remaining_ms: 500, level: 10, poison_react_level: 10),
               %{}
             )
  end

  test "a mob terminal tick omits player passive resources and empty areas stay valid" do
    expect(StatusInterpreter, :expire_status_if_current, fn
      :player, 4_000, :sc_splasher, _instance -> true
    end)

    source = %MobState{
      instance_id: 3_000,
      mob_id: 1,
      mob_data: %{},
      spawn_ref: nil,
      map_name: "prontera",
      x: 40,
      y: 40,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    instance = %{
      entry(remaining_ms: 500, level: 1, poison_react_level: 99)
      | source_id: 3_000,
        source_type: :mob
    }

    expect(TargetResolver, :resolve, fn :mob, 3_000 -> {:ok, self(), source, :mob} end)

    expect(TargetResolver, :resolve_target_position, fn {:player, 4_000} ->
      {:ok, :player, {50, 51, "prontera"}}
    end)

    expect(Combat, :execute_forced_no_card_splash, fn ^source, {50, 51}, 2, opts ->
      assert opts[:skill_ratio] == 500
      []
    end)

    expect(SpecialEffect, :play, fn {:player, 4_000}, :splasher -> :ok end)

    assert :remove = Splasher.on_tick({:player, 4_000}, instance, %{})
  end

  test "source or target loss cleans the terminal status without exploding" do
    expect(StatusInterpreter, :expire_status_if_current, 2, fn
      :mob, 2_000, :sc_splasher, _instance -> true
    end)

    instance = entry(remaining_ms: 500)

    expect(TargetResolver, :resolve, fn :player, 1_000 -> {:error, :target_not_found} end)
    assert :remove = Splasher.on_tick({:mob, 2_000}, instance, %{})

    source = %PlayerState{
      character_id: 1_000,
      map_name: "prontera",
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    expect(TargetResolver, :resolve, fn :player, 1_000 -> {:ok, self(), source, :player} end)

    expect(TargetResolver, :resolve_target_position, fn {:mob, 2_000} ->
      {:error, :target_not_found}
    end)

    assert :remove = Splasher.on_tick({:mob, 2_000}, instance, %{})
  end

  test "a terminal callback that loses the generation claim never explodes" do
    expect(StatusInterpreter, :expire_status_if_current, fn
      :mob, 2_000, :sc_splasher, _instance -> false
    end)

    assert :remove = Splasher.on_tick({:mob, 2_000}, entry(remaining_ms: 500), %{})
  end

  test "ordinary expiration is inert" do
    assert :ok = Splasher.on_expire({:mob, 2_000}, entry(remaining_ms: 500), %{})
  end

  defp entry(opts) do
    %StatusEntry{
      type: :sc_splasher,
      val1: Keyword.get(opts, :level, 3),
      tick: 0,
      source_id: 1_000,
      source_type: :player,
      state: %{
        remaining_ms: Keyword.fetch!(opts, :remaining_ms),
        poison_react_level: Keyword.get(opts, :poison_react_level, 7)
      }
    }
  end
end
