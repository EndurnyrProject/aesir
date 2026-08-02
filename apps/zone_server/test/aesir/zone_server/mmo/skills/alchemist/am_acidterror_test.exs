defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAcidterrorTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmAcidterror
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  @target_id 2000

  defmodule FakeUnit do
    @moduledoc false
    defstruct [:combatant, :hp, :x, :y, :map_name]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
    def living?(%__MODULE__{hp: hp}), do: hp > 0
  end

  defp definition do
    Catalog.reload()
    {:ok, definition} = Catalog.by_id(230)
    definition
  end

  defp caster(learned_skills \\ %{}) do
    %{stats: %{progression: %{learned_skills: learned_skills}}}
  end

  defp hit_stub(test_pid) do
    stub(Combat, :execute_acid_terror_attack, fn caster, @target_id, opts ->
      send(test_pid, {:attack, caster, opts})
      {:ok, %{hit?: true}}
    end)

    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), %{stats: %Stats{}}, :player} end)

    stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> :ok end)
    stub(EquipBreak, :resolve_slot, fn _, _, _, _ -> [] end)
  end

  test "definition carries cast costs and timings" do
    skill = definition()

    assert skill.name == :am_acidterror
    assert skill.max_level == 5
    assert skill.target_type == :target_enemy
    assert skill.damage_kind == :weapon
    assert skill.sp_cost == List.duplicate(15, 5)
    assert skill.item_cost == [%{id: 7136, amount: 1}]
    assert skill.cast_time == List.duplicate(500, 5)
    assert skill.fixed_cast_time == List.duplicate(500, 5)
    assert skill.after_cast_delay == List.duplicate(500, 5)
    assert skill.element == :neutral
    assert skill.hit_count == 1
  end

  test "ratio is 100 + 200 per level without Learning Potion" do
    hit_stub(self())

    for level <- 1..5 do
      assert {:ok, _caster} =
               AmAcidterror.cast(caster(), {:unit, @target_id}, level, definition())

      assert_receive {:attack, _, opts}
      assert opts[:skill_ratio] == 100 + 200 * level
    end
  end

  test "any learned Learning Potion level adds a flat 100 ratio" do
    hit_stub(self())
    {:ok, %{id: learning_potion_id}} = Catalog.by_name(:am_learningpotion)

    state = caster(%{learning_potion_id => 1})
    assert {:ok, ^state} = AmAcidterror.cast(state, {:unit, @target_id}, 3, definition())
    assert_receive {:attack, _, opts}
    assert opts[:skill_ratio] == 800
  end

  test "attack is forced neutral, never misses, cannot crit, and uses status-DEF bypass" do
    hit_stub(self())

    assert {:ok, _caster} = AmAcidterror.cast(caster(), {:unit, @target_id}, 5, definition())
    assert_receive {:attack, _, opts}
    assert opts[:element] == :neutral
    assert opts[:ignore_flee] == true
    assert opts[:skip_crit] == true
    assert opts[:report_hit] == true
  end

  test "a connected hit wires Bleeding chance and duration" do
    test_pid = self()
    hit_stub(test_pid)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_bleeding, opts ->
      assert opts[:duration] == 108_000
      assert opts[:success_rate] == 15
      :ok
    end)

    assert {:ok, _caster} = AmAcidterror.cast(caster(), {:unit, @target_id}, 5, definition())
  end

  test "armor break uses the slot resolver and dispatches its decision" do
    hit_stub(self())
    victim = %Stats{}
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), %{stats: victim}, :player} end)

    expect(EquipBreak, :resolve_slot, fn 2_500, {:player, @target_id, ^victim}, :armor, [] ->
      [{:target, :armor}]
    end)

    expect(PlayerSession, :break_equip, fn pid, :armor ->
      assert pid == self()
      :ok
    end)

    assert {:ok, _caster} = AmAcidterror.cast(caster(), {:unit, @target_id}, 3, definition())
  end

  test "SC_CP_ARMOR veto from the real resolver prevents dispatch" do
    hit_stub(self())
    victim = %Stats{}
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), %{stats: victim}, :player} end)
    Mimic.copy(EquipBreak)

    StatusStorage.apply_status(:player, @target_id, :sc_cp_armor)
    reject(&PlayerSession.break_equip/2)

    assert {:ok, _caster} = AmAcidterror.cast(caster(), {:unit, @target_id}, 5, definition())
  end

  test "restricted combat path connects against extreme Flee" do
    attacker = combatant(1000, :player, hit: 1)
    target = combatant(@target_id, :mob, flee: 10_000)
    caster_state = %FakeUnit{combatant: attacker, x: 10, y: 10, map_name: "test"}
    target_state = %FakeUnit{combatant: target, hp: 100, x: 10, y: 10, map_name: "test"}

    stub(UnitRegistry, :get_unit, fn :mob, @target_id ->
      {:ok, {FakeUnit, target_state, self()}}
    end)

    stub(SpatialIndex, :get_unit_position, fn :mob, @target_id -> {:ok, {10, 10, "test"}} end)
    stub(Broadcast, :to_in_range, fn _, _, _, _, _ -> :ok end)

    expect(DamageCalculator, :calculate_damage_ignoring_status_def, fn _, _, opts ->
      assert opts[:element] == :neutral
      assert opts[:skip_crit] == true
      {:ok, %{damage: 20, is_critical: false}}
    end)

    expect(MobSession, :apply_damage, fn _, 20, 1000 -> :ok end)

    assert {:ok, %{hit?: true}} =
             Combat.execute_acid_terror_attack(caster_state, @target_id,
               skill_id: 230,
               skill_level: 5,
               skill_ratio: 1_100,
               element: :neutral,
               ignore_flee: true,
               skip_crit: true,
               report_hit: true
             )
  end

  test "restricted calculator ignores soft DEF and forced neutral overrides an endow" do
    Mimic.copy(ElementModifiers)
    Mimic.copy(ModifierCalculator)

    stub(ModifierCalculator, :get_all_modifiers, fn
      :player, attacker_id when attacker_id in [1000, 1001] -> %{attack_element: :water}
      _, _ -> %{}
    end)

    stub(ElementModifiers, :get_modifier, fn attack_element, _, _, _ ->
      send(self(), {:attack_element, attack_element})
      1.0
    end)

    neutral_attacker = combatant(1000, :player, weapon_element: :neutral, critical: 10_000)
    fire_attacker = combatant(1001, :player, weapon_element: :fire, critical: 10_000)
    low_soft_def = combatant(2000, :player, vit: 1, defense_element: {:water, 1})
    high_soft_def = combatant(2001, :player, vit: 99, defense_element: {:water, 1})
    opts = [skill_ratio: 300, element: :neutral, skip_crit: true]

    assert {:ok, low_result} =
             DamageCalculator.calculate_damage_ignoring_status_def(
               neutral_attacker,
               low_soft_def,
               opts
             )

    assert {:ok, high_result} =
             DamageCalculator.calculate_damage_ignoring_status_def(
               fire_attacker,
               high_soft_def,
               opts
             )

    assert low_result.damage == high_result.damage
    assert low_result.is_critical == false
    assert high_result.is_critical == false
    assert_received {:attack_element, :neutral}
    assert_received {:attack_element, :neutral}
  end

  defp combatant(unit_id, unit_type, opts) do
    Combatant.new!(%{
      unit_id: unit_id,
      unit_type: unit_type,
      base_stats: %{
        str: 10,
        agi: 1,
        vit: Keyword.get(opts, :vit, 1),
        int: 1,
        dex: 1,
        luk: 1
      },
      combat_stats: %{
        atk: 100,
        def: 0,
        passive_atk: 0,
        hit: Keyword.get(opts, :hit, 200),
        flee: Keyword.get(opts, :flee, 0),
        perfect_dodge: 0,
        critical: Keyword.get(opts, :critical, 0),
        max_weapon_damage: true
      },
      progression: %{base_level: 1, job_level: 1},
      element: Keyword.get(opts, :defense_element, {:neutral, 1}),
      race: :formless,
      size: :medium,
      weapon: %{
        type: :fist,
        element: Keyword.get(opts, :weapon_element, :neutral),
        size: :medium
      },
      attack_range: 1,
      attack_delay_ms: 500,
      position: {10, 10},
      map_name: "test"
    })
  end
end
