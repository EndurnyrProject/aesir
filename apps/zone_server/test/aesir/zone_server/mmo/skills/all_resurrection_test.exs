defmodule Aesir.ZoneServer.Mmo.Skills.AllResurrectionTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AllResurrection
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(PlayerSession)
    Mimic.copy(PlayerState)
    Mimic.copy(MobState)
    Mimic.copy(Combat)
    Mimic.copy(TargetResolver)
  end

  defp living_mob do
    %MobState{
      instance_id: 2_000,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 150,
      y: 150,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }
  end

  test "exposes the exact Renewal definition" do
    assert {:ok, definition} = Catalog.by_id(54)

    assert definition.name == :all_resurrection
    assert definition.max_level == 4
    assert definition.target_type == :target_resurrection
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :magic
    assert definition.element == :holy
    assert definition.range == 9
    assert definition.cast_time == [4_800, 3_200, 1_600, 0]
    assert definition.fixed_cast_time == [1_200, 800, 400, 0]
    assert definition.after_cast_delay == [0, 1_000, 2_000, 3_000]
    assert definition.sp_cost == List.duplicate(60, 4)
    assert definition.item_cost == [%{id: 717, amount: 1}]
  end

  test "levels 1 through 4 revive a player corpse at 10, 30, 50, and 80 percent HP" do
    assert {:ok, definition} = Catalog.by_id(54)
    target_pid = self()
    corpse = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, target_pid, corpse, :player} end)

    for {percent, level} <- Enum.with_index([10, 30, 50, 80], 1) do
      expect(PlayerSession, :resurrect, fn ^target_pid, 1_000, ^percent -> :ok end)

      caster = %{character_id: 1_000}

      assert {:ok, ^caster} =
               AllResurrection.cast(caster, {:unit, 2_000}, level, definition)
    end
  end

  test "rejects a living non-undead target before costs are charged" do
    living = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), living, :mob} end)
    stub(MobState, :to_combatant, fn ^living -> %{race: :formless, element: {:neutral, 1}} end)

    assert {:error, :invalid_target} =
             AllResurrection.validate(%{character_id: 1_000}, {:unit, 2_000}, 1, %{})
  end

  test "a living undead target follows Resurrection's canonical Holy magic branch" do
    assert {:ok, definition} = Catalog.by_id(54)

    living_undead = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), living_undead, :mob} end)

    stub(MobState, :to_combatant, fn ^living_undead ->
      %{race: :formless, element: {:undead, 1}}
    end)

    stub(MobState, :get_stats, fn ^living_undead -> %{hp: 100, max_hp: 100} end)
    stub(PlayerState, :get_stats, fn _caster -> %{luk: 0, int: 0, base_level: 0} end)
    :rand.seed(:exsss, {100, 200, 300})

    expect(Combat, :execute_magic_attack, fn %{character_id: 1_000}, 2_000, opts ->
      assert opts[:skill_id] == 54
      assert opts[:skill_level] == 4
      assert opts[:skill_ratio] == 4
      assert opts[:element] == :holy
      assert opts[:skip_range]
      :ok
    end)

    caster = %{character_id: 1_000}

    assert :ok = AllResurrection.validate(caster, {:unit, 2_000}, 4, definition)
    assert {:ok, ^caster} = AllResurrection.cast(caster, {:unit, 2_000}, 4, definition)
  end

  test "the undead instant-kill score uses the Renewal formula and 70 percent cap" do
    caster = %{luk: 50, int: 80, base_level: 99}
    target = %{hp: 1, max_hp: 1_000}

    assert AllResurrection.instant_kill_score(caster, target, 4) == 569

    assert AllResurrection.instant_kill_score(
             %{luk: 400, int: 400, base_level: 300},
             target,
             4
           ) == 700
  end

  test "a successful undead roll feeds the target's current HP through existing magic combat" do
    assert {:ok, definition} = Catalog.by_id(54)
    living_undead = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), living_undead, :mob} end)

    stub(MobState, :to_combatant, fn ^living_undead ->
      %{race: :undead, element: {:neutral, 1}}
    end)

    stub(MobState, :get_stats, fn ^living_undead -> %{hp: 100, max_hp: 100} end)
    stub(PlayerState, :get_stats, fn _caster -> %{luk: 400, int: 400, base_level: 300} end)
    :rand.seed(:exsss, {1, 2, 3})

    expect(Combat, :execute_magic_attack, fn %{character_id: 1_000}, 2_000, opts ->
      assert opts[:skill_id] == 54
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 0
      assert opts[:bonus_matk] == 100
      assert opts[:element] == :holy
      assert opts[:skip_range]
      refute opts[:ignore_mdef]
      :ok
    end)

    caster = %{character_id: 1_000}
    assert {:ok, ^caster} = AllResurrection.cast(caster, {:unit, 2_000}, 1, definition)
  end

  test "a status-immune boss undead always uses the ordinary MATK fallback" do
    assert {:ok, definition} = Catalog.by_id(54)
    boss_undead = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), boss_undead, :mob} end)

    stub(MobState, :to_combatant, fn ^boss_undead ->
      %{race: :undead, element: {:undead, 1}, class: :boss}
    end)

    stub(MobState, :get_stats, fn ^boss_undead -> %{hp: 100, max_hp: 100} end)
    stub(PlayerState, :get_stats, fn _caster -> %{luk: 400, int: 400, base_level: 300} end)
    :rand.seed(:exsss, {1, 2, 3})

    expect(Combat, :execute_magic_attack, fn %{character_id: 1_000}, 2_000, opts ->
      assert opts[:skill_ratio] == 4
      refute opts[:bonus_matk]
      :ok
    end)

    caster = %{character_id: 1_000}
    assert {:ok, ^caster} = AllResurrection.cast(caster, {:unit, 2_000}, 4, definition)
  end
end
