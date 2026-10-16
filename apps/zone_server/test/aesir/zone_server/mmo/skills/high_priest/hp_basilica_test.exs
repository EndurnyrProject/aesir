defmodule Aesir.ZoneServer.Mmo.Skills.HighPriest.HpBasilicaTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.HighPriest.HpBasilica
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.TrapTestHelper
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 36_301
  @ally_id 36_302
  @mob_id 36_303
  @boss_id 36_304
  @homunculus_id 36_305

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 40, 40)})
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
    Process.put({Manager, :server}, manager)

    caster = player(@caster_id)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_player(@caster_id, 20, 20, "prontera")
    %{caster: caster, manager: manager}
  end

  defp definition do
    {:ok, definition} = Catalog.by_name(:hp_basilica)
    definition
  end

  describe "renewal" do
    @describetag game_mode: :renewal

    test "definition: 3 s cast + 1 s fixed, 1 s delay, 30 s cooldown, no catalysts" do
      definition = definition()

      assert definition.target_type == :self
      assert definition.sp_cost == [40, 50, 60, 70, 80]
      assert definition.cast_time == List.duplicate(3_000, 5)
      assert definition.fixed_cast_time == List.duplicate(1_000, 5)
      assert definition.after_cast_delay == List.duplicate(1_000, 5)
      assert definition.cooldown == List.duplicate(30_000, 5)
      assert definition.duration == [60_000, 90_000, 120_000, 150_000, 180_000]
      assert definition.item_cost == []
    end

    test "casting applies the Basilica buff for the level's duration", %{caster: caster} do
      assert {:ok, ^caster} = HpBasilica.cast(caster, :self, 4, definition())

      entry = StatusStorage.get_status(:player, @caster_id, :sc_basilica_buff)
      assert entry.val1 == 4
      assert entry.expires_at - entry.started_at == 150_000
    end
  end

  describe "renewal cell sync" do
    @describetag game_mode: :renewal

    test "a player on a sanctuary cell is left alone", %{caster: caster} do
      :ok = Storage.insert(group(9_302, :hp_basilica, [{20, 20}], %{basilica: true}))

      assert :ok = Basilica.sync_cell_status(caster)

      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica)
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "definition: 5-9 s cast, 2-6 s delay, no cooldown, four catalysts" do
      definition = definition()

      assert definition.sp_cost == [80, 90, 100, 110, 120]
      assert definition.cast_time == [5_000, 6_000, 7_000, 8_000, 9_000]
      assert definition.after_cast_delay == [2_000, 3_000, 4_000, 5_000, 6_000]
      assert definition.duration == [20_000, 25_000, 30_000, 35_000, 40_000]

      assert definition.item_cost == [
               %{id: 715, amount: 1},
               %{id: 716, amount: 1},
               %{id: 717, amount: 1},
               %{id: 523, amount: 1}
             ]
    end
  end

  describe "pre-renewal sanctuary" do
    @describetag game_mode: :pre_renewal

    test "through the interpreter: creation spends SP and all four catalysts; the cancel needs none",
         %{caster: caster} do
      caster = %{
        caster
        | inventory:
            Map.new(Enum.with_index([715, 716, 717, 523]), fn {id, index} ->
              {index, %InventoryItem{nameid: id, amount: 1, equip: 0}}
            end),
          stats: %{
            caster.stats
            | current_state: %{caster.stats.current_state | sp: 500},
              progression: %{caster.stats.progression | learned_skills: %{362 => 1}}
          }
      }

      assert {:ok, anchored} = Interpreter.complete_cast(caster, 362, 1, :self)
      assert anchored.stats.current_state.sp == 420
      assert Inventory.held_amount(anchored.inventory, 717) == 0
      assert anchored.act_delay_until == 0
      assert StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)

      before = System.monotonic_time(:millisecond)
      anchored = %{anchored | act_delay_until: 0}

      assert {:ok, released} = Interpreter.complete_cast(anchored, 362, 1, :self)
      assert released.stats.current_state.sp == 420
      assert released.act_delay_until >= before + 2_000
      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)
    end

    test "refuses a wall inside the 7x7 area", %{caster: caster} do
      [{"prontera", map}] = :ets.lookup(EtsTable.table_for(:map_cache), "prontera")
      wall = MapData.set_cell(map, 23, 17, GatType.wall())
      :ets.insert(EtsTable.table_for(:map_cache), {"prontera", wall})

      assert {:error, :blocked_area} = HpBasilica.validate(caster, :self, 1, definition())
    end

    test "refuses another player or mob within 3 cells", %{caster: caster} do
      assert :ok = HpBasilica.validate(caster, :self, 1, definition())

      register_mob(@mob_id, [], {23, 21})

      assert {:error, :blocked_area} = HpBasilica.validate(caster, :self, 1, definition())
    end

    test "refuses a Land Protector cell", %{caster: caster} do
      :ok = Storage.insert(group(9_301, :sa_landprotector, [{20, 20}], %{land_protector: true}))

      assert {:error, :land_protector} = HpBasilica.validate(caster, :self, 1, definition())
    end

    test "places a 5x5 sanctuary and locks the caster to it", %{caster: caster} do
      assert {:ok, ^caster} = HpBasilica.cast(caster, :self, 3, definition())

      assert [group] = Storage.get_groups_by_caster(:player, @caster_id)
      assert Group.basilica?(group)
      assert length(group.cells) == 25
      assert {18, 18} in group.cells and {22, 22} in group.cells
      assert group.expires_at - group.created_at == 30_000

      assert %{val1: 3, val2: group_id} =
               StatusStorage.get_status(:player, @caster_id, :sc_basilica_caster)

      assert group_id == group.group_id
    end

    test "recasting ends the sanctuary and needs no catalysts", %{caster: caster} do
      definition = definition()
      assert length(HpBasilica.dynamic_item_cost(caster, :self, 1, definition)) == 4

      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition)

      assert HpBasilica.dynamic_item_cost(caster, :self, 1, definition) == []
      assert {:ok, ^caster} = HpBasilica.cast(caster, :self, 1, definition)
      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)
    end

    test "the cancel recast is instant, spends no SP, and keeps its delay",
         %{caster: caster} do
      definition = definition()

      assert %Cost{sp: 100} = HpBasilica.dynamic_cost(caster, :self, 3, definition)
      assert HpBasilica.dynamic_after_cast_delay(caster, :self, 3, definition) == 0

      assert HpBasilica.dynamic_cast_time(caster, :self, 3, definition) ==
               %{cast_time: 7_000, fixed_cast_time: 0}

      {:ok, _} = HpBasilica.cast(caster, :self, 3, definition)

      assert %Cost{sp: 0} = HpBasilica.dynamic_cost(caster, :self, 3, definition)

      assert HpBasilica.dynamic_after_cast_delay(caster, :self, 3, definition) == 4_000

      assert HpBasilica.dynamic_cast_time(caster, :self, 3, definition) ==
               %{cast_time: 0, fixed_cast_time: 0}

      register_mob(@mob_id, [], {21, 20})
      assert :ok = HpBasilica.validate(caster, :self, 3, definition)
    end

    test "grants non-enemies on it the status for the sanctuary's full lifetime, never the caster",
         %{caster: caster, manager: manager} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      place_player(@ally_id, {21, 20})

      :ok = Manager.tick(manager, group.next_tick_at)

      assert %{val3: group_id, val4: @caster_id} =
               entry =
               StatusStorage.get_status(:player, @ally_id, :sc_basilica)

      assert group_id == group.group_id
      assert entry.expires_at - entry.started_at == 20_000
      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica)
    end

    test "a homunculus that is no enemy is granted the status by the unit pass",
         %{caster: caster, manager: manager} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      homunculus = %{TrapTestHelper.homunculus(@homunculus_id, @caster_id) | x: 21, y: 20}

      :ok =
        UnitRegistry.register_unit(
          :homunculus,
          @homunculus_id,
          HomunculusState,
          homunculus,
          self()
        )

      :ok = SpatialIndex.add_unit(:homunculus, @homunculus_id, 21, 20, "prontera")

      :ok = Manager.tick(manager, group.next_tick_at)

      assert StatusStorage.has_status?(:homunculus, @homunculus_id, :sc_basilica)
    end

    test "destroying the field strips the status from units standing on its cells",
         %{caster: caster, manager: manager} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      place_player(@ally_id, {21, 20})
      :ok = Manager.tick(manager, group.next_tick_at)
      assert StatusStorage.has_status?(:player, @ally_id, :sc_basilica)

      register_mob(@mob_id, [], {19, 19})
      :ok = timer_grant(:mob, @mob_id, group)

      :ok = Manager.destroy(manager, group.group_id)

      refute StatusStorage.has_status?(:player, @ally_id, :sc_basilica)
      refute StatusStorage.has_status?(:mob, @mob_id, :sc_basilica)
      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)
      refute Storage.basilica?("prontera", 20, 20)
    end

    test "walking off releases a player through the cell sync but not a mob",
         %{caster: caster, manager: manager} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      ally = place_player(@ally_id, {21, 20})
      :ok = Manager.tick(manager, group.next_tick_at)
      register_mob(@mob_id, [], {19, 19})
      :ok = timer_grant(:mob, @mob_id, group)

      :ok = SpatialIndex.update_position(@ally_id, 30, 30, "prontera")
      :ok = Basilica.sync_cell_status(%{ally | x: 30, y: 30})
      :ok = SpatialIndex.update_unit_position(:mob, @mob_id, 30, 30, "prontera")
      :ok = Trigger.on_step({:mob, @mob_id}, "prontera", 19, 19, "prontera", 30, 30)

      refute StatusStorage.has_status?(:player, @ally_id, :sc_basilica)
      assert StatusStorage.has_status?(:mob, @mob_id, :sc_basilica)
    end

    test "a unit leaving a sanctuary cell does not run its on_out", %{caster: caster} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      register_mob(@mob_id, [], {19, 19})
      :ok = timer_grant(:mob, @mob_id, group)

      :ok = SpatialIndex.update_unit_position(:mob, @mob_id, 30, 30, "prontera")
      :ok = Trigger.on_step({:mob, @mob_id}, "prontera", 19, 19, "prontera", 30, 30)

      assert StatusStorage.has_status?(:mob, @mob_id, :sc_basilica)
    end

    test "an enemy boss on it is neither pushed nor granted the status",
         %{caster: caster, manager: manager} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      register_mob(@boss_id, [:boss], {21, 21})

      :ok = Manager.tick(manager, group.next_tick_at)

      assert {:ok, {21, 21, "prontera"}} = SpatialIndex.get_unit_position(:mob, @boss_id)
      refute StatusStorage.has_status?(:mob, @boss_id, :sc_basilica)
      refute_received {:"$gen_cast", {:movement, {:knockback, _, _, _, _, _}}}
    end

    test "each pass pushes an enemy 2 cells straight back and grants a non-enemy the status",
         %{caster: caster, manager: manager} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)
      place_player(@ally_id, {19, 20})
      register_mob(@mob_id, [], {21, 21})

      :ok = Manager.tick(manager, group.next_tick_at)

      assert_received {:"$gen_cast", {:movement, {:knockback, 21, 21, "prontera", 21, 23}}}
      refute_received {:"$gen_cast", {:movement, {:knockback, _, _, _, _, _}}}
      refute StatusStorage.has_status?(:mob, @mob_id, :sc_basilica)
      assert StatusStorage.has_status?(:player, @ally_id, :sc_basilica)
    end

    test "the cell sync grants a player stepping on indefinitely and releases one stepping off",
         %{caster: caster} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      ally = place_player(@ally_id, {21, 20})

      :ok = Basilica.sync_cell_status(ally)

      assert %{val4: 0, expires_at: nil} =
               StatusStorage.get_status(:player, @ally_id, :sc_basilica)

      :ok = Basilica.sync_cell_status(%{ally | x: 30, y: 30})

      refute StatusStorage.has_status?(:player, @ally_id, :sc_basilica)
    end

    test "the cell sync ends the sanctuary of a caster moved off it", %{caster: caster} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      assert StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)

      :ok = Basilica.sync_cell_status(%{caster | x: 30, y: 30})

      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)
    end

    test "ending the field releases the caster lock", %{caster: caster} do
      {:ok, _} = HpBasilica.cast(caster, :self, 1, definition())
      [group] = Storage.get_groups_by_caster(:player, @caster_id)

      assert :ok = HpBasilica.on_expire(group)
      refute StatusStorage.has_status?(:player, @caster_id, :sc_basilica_caster)
    end
  end

  test "a mob caster is refused", %{caster: caster} do
    mob = struct(MobState, instance_id: 1)

    assert {:error, :player_only} = HpBasilica.cast(mob, :self, 1, definition())
    refute StatusStorage.has_status?(:player, caster.character_id, :sc_basilica_buff)
  end

  defp group(group_id, skill_name, cells, state) do
    %Group{
      group_id: group_id,
      skill_id: 1,
      skill_name: skill_name,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: hd(cells),
      cells: cells,
      next_tick_at: 0,
      expires_at: 0,
      interval: 1_000,
      state: state
    }
  end

  defp place_player(id, {x, y}) do
    state = %{player(id) | x: x, y: y}
    :ok = UnitRegistry.register_player(state, self())
    :ok = SpatialIndex.add_player(id, x, y, "prontera")
    state
  end

  # No path grants an enemy mob the timer status, so the test gives it one.
  defp timer_grant(type, id, %Group{} = group) do
    StatusInterpreter.apply_status(type, id, :sc_basilica,
      val1: 0,
      val3: group.group_id,
      val4: @caster_id,
      duration: 20_000,
      caster_id: @caster_id,
      source_type: :player
    )
  end

  defp register_mob(id, modes, {x, y}) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 400,
      attack_delay: 1_872,
      attack_motion: 672,
      client_attack_motion: 672,
      damage_motion: 480,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: x, y: y}
    }

    state = %{MobState.new(id, mob_data, spawn_ref, "prontera", x, y) | dir: 0}
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, x, y, "prontera")
    state
  end

  defp player(id) do
    state = character_player(id)
    put_in(state.stats.current_state.hp, 100)
  end

  defp character_player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "HP #{id}",
      last_map: "prontera",
      last_x: 20,
      last_y: 20,
      sex: "F",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4009
    })
  end
end
