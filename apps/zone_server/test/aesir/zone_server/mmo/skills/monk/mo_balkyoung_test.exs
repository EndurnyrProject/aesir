defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoungTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoung
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :verify_on_exit!

  setup do
    Mimic.copy(TargetResolver)
    :ok
  end

  @primary_target_id 42
  @splash_target_id 43

  defp caster do
    %PlayerState{
      character_id: 1,
      x: 100,
      y: 100,
      stats: %Stats{modifiers: %Modifiers{}}
    }
  end

  test "defines the fixed Renewal cost, damage, area, and delay profile" do
    definition = MoBalkyoung.definition()

    assert definition.id == 1_016
    assert definition.target_type == :target_enemy
    assert definition.range == -1
    assert definition.hp_cost == [200]
    assert definition.sp_cost == [40]
    assert definition.splash_radius == 1
    assert definition.knockback == 5
    assert definition.after_cast_delay == [2_000]
    assert definition.duration == [4_500]
  end

  test "passes target-centered native and equipment blow before stunning each connected target" do
    caster = %PlayerState{
      character_id: 1,
      x: 100,
      y: 100,
      stats: %Stats{modifiers: %Modifiers{equipment: %{{:add_skill_blow, 1_016} => 3}}}
    }

    test_pid = self()

    stub(TargetResolver, :resolve, fn {:mob, target_id} ->
      {:ok, self(), %{id: target_id}, :mob}
    end)

    stub(Combat, :resolve_combatant, fn @primary_target_id ->
      {:ok, %{position: {101, 100}}}
    end)

    expect(Combat, :execute_splash_attack, fn ^caster, {101, 100}, 1, opts ->
      assert caster.stats.modifiers.equipment[{:add_skill_blow, 1_016}] == 3
      assert opts[:skill_id] == 1_016
      assert opts[:skill_level] == 1
      assert opts[:skill_ratio] == 800
      assert opts[:skip_crit]
      assert opts[:typed_results]
      assert opts[:base_distance] == 5
      assert opts[:origin] == {101, 100}
      assert opts[:native_target_types] == [:player, :mob, :homunculus]
      send(test_pid, :combined_blow_requested)
      [{:mob, @primary_target_id}, {:mob, @splash_target_id}]
    end)

    reject(&Combat.knockback/5)

    expect(StatusInterpreter, :apply_status, 2, fn :mob, target_id, :sc_stun, opts ->
      assert target_id in [@primary_target_id, @splash_target_id]
      assert opts[:duration] == 4_500
      assert opts[:caster_id] == 1
      send(test_pid, {:stunned, target_id})
      :ok
    end)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, ^caster} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())

    assert_received :combined_blow_requested
    assert_receive {:stunned, target_id} when target_id in [@primary_target_id, @splash_target_id]
    assert_receive {:stunned, target_id} when target_id in [@primary_target_id, @splash_target_id]
  end

  test "does not stun a secondary splash target when the 70 percent roll fails" do
    caster = caster()

    stub(TargetResolver, :resolve, fn {:mob, @splash_target_id} ->
      {:ok, self(), %{id: @splash_target_id}, :mob}
    end)

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:ok, %{position: {101, 100}}} end)

    stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, opts ->
      assert opts[:typed_results]
      [{:mob, @splash_target_id}]
    end)

    reject(&Combat.knockback/5)
    reject(&StatusInterpreter.apply_status/4)

    :rand.seed(:exsss, {6, 7, 8})

    assert {:ok, ^caster} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  test "preserves the typed player target when unit ids collide" do
    caster = caster()

    expect(TargetResolver, :resolve, fn {:player, @splash_target_id} ->
      {:ok, self(), %{id: @splash_target_id}, :player}
    end)

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:ok, %{position: {101, 100}}} end)

    stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, opts ->
      assert opts[:typed_results]
      [{:player, @splash_target_id}]
    end)

    reject(&Combat.knockback/5)

    expect(StatusInterpreter, :apply_status, fn :player, @splash_target_id, :sc_stun, _opts ->
      :ok
    end)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, ^caster} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  test "applies effects to a damaged player target" do
    caster = caster()

    expect(TargetResolver, :resolve, fn {:player, @splash_target_id} ->
      {:ok, self(), %{id: @splash_target_id}, :player}
    end)

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:ok, %{position: {101, 100}}} end)

    stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, opts ->
      assert opts[:native_target_types] == [:player, :mob, :homunculus]
      [{:player, @splash_target_id}]
    end)

    reject(&Combat.knockback/5)

    expect(StatusInterpreter, :apply_status, fn :player, @splash_target_id, :sc_stun, _opts ->
      :ok
    end)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, ^caster} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  test "does not apply effects when a returned hit no longer resolves" do
    caster = caster()

    expect(TargetResolver, :resolve, fn {:mob, @splash_target_id} ->
      {:error, :target_not_found}
    end)

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:ok, %{position: {101, 100}}} end)

    stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, _opts ->
      [{:mob, @splash_target_id}]
    end)

    reject(&Combat.knockback/5)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  test "does not apply effects to targets omitted by splash damage gates" do
    caster = caster()

    expect(TargetResolver, :resolve, fn {:mob, @primary_target_id} ->
      {:ok, self(), %{id: @primary_target_id}, :mob}
    end)

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:ok, %{position: {101, 100}}} end)

    stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, _opts ->
      [{:mob, @primary_target_id}]
    end)

    reject(&Combat.knockback/5)

    expect(StatusInterpreter, :apply_status, fn :mob, @primary_target_id, :sc_stun, _opts ->
      :ok
    end)

    :rand.seed(:exsss, {1, 2, 3})

    assert {:ok, ^caster} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  test "returns target resolution errors without applying splash effects" do
    caster = caster()

    stub(Combat, :resolve_combatant, fn @primary_target_id -> {:error, :target_not_found} end)
    reject(&Combat.execute_splash_attack/4)
    reject(&Combat.knockback/5)
    reject(&StatusInterpreter.apply_status/4)

    assert {:error, :target_not_found} =
             MoBalkyoung.cast(caster, {:unit, @primary_target_id}, 1, definition())
  end

  defp definition do
    %Definition{
      id: 1_016,
      name: :mo_balkyoung,
      display_name: "Ki Explosion",
      max_level: 1,
      target_type: :target_enemy,
      damage_type: :damage,
      range: -1,
      hp_cost: [200],
      sp_cost: [40],
      splash_radius: 1,
      knockback: 5,
      after_cast_delay: [2_000],
      duration: [4_500]
    }
  end
end
