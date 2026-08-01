defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrapTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Mimic.copy(Knockback)
    Mimic.copy(StatusInterpreter)
  end

  defp group(attrs \\ []) do
    struct!(
      %Group{
        group_id: 1,
        skill_id: 115,
        skill_name: :ht_skidtrap,
        level: 3,
        caster_id: 1000,
        caster_type: :player,
        map_name: "prontera",
        center: {50, 50},
        origin: {40, 50},
        cells: [{50, 50}],
        next_tick_at: 0,
        expires_at: 0,
        interval: 1_000,
        state: %{}
      },
      attrs
    )
  end

  test "registers the canonical placement costs and durations" do
    assert {:ok, HtSkidtrap} = Catalog.ground_module_for(:ht_skidtrap)

    assert %{id: 115, max_level: 5, range: 3, sp_cost: [10, 10, 10, 10, 10]} =
             HtSkidtrap.definition()

    assert [%{id: 1065, amount: 1}] = HtSkidtrap.definition().item_cost
    assert [300_000, 240_000, 180_000, 120_000, 60_000] = HtSkidtrap.definition().unit_duration
  end

  test "places a hidden single-cell trap with typed lifecycle state" do
    stub(UnitRegistry, :get_unit_info, fn :player, 1000 ->
      {:ok, %{stats: %{dex: 1, int: 1, base_level: 1}}}
    end)

    assert {:ok, placement} = HtSkidtrap.on_place(group())
    assert placement.cells == [{50, 50}]
    assert placement.visibility == :party_only
    assert placement.duration == 180_000
    assert placement.state.trap.phase == :armed
  end

  test "a player trap stops and pushes eligible monsters at every level from its placement origin" do
    target = mob_state()
    stub(UnitRegistry, :get_unit, fn :mob, 2000 -> {:ok, {MobState, target, self()}} end)

    for level <- 1..5 do
      expect(StatusInterpreter, :apply_status, fn :mob, 2000, :sc_stop, options ->
        assert options[:duration] == 3_000
        assert options[:bypass_resistance] == true
        assert options[:caster_id] == 1000
        assert options[:source_type] == :player
        :ok
      end)

      expect(Knockback, :knockback, fn :mob, 2000, 40, 50, distance ->
        assert distance == level + 5
        :ok
      end)

      assert :expire = HtSkidtrap.on_touch(group(level: level), {:mob, 2000})
    end
  end

  test "same-cell mob placement uses the deterministic eastward fallback" do
    target = %PlayerState{character_id: 3000}
    stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:ok, {PlayerState, target, self()}} end)
    expect(StatusInterpreter, :apply_status, fn :player, 3000, :sc_stop, _ -> :ok end)
    expect(Knockback, :knockback, fn :player, 3000, 49, 50, 8 -> :ok end)

    assert :expire =
             HtSkidtrap.on_touch(group(caster_type: :mob, origin: {50, 50}), {:player, 3000})
  end

  test "bosses leave the trap armed" do
    boss = mob_state([:boss])

    stub(UnitRegistry, :get_unit, fn :mob, 2000 -> {:ok, {MobState, boss, self()}} end)
    reject(&StatusInterpreter.apply_status/4)
    reject(&Knockback.knockback/5)

    assert {:ok, %Group{}} = HtSkidtrap.on_touch(group(), {:mob, 2000})
  end

  test "status-immune targets leave the trap armed" do
    immune = mob_state([:status_immune])

    stub(UnitRegistry, :get_unit, fn :mob, 2000 -> {:ok, {MobState, immune, self()}} end)
    reject(&StatusInterpreter.apply_status/4)
    reject(&Knockback.knockback/5)

    assert {:ok, %Group{}} = HtSkidtrap.on_touch(group(), {:mob, 2000})
  end

  test "a target rejecting Stop leaves the trap armed" do
    target = mob_state()
    stub(UnitRegistry, :get_unit, fn :mob, 2000 -> {:ok, {MobState, target, self()}} end)
    expect(StatusInterpreter, :apply_status, fn :mob, 2000, :sc_stop, _ -> {:error, :immune} end)
    reject(&Knockback.knockback/5)

    assert {:ok, %Group{}} = HtSkidtrap.on_touch(group(), {:mob, 2000})
  end

  test "a mob trap affects players and same-side contacts remain armed" do
    target = %PlayerState{character_id: 3000}
    stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:ok, {PlayerState, target, self()}} end)
    expect(StatusInterpreter, :apply_status, fn :player, 3000, :sc_stop, _ -> :ok end)
    expect(Knockback, :knockback, fn :player, 3000, 40, 50, 8 -> :ok end)

    assert :expire = HtSkidtrap.on_touch(group(caster_type: :mob), {:player, 3000})
    assert {:ok, %Group{}} = HtSkidtrap.on_touch(group(), {:player, 3000})
  end

  defp mob_state(modes \\ []) do
    definition = %MobDefinition{
      id: 1,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 1,
      hp: 1,
      stats: %{},
      attack_range: 1,
      size: :small,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      modes: modes
    }

    spawn = %MobSpawn{
      mob: 1,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50}
    }

    %MobState{
      instance_id: 2000,
      mob_id: 1,
      spawn_ref: spawn,
      x: 50,
      y: 50,
      map_name: "prontera",
      hp: 1,
      max_hp: 1,
      sp: 1,
      max_sp: 1,
      spawned_at: 0,
      mob_data: definition
    }
  end
end
