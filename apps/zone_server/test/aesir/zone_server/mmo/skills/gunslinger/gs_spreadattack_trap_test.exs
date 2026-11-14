defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSpreadattackTrapTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSpreadattack
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private

  test "spread_trap_test: a targetable enemy trap takes splash damage" do
    map = "spread_trap"
    :ets.insert(EtsTable.table_for(:map_cache), {map, MapData.new(map, 40, 40)})
    now = System.monotonic_time(:millisecond)

    manager =
      start_supervised!(
        {Manager,
         name: nil,
         clock: fn -> now end,
         schedule_tick: fn _, _ -> :ok end,
         unit_available?: fn _, _, _ -> true end}
      )

    Process.put({Manager, :server}, manager)

    player =
      PlayerState.new(%Character{
        id: 1,
        account_id: 1,
        name: "TrapOwner",
        last_map: map,
        last_x: 8,
        last_y: 8,
        class: 11,
        sex: "F",
        base_level: 20,
        job_level: 20,
        hp: 100,
        sp: 100,
        str: 20,
        dex: 20,
        vit: 10,
        agi: 10,
        int: 10,
        luk: 0
      })

    UnitRegistry.register_unit(:player, 1, PlayerState, player, self())
    assert {:ok, group} = Unit.place(player, :ht_landmine, 1, {9, 8})
    [cell] = Storage.get_cells_by_group(group.group_id)

    {:ok, data} = Mobs.by_id(1002)

    mob =
      %MobState{
        instance_id: 3,
        mob_id: 1002,
        mob_data: data,
        spawn_ref: nil,
        x: 8,
        y: 8,
        map_name: map,
        hp: 55,
        sp: 1,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 55, max_sp: 1)

    UnitRegistry.register_unit(:mob, 3, MobState, mob, self())
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)

    assert {:ok, ^mob} =
             GsSpreadattack.cast(
               mob,
               {:unit, {:skill_unit, cell.cell_id}},
               1,
               GsSpreadattack.definition()
             )

    assert Storage.get_cell(cell.cell_id).hp < 3_500
  end
end
