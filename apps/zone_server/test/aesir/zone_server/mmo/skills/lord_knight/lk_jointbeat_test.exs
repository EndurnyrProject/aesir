defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkJointbeatTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkJointbeat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Jointbeat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "choose_break preserves an existing neck break and otherwise chooses one of six" do
    :rand.seed(:exsss, {2, 3, 4})
    assert LkJointbeat.choose_break({:mob, 6_150}) in Jointbeat.breaks()

    :ok = StatusStorage.apply_status(:mob, 6_150, :sc_jointbeat, val2: :neck)
    assert :neck = LkJointbeat.choose_break({:mob, 6_150})
  end

  test "a new wound strikes for 150 percent at level ten; an existing neck for 300" do
    caster = spear_caster()
    {:ok, definition} = Catalog.by_name(:lk_jointbeat)

    stub(Combat, :resolve_combatant, fn 6_150 ->
      {:ok, CombatTestHelper.create_mob_combatant(unit_id: 6_150)}
    end)

    expect(Combat, :execute_skill_attack, 2, fn ^caster, 6_150, opts ->
      strike = Process.get(:jointbeat_strike, 0) + 1
      Process.put(:jointbeat_strike, strike)
      assert opts[:skill_ratio] == if(strike == 1, do: 150, else: 300)
      assert opts[:skip_crit] == true
      assert opts[:skip_range] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: false}}
    end)

    :rand.seed(:exsss, {2, 3, 4})
    assert {:ok, ^caster} = LkJointbeat.cast(caster, {:unit, 6_150}, 10, definition)
    :ok = StatusStorage.apply_status(:mob, 6_150, :sc_jointbeat, val2: :neck)
    assert {:ok, ^caster} = LkJointbeat.cast(caster, {:unit, 6_150}, 10, definition)
  end

  @tag game_mode: :renewal
  test "Renewal's level five delay is 1000 ms" do
    assert {:ok, definition} = Catalog.by_name(:lk_jointbeat)
    assert Enum.at(definition.after_cast_delay, 4) == 1_000
    assert Enum.at(definition.after_cast_delay, 9) == 1_000
  end

  @tag game_mode: :pre_renewal
  test "classic's level five delay is 800 ms while level ten is 1000 ms" do
    assert {:ok, definition} = Catalog.by_name(:lk_jointbeat)
    assert Enum.at(definition.after_cast_delay, 4) == 800
    assert Enum.at(definition.after_cast_delay, 9) == 1_000
  end

  test "a forced landed hit wounds the target with the cast level and chosen break" do
    target =
      PlayerStateFixture.build(%{
        character_id: 6_150,
        stats: %{combat_stats: %CombatStats{}}
      })

    :ok = UnitRegistry.register_player(target, self())
    caster = spear_caster()
    {:ok, definition} = Catalog.by_name(:lk_jointbeat)
    combatant = CombatTestHelper.create_player_combatant(unit_id: 6_150)
    combatant = %{combatant | base_stats: %{combatant.base_stats | str: 0}}
    stub(Combat, :resolve_combatant, fn 6_150 -> {:ok, combatant} end)
    stub(Combat, :execute_skill_attack, fn _caster, 6_150, _opts -> {:ok, %{hit?: true}} end)

    :rand.seed(:exsss, {2, 3, 4})
    assert {:ok, ^caster} = LkJointbeat.cast(caster, {:unit, 6_150}, 10, definition)
    assert %{val1: 10, val2: break} = StatusStorage.get_status(:player, 6_150, :sc_jointbeat)
    assert break in Jointbeat.breaks()
  end

  test "a zero-percent break chance applies no wound" do
    caster = spear_caster()
    {:ok, definition} = Catalog.by_name(:lk_jointbeat)
    combatant = CombatTestHelper.create_mob_combatant(unit_id: 6_150, str: 40)
    stub(Combat, :resolve_combatant, fn 6_150 -> {:ok, combatant} end)
    stub(Combat, :execute_skill_attack, fn _caster, 6_150, _opts -> {:ok, %{hit?: true}} end)
    reject(&StatusInterpreter.apply_status/4)

    :rand.seed(:exsss, {2, 3, 4})
    assert {:ok, ^caster} = LkJointbeat.cast(caster, {:unit, 6_150}, 1, definition)
  end

  test "a missed strike leaves an eligible target unwounded" do
    caster = spear_caster()
    {:ok, definition} = Catalog.by_name(:lk_jointbeat)
    combatant = CombatTestHelper.create_mob_combatant(unit_id: 6_150, str: 0)
    stub(Combat, :resolve_combatant, fn 6_150 -> {:ok, combatant} end)
    stub(Combat, :execute_skill_attack, fn _caster, 6_150, _opts -> {:ok, %{hit?: false}} end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = LkJointbeat.cast(caster, {:unit, 6_150}, 10, definition)
  end

  test "a one-handed sword cannot cast Vital Strike but a spear can" do
    assert {:ok, definition} = Catalog.by_name(:lk_jointbeat)
    assert definition.id == 399
    assert definition.require_weapon == [:one_handed_spear, :two_handed_spear]

    swordsman = %PlayerState{
      character_id: 5_150,
      stats: %Stats{equipment: %Equipment{right_hand: 1101}}
    }

    assert {:error, :requires_spear} =
             LkJointbeat.validate(swordsman, {:unit, 6_150}, 1, definition)

    spearman = %{swordsman | stats: %Stats{equipment: %Equipment{right_hand: 1401}}}
    assert :ok = LkJointbeat.validate(spearman, {:unit, 6_150}, 1, definition)
  end

  defp spear_caster do
    %PlayerState{character_id: 5_150, stats: %Stats{equipment: %Equipment{right_hand: 1401}}}
  end
end
