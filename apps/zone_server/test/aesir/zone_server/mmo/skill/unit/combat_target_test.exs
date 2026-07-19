defmodule Aesir.ZoneServer.Mmo.Skill.Unit.CombatTargetTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  defmodule FakePlayer do
    defstruct [:combatant, :stats]

    def to_combatant(%__MODULE__{combatant: combatant}), do: combatant
  end

  test "serializes damage with removal and rejects a stale target" do
    manager =
      start_supervised!(
        {Manager,
         name: nil,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
      )

    :ok =
      Manager.register(
        manager,
        group(
          visible?: true,
          cells: [{10, 10}],
          state: %{cell_attrs: %{{10, 10} => targetable_cell_attrs()}}
        )
      )

    [cell] = Storage.get_cells_by_group(1)

    assert %{unit_type: :skill_unit, combat_stats: %{def: 30}, element: {:water, 1}} =
             CombatTarget.to_combatant(cell)

    assert {:destroyed, ^cell} =
             Manager.damage_targetable_cell(manager, cell.cell_id, 10, {:player, 1})

    assert {:error, :not_found} = UnitRegistry.get_unit(:skill_unit, cell.cell_id)

    assert {:error, :not_found} =
             Manager.damage_targetable_cell(manager, cell.cell_id, 1, {:player, 1})
  end

  test "propagates a cell removed during damage calculation" do
    Mimic.copy(DamageCalculator)
    Mimic.copy(Passives)

    manager =
      start_supervised!(
        {Manager,
         name: nil,
         schedule_tick: fn _pid, _interval -> :ok end,
         unit_available?: fn _unit_type, _unit_id, _map_name -> true end}
      )

    :ok =
      Manager.register(
        manager,
        group(
          visible?: true,
          cells: [{10, 10}],
          state: %{cell_attrs: %{{10, 10} => targetable_cell_attrs()}}
        )
      )

    [cell] = Storage.get_cells_by_group(1)

    attacker = attacker()
    player = %FakePlayer{combatant: attacker, stats: attacker}

    stub(DamageCalculator, :calculate_damage, fn _attacker, _target ->
      :ok = Manager.destroy(manager, 1)
      {:ok, %{damage: 10, is_critical: false}}
    end)

    stub(Passives, :attack_procs, fn _player -> %{} end)

    assert {:error, :not_found} = Combat.execute_attack(attacker, player, cell.cell_id)
  end

  defp group do
    %Group{
      group_id: 1,
      skill_id: 0,
      skill_name: :fixture,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {10, 10},
      cells: [],
      next_tick_at: 0,
      expires_at: 1_000_000,
      interval: 1_000,
      visible?: false,
      state: %{}
    }
  end

  defp group(attrs), do: struct(group(), attrs)

  defp targetable_cell_attrs do
    %{
      hp: 10,
      max_hp: 10,
      flags: [:targetable],
      state: %{combat: %{def: 30, element: {:water, 1}}}
    }
  end

  defp attacker do
    Combatant.new!(%{
      unit_id: 1,
      unit_type: :player,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: %{
        atk: 1,
        def: 0,
        hit: 200,
        flee: 0,
        perfect_dodge: 0,
        matk: 0,
        mdef: 0,
        soft_mdef: 0
      },
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :player_human,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 500,
      position: {10, 9},
      map_name: "prontera"
    })
  end
end
