defmodule Aesir.ZoneServer.Mmo.Combat.CriticalWoundHealingTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.PotionRecovery
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.ItemHeal
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.ScriptVitals
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @id 88_301
  @target {:player, @id}
  @caster %{
    player?: true,
    base_level: 60,
    int: 40,
    vit: 0,
    learned: %{},
    brain_rate: 0,
    equipment: %{},
    heal_matk_min: 150,
    heal_matk_max: 150,
    hplus: 0
  }
  @thrower %{
    pitcher: 0,
    learning_potion: 0,
    group_hp_rate: 0,
    group_sp_rate: 0,
    skill_heal: 0,
    hplus: 10
  }

  setup :setup_ets_tables

  setup do
    player =
      PlayerState.new(%Character{
        id: @id,
        account_id: @id,
        name: "CriticalWound",
        class: 0,
        base_level: 60,
        vit: 0,
        int: 0,
        hp: 1,
        sp: 1,
        last_map: "prontera",
        last_x: 100,
        last_y: 100
      })

    :ok = UnitRegistry.register_unit(:player, @id, PlayerState, player, self())
    %{player: player}
  end

  test "initialization wraps the level but preserves the supplied lifetime and restored values" do
    before = System.monotonic_time(:millisecond)

    assert :ok =
             Interpreter.apply_status(:player, @id, :sc_criticalwound,
               val1: 7,
               duration: 90_000
             )

    after_apply = System.monotonic_time(:millisecond)

    assert %{val1: 2, val2: 40} =
             entry = StatusStorage.get_status(:player, @id, :sc_criticalwound)

    assert entry.expires_at >= before + 90_000
    assert entry.expires_at <= after_apply + 90_000

    assert :ok =
             Interpreter.apply_status(:player, @id, :sc_criticalwound,
               val1: 3,
               val2: 37,
               duration: 10_000,
               loaded: true
             )

    assert %{val1: 3, val2: 37} = StatusStorage.get_status(:player, @id, :sc_criticalwound)
  end

  test "healing skills keep the mode's reduction rounding, H.Plus order and attack exceptions" do
    start_wound(1)
    expected = if GameMode.mode() == :renewal, do: 683, else: 622
    assert SkillHeal.amount(%{@caster | hplus: 10}, @target, 70, 7, true) == expected
    assert SkillHeal.amount(@caster, @target, 70, 7, false) == 388
    assert SkillHeal.amount(@caster, @target, 28, 11, true) == 9_999
    assert SkillHeal.amount(@caster, nil, 70, 7, true) == 777

    :ok = StatusStorage.apply_status(:player, @id, :sc_norecover_state)

    assert SkillHeal.amount(@caster, @target, 70, 7, true) ==
             if(GameMode.mode() == :renewal, do: 1, else: 0)
  end

  test "item healing reduces HP and SP after bonuses and Renewal Apple of Idun", %{player: player} do
    start_wound(1)
    :ok = StatusStorage.apply_status(:player, @id, :sc_appleidun, val3: 2_000)
    hp = if GameMode.mode() == :renewal, do: 97, else: 81
    assert ItemHeal.amounts(player, nil, 101, 51) == {hp, 41}

    :ok = StatusStorage.apply_status(:player, @id, :sc_norecover_state)
    assert ItemHeal.amounts(player, nil, 101, 51) == {0, 0}
  end

  test "Potion Pitcher and Slim Pitcher reduce each final recipient amount", %{player: player} do
    start_wound(1)
    recipient = PotionRecovery.recipient(player)
    potion = %{hp: 101, sp: 51, per_hp: 0, per_sp: 0}
    assert PotionRecovery.player_throw(@thrower, recipient, potion) == {89, 45}
    assert PotionRecovery.slim_receive({111, 56}, recipient) == {89, 45}

    :ok = StatusStorage.apply_status(:player, @id, :sc_norecover_state)
    assert PotionRecovery.player_throw(@thrower, recipient, potion) == {0, 0}
    assert PotionRecovery.slim_receive({111, 56}, recipient) == {0, 0}
  end

  test "plain and percent script heals bypass the wound", %{player: player} do
    start_wound(5)
    assert {plain, nil} = ScriptVitals.apply({:heal, 101, 0}, player)
    assert plain.stats.current_state.hp == 102
    assert {percent, nil} = ScriptVitals.apply({:percent_heal, 10, 0}, player)
    assert percent.stats.current_state.hp == 1 + div(player.stats.derived_stats.max_hp * 10, 100)
  end

  defp start_wound(level) do
    assert :ok =
             Interpreter.apply_status(:player, @id, :sc_criticalwound,
               val1: level,
               duration: 30_000
             )
  end
end
