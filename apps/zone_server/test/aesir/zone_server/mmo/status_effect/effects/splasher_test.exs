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

  test "is saved and counts its countdown down in val4 every half second" do
    metadata = Splasher.metadata()
    refute metadata.no_save
    refute metadata.remove_on_map_change
    refute metadata.no_dispel
    assert metadata.remove_on_death
    assert metadata.icon == :splasher
    assert metadata.immunity == [:status_immune]
    assert metadata.tick_interval == 500

    assert {:ok, %{val4: 500}} = Splasher.on_tick({:mob, 2_000}, entry(countdown: 1_000), %{})
  end

  @tag game_mode: :renewal
  test "a player terminal tick uses the current target cell and the source's current Poison React" do
    expect(StatusInterpreter, :expire_status_if_current, fn
      :mob, 2_000, :sc_splasher, _instance -> true
    end)

    source = player_source(10)

    expect(TargetResolver, :resolve, fn :player, 1_000 -> {:ok, self(), source, :player} end)

    expect(TargetResolver, :resolve_target_position, fn {:mob, 2_000} ->
      {:ok, :mob, {120, 121, "prontera"}}
    end)

    expect(Combat, :execute_forced_no_card_splash, fn ^source, {120, 121}, 2, opts ->
      assert opts == [
               skill_id: 141,
               skill_level: 10,
               skill_ratio: 1_600,
               typed_results: true,
               delivery: {:splash, {:mob, 2_000}}
             ]

      [{:mob, 2_001}, {:player, 2_002}]
    end)

    expect(StatusInterpreter, :apply_status, 2, fn unit_type, unit_id, :sc_poison, params ->
      assert {unit_type, unit_id} in [{:mob, 2_001}, {:player, 2_002}]
      assert params == [duration: 18_000, caster_id: 1_000, source_type: :player]
      :ok
    end)

    expect(SpecialEffect, :play, fn {:mob, 2_000}, :splasher -> :ok end)

    assert :remove =
             Splasher.on_tick({:mob, 2_000}, entry(countdown: 500, level: 10), %{})
  end

  @tag game_mode: :renewal
  test "a mob terminal tick omits player passive resources and empty areas stay valid" do
    expect(StatusInterpreter, :expire_status_if_current, fn
      :player, 4_000, :sc_splasher, _instance -> true
    end)

    source =
      %MobState{
        instance_id: 3_000,
        mob_id: 1,
        mob_data: Aesir.TestMob.definition(),
        spawn_ref: nil,
        map_name: "prontera",
        x: 40,
        y: 40,
        hp: 100,
        sp: 0,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

    instance = %{
      entry(countdown: 500, level: 1)
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

  @tag game_mode: :pre_renewal
  test "classic explodes at 500 plus 50 per level and poisons for a minute" do
    assert Splasher.base_ratio(10) == 1_000
    assert Splasher.base_ratio(1) == 550
    assert Splasher.poison_duration() == 60_000

    expect(StatusInterpreter, :expire_status_if_current, fn
      :mob, 2_000, :sc_splasher, _instance -> true
    end)

    source = player_source(10)

    expect(TargetResolver, :resolve, fn :player, 1_000 -> {:ok, self(), source, :player} end)

    expect(TargetResolver, :resolve_target_position, fn {:mob, 2_000} ->
      {:ok, :mob, {120, 121, "prontera"}}
    end)

    expect(Combat, :execute_forced_no_card_splash, fn ^source, {120, 121}, 2, opts ->
      assert opts[:skill_ratio] == 1_200
      [{:mob, 2_001}]
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 2_001, :sc_poison, params ->
      assert params[:duration] == 60_000
      :ok
    end)

    expect(SpecialEffect, :play, fn {:mob, 2_000}, :splasher -> :ok end)

    assert :remove =
             Splasher.on_tick({:mob, 2_000}, entry(countdown: 500, level: 10), %{})
  end

  test "source or target loss cleans the terminal status without exploding" do
    expect(StatusInterpreter, :expire_status_if_current, 2, fn
      :mob, 2_000, :sc_splasher, _instance -> true
    end)

    instance = entry(countdown: 500)

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

  @tag game_mode: :renewal
  test "a dead source still explodes, and one on another map does not" do
    expect(StatusInterpreter, :expire_status_if_current, 2, fn
      :mob, 2_000, :sc_splasher, _instance -> true
    end)

    dead = put_in(%{player_source(0) | action_state: :dead}.stats.current_state.hp, 0)
    elsewhere = %{player_source(0) | map_name: "geffen"}

    expect(TargetResolver, :resolve, 2, fn :player, 1_000 ->
      {:ok, self(), Process.get(:splasher_source), :player}
    end)

    expect(TargetResolver, :resolve_target_position, 2, fn {:mob, 2_000} ->
      {:ok, :mob, {120, 121, "prontera"}}
    end)

    expect(Combat, :execute_forced_no_card_splash, fn ^dead, {120, 121}, 2, opts ->
      assert opts[:skill_ratio] == 700
      []
    end)

    expect(SpecialEffect, :play, fn {:mob, 2_000}, :splasher -> :ok end)

    Process.put(:splasher_source, dead)
    assert :remove = Splasher.on_tick({:mob, 2_000}, entry(countdown: 500), %{})

    Process.put(:splasher_source, elsewhere)
    assert :remove = Splasher.on_tick({:mob, 2_000}, entry(countdown: 500), %{})
  end

  test "a terminal callback that loses the generation claim never explodes" do
    expect(StatusInterpreter, :expire_status_if_current, fn
      :mob, 2_000, :sc_splasher, _instance -> false
    end)

    assert :remove = Splasher.on_tick({:mob, 2_000}, entry(countdown: 500), %{})
  end

  test "ordinary expiration is inert" do
    assert :ok = Splasher.on_expire({:mob, 2_000}, entry(countdown: 500), %{})
  end

  defp entry(opts) do
    %StatusEntry{
      type: :sc_splasher,
      val1: Keyword.get(opts, :level, 3),
      val4: Keyword.fetch!(opts, :countdown),
      tick: 500,
      source_id: 1_000,
      source_type: :player
    }
  end

  defp player_source(poison_react_level) do
    %PlayerState{
      character_id: 1_000,
      map_name: "prontera",
      action_state: :idle,
      stats: %{
        current_state: %{hp: 100},
        progression: %{learned_skills: %{139 => poison_react_level}}
      }
    }
  end
end
