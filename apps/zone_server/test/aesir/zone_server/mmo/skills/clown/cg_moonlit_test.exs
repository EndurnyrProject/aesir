defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgMoonlitTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgMoonlit
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 20, 20)})
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
    Process.put({Manager, :server}, manager)
    caster = player(17, 4020, 10, 2, 1901)
    register(caster)
    %{caster: caster}
  end

  test "entry skips performers and pushes a mob along its facing", %{caster: caster} do
    mob = mob()
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob, self())

    group = %Group{
      group_id: 1,
      skill_name: :cg_moonlit,
      state: %{performance: %{performers: [17]}}
    }

    expect(Knockback, :knockback, fn :mob, 42, 10, 10, 2 -> :ok end)
    assert {:ok, ^group} = CgMoonlit.on_touch(group, {:player, caster.character_id})
    assert {:ok, ^group} = CgMoonlit.on_touch(group, {:mob, 42})
  end

  test "a wall anywhere in the nine-by-nine box refuses casting", %{caster: caster} do
    register(player(18, 4021, 11, 2, 1960))
    map = MapData.new("prontera", 20, 20) |> MapData.set_cell(14, 14, GatType.wall())
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", map})

    assert {:error, :blocked_by_wall} =
             CgMoonlit.validate(caster, :self, 2, CgMoonlit.definition())
  end

  @tag game_mode: :renewal
  test "renewal solo cast roots only the caster with level-based upkeep and no fatigue", %{
    caster: caster
  } do
    assert {:ok, _} = CgMoonlit.cast(caster, :self, 2, CgMoonlit.definition())

    assert %{state: %{root: :always, upkeep: 10, upkeep_sp: 8}} =
             StatusStorage.get_status(:player, 17, :sc_dancing)

    [group] = Storage.get_groups_by_caster(:player, 17)
    assert group.state.performance.performers == [17]
    assert length(group.cells) == 81
    refute StatusStorage.has_status?(:player, 17, :sc_ensemblefatigue)
  end

  test "paired upkeep uses the averaged field level", %{caster: caster} do
    caster = put_in(caster.stats.progression.learned_skills, %{395 => 5})
    register(caster)
    register(player(18, 4021, 11, 1, 1960))
    assert {:ok, _} = CgMoonlit.cast(caster, :self, 5, CgMoonlit.definition())
    [group] = Storage.get_groups_by_caster(:player, 17)
    assert group.level == 3

    for id <- [17, 18] do
      assert %{state: %{upkeep_sp: 12}} = StatusStorage.get_status(:player, id, :sc_dancing)
    end
  end

  @tag game_mode: :pre_renewal
  test "classic cast requires an adjacent partner", %{caster: caster} do
    assert {:error, :ensemble_partner_required} =
             CgMoonlit.cast(caster, :self, 2, CgMoonlit.definition())
  end

  test "the first interval sweeps existing occupants exactly once", %{caster: caster} do
    assert {:ok, _} =
             Field.start(caster, CgMoonlit.definition(), 2, nil, [],
               kind: :ensemble,
               root: :always,
               upkeep: 10,
               upkeep_sp: 8,
               layout_radius: 4
             )

    [group] = Storage.get_groups_by_caster(:player, 17)
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(), self())
    :ok = SpatialIndex.add_unit(:mob, 42, 11, 10, "prontera")
    expect(Knockback, :knockback, fn :mob, 42, 10, 10, 2 -> :ok end)
    assert {:ok, swept} = CgMoonlit.on_interval(group, group.created_at + 1000)
    assert swept.state.performance.moonlit_swept
    assert {:ok, _} = CgMoonlit.on_interval(swept, group.created_at + 2000)
  end

  test "the initial sweep reaches the far corner of the field", %{caster: caster} do
    assert {:ok, _} =
             Field.start(caster, CgMoonlit.definition(), 2, nil, [],
               kind: :ensemble,
               root: :always,
               upkeep: 10,
               upkeep_sp: 8,
               layout_radius: 4
             )

    [group] = Storage.get_groups_by_caster(:player, 17)
    corner_mob = %{mob() | x: 14, y: 14}
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, corner_mob, self())
    :ok = SpatialIndex.add_unit(:mob, 42, 14, 14, "prontera")
    expect(Knockback, :knockback, fn :mob, 42, 13, 14, 2 -> :ok end)
    assert {:ok, _} = CgMoonlit.on_interval(group, group.created_at + 1000)
  end

  defp player(id, job, x, level, weapon) do
    state =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Moonlit #{id}",
        class: job,
        base_level: 80,
        job_level: 50,
        party_id: 2,
        sex: "M",
        last_map: "prontera",
        last_x: x,
        last_y: 10,
        str: 10,
        agi: 10,
        vit: 0,
        int: 10,
        dex: 10,
        luk: 0
      })

    state = put_in(state.stats.progression.learned_skills, %{395 => level})
    put_in(state.stats.equipment.right_hand, weapon)
  end

  defp register(player) do
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(player.character_id, player.x, player.y, player.map_name)
  end

  defp mob do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 11, y: 10, xs: 0, ys: 0}
    }

    %{MobState.new(42, definition, spawn, "prontera", 11, 10) | dir: 6}
  end
end
