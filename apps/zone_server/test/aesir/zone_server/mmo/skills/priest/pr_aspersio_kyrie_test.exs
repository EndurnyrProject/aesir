defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrAspersioKyrieTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrAspersio
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrKyrie
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(Combat)
    Mimic.copy(TargetResolver)
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "Aspersio exposes its Renewal definition and Holy Water cost" do
    assert {:ok, definition} = Catalog.by_id(68)

    assert definition.name == :pr_aspersio
    assert definition.max_level == 5
    assert definition.target_type == :target_ally
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :magic
    assert definition.element == :holy
    assert definition.range == 9
    assert definition.after_cast_delay == List.duplicate(2_000, 5)
    assert definition.sp_cost == [14, 18, 22, 26, 30]
    assert definition.item_cost == [%{id: 523, amount: 1}]
    assert definition.duration == [60_000, 90_000, 120_000, 150_000, 180_000]
  end

  test "Aspersio applies its status with the selected level and duration" do
    assert {:ok, definition} = Catalog.by_id(68)
    caster = %{character_id: 1_000}

    expect(StatusInterpreter, :apply_status, fn :player, 1_000, :sc_aspersio, params ->
      assert params[:val1] == 3
      assert params[:caster_id] == 1_000
      assert params[:duration] == 120_000
      :ok
    end)

    assert {:ok, ^caster} = PrAspersio.cast(caster, :self, 3, definition)
  end

  test "Aspersio deals fixed Holy magic damage to an undead enemy" do
    caster = %{character_id: 1_000}

    stub(Combat, :resolve_combatant, fn 2_000 ->
      {:ok, %{unit_type: :mob, race: :undead, element: {:undead, 1}}}
    end)

    expect(Combat, :execute_magic_damage, fn ^caster, 2_000, 40, opts ->
      assert opts[:skill_id] == 68
      assert opts[:skill_level] == 3
      assert opts[:element] == :holy
      assert opts[:skip_range]
      :ok
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} =
             PrAspersio.cast(caster, {:unit, 2_000}, 3, PrAspersio.definition())
  end

  test "Kyrie exposes its Renewal timing and SP tables" do
    assert {:ok, definition} = Catalog.by_id(73)

    assert definition.name == :pr_kyrie
    assert definition.max_level == 10
    assert definition.target_type == :target_ally
    assert definition.damage_type == :no_damage
    assert definition.range == 9
    assert definition.cast_time == List.duplicate(1_600, 10)
    assert definition.fixed_cast_time == List.duplicate(400, 10)
    assert definition.after_cast_delay == List.duplicate(2_000, 10)
    assert definition.sp_cost == [20, 20, 20, 25, 25, 25, 30, 30, 30, 35]
    assert definition.duration == List.duplicate(120_000, 10)
  end

  test "Kyrie derives its barrier HP and hit count from the target's max HP" do
    assert {:ok, definition} = Catalog.by_id(73)
    caster = %{character_id: 1_000, stats: %{derived_stats: %{max_hp: 1_234}}}

    expect(StatusInterpreter, :apply_status, fn :player, 1_000, :sc_kyrie, params ->
      assert params[:val1] == 4
      assert params[:val2] == 222
      assert params[:val3] == 7
      assert params[:caster_id] == 1_000
      assert params[:duration] == 120_000
      :ok
    end)

    assert {:ok, ^caster} = PrKyrie.cast(caster, :self, 4, definition)
  end

  test "Kyrie derives its barrier from an allied player's max HP" do
    assert {:ok, definition} = Catalog.by_id(73)
    caster = %{character_id: 1_000, stats: %{derived_stats: %{max_hp: 1_000}}}
    target = %PlayerState{stats: %{derived_stats: %{max_hp: 2_001}}}

    stub(UnitRegistry, :get_unit, fn :player, 2_000 -> {:ok, {PlayerState, target, self()}} end)

    expect(StatusInterpreter, :apply_status, fn :player, 2_000, :sc_kyrie, params ->
      assert params[:val2] == 600
      assert params[:val3] == 10
      :ok
    end)

    assert {:ok, ^caster} = PrKyrie.cast(caster, {:unit, 2_000}, 10, definition)
  end

  test "Kyrie recast replaces a depleted barrier with full target-derived state" do
    caster = %{character_id: 1_000, stats: %{derived_stats: %{max_hp: 1_000}}}

    target = %PlayerState{
      action_state: :idle,
      stats: %{current_state: %{hp: 100}, derived_stats: %{max_hp: 2_000}}
    }

    stub(UnitRegistry, :get_unit_info, fn :player, _unit_id -> {:ok, %{stats: %{}}} end)
    stub(UnitRegistry, :get_unit, fn :player, 2_000 -> {:ok, {PlayerState, target, self()}} end)

    :ok =
      StatusInterpreter.apply_status(:player, 2_000, :sc_kyrie,
        duration: 30_000,
        val1: 1,
        val2: 100,
        val3: 5
      )

    assert StatusInterpreter.absorb_damage(:player, 2_000, 25, %{dmg_type: :physical}) == 0

    assert %{state: %{shield_hp: 75, hits_remaining: 4}} =
             StatusStorage.get_status(:player, 2_000, :sc_kyrie)

    assert {:ok, ^caster} =
             PrKyrie.cast(caster, {:unit, 2_000}, 5, PrKyrie.definition())

    refreshed = StatusStorage.get_status(:player, 2_000, :sc_kyrie)
    assert refreshed.val1 == 5
    assert refreshed.val2 == 400
    assert refreshed.val3 == 7
    assert refreshed.state == %{shield_hp: 400, hits_remaining: 7}
    assert refreshed.expires_at - refreshed.started_at == 120_000
  end

  test "Kyrie rejects a living non-player target before a cast can charge SP" do
    caster = game_state(%{73 => 1}, %{})
    target = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), target, :mob} end)

    stub(Combat, :resolve_target_position, fn 2_000 ->
      {:ok, :mob, {10, 10, "prontera"}}
    end)

    assert {:error, :invalid_target} = SkillInterpreter.cast(caster, 73, 1, {:unit, 2_000})
    assert caster.stats.current_state.sp == 100
  end

  test "an invalid Aspersio target retains Holy Water and SP" do
    caster = game_state(%{68 => 1}, %{0 => catalyst(1)})
    target = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), target, :mob} end)

    stub(Combat, :resolve_target_position, fn 2_000 ->
      {:ok, :mob, {10, 10, "prontera"}}
    end)

    stub(Combat, :resolve_combatant, fn 2_000 ->
      {:ok, %{unit_type: :mob, race: :formless, element: {:neutral, 1}}}
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :invalid_target} = SkillInterpreter.cast(caster, 68, 1, {:unit, 2_000})
    assert caster.stats.current_state.sp == 100
    assert caster.inventory == %{0 => catalyst(1)}
  end

  test "a successful offensive Aspersio consumes Holy Water and SP after damage delivery" do
    caster = game_state(%{68 => 1}, %{0 => catalyst(1)})
    target = living_mob()

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), target, :mob} end)

    stub(Combat, :resolve_target_position, fn 2_000 ->
      {:ok, :mob, {10, 10, "prontera"}}
    end)

    stub(Combat, :resolve_combatant, fn 2_000 ->
      {:ok, %{unit_type: :mob, race: :undead, element: {:undead, 1}}}
    end)

    expect(Combat, :execute_magic_damage, fn ^caster, 2_000, 40, _opts -> :ok end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, updated} = SkillInterpreter.cast(caster, 68, 1, {:unit, 2_000})
    assert updated.stats.current_state.sp == 86
    assert updated.inventory == %{}
  end

  test "a dead target retains Aspersio's Holy Water and SP" do
    dead_target = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), dead_target, :player} end)

    caster = game_state(%{68 => 1}, %{0 => catalyst(1)})

    assert {:error, :target_dead} = SkillInterpreter.cast(caster, 68, 1, {:unit, 2_000})
    assert caster.stats.current_state.sp == 100
    assert caster.inventory == %{0 => catalyst(1)}
  end

  test "a dead Kyrie target retains SP" do
    dead_target = %PlayerState{action_state: :dead, stats: %{current_state: %{hp: 0}}}

    stub(TargetResolver, :resolve, fn 2_000 -> {:ok, self(), dead_target, :player} end)

    caster = game_state(%{73 => 1}, %{})

    assert {:error, :target_dead} = SkillInterpreter.cast(caster, 73, 1, {:unit, 2_000})
    assert caster.stats.current_state.sp == 100
  end

  test "Aspersio replaces an existing weapon endow" do
    stub(UnitRegistry, :get_unit_info, fn :player, 1_000 -> {:ok, %{stats: %{}}} end)
    :ok = StatusInterpreter.apply_status(:player, 1_000, :sc_fireweapon, duration: 30_000)

    assert {:ok, _caster} =
             PrAspersio.cast(%{character_id: 1_000}, :self, 1, PrAspersio.definition())

    refute StatusStorage.has_status?(:player, 1_000, :sc_fireweapon)
    assert %{val1: 1} = StatusStorage.get_status(:player, 1_000, :sc_aspersio)
  end

  test "a successful Aspersio cast consumes one Holy Water after applying the status" do
    stub(UnitRegistry, :get_unit_info, fn :player, 1_000 -> {:ok, %{stats: %{}}} end)
    caster = game_state(%{68 => 3}, %{0 => catalyst(1)})

    assert {:ok, updated} = SkillInterpreter.cast(caster, 68, 3, :self)
    assert updated.stats.current_state.sp == 78
    assert updated.inventory == %{}
    assert %{val1: 3} = StatusStorage.get_status(:player, 1_000, :sc_aspersio)
  end

  defp game_state(learned_skills, inventory) do
    %{
      character_id: 1_000,
      x: 10,
      y: 10,
      map_name: "prontera",
      zeny: 0,
      skill_cooldowns: %{},
      act_delay_until: 0,
      inventory: inventory,
      pending_inventory_persist: [],
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 100, max_hp: 100},
        progression: %{learned_skills: learned_skills}
      }
    }
  end

  defp catalyst(amount), do: %InventoryItem{nameid: 523, amount: amount, equip: 0}

  defp living_mob do
    %MobState{
      instance_id: 2_000,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      x: 10,
      y: 10,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0,
      is_dead: false
    }
  end
end
