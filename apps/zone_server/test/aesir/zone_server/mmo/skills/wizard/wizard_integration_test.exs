defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WizardIntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Net.EstimationResult
  alias Aesir.Net.SkillUnitSnapshot
  alias Aesir.Net.SkillUnitSpawn
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.Cell, as: MapCell
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.SkillTree

  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzEstimation
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzIcewall
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzJupitel
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzMeteor
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmire
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightblaster
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzWaterball

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule FieldEntity do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  defmodule PacketSink do
    use GenServer

    def start_link(test_pid, character_id),
      do: GenServer.start_link(__MODULE__, {test_pid, character_id})

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_cast({:send_packet, packet}, {test_pid, character_id} = state) do
      send(test_pid, {:packet, character_id, packet})
      {:noreply, state}
    end
  end

  @map "prontera"
  @caster_id 1_000
  @target_id 2_000

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    :ok = Catalog.reload()
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 300, 300)})

    manager =
      start_supervised!({Manager, name: nil, schedule_tick: fn _pid, _interval -> :ok end})

    Process.put({Manager, :server}, manager)
    allow(Catalog, self(), manager)
    :ok = StatusInterpreter.init()

    %{manager: manager}
  end

  test "ground Wizard fields deliver visibility protocol only to visible recipients and clean up",
       %{
         manager: manager
       } do
    caster = caster()
    register_player(1_001, %{caster | character_id: 1_001}, 151, 150)
    register_player(1_002, %{caster | character_id: 1_002}, 250, 250)

    assert {:ok, ^caster} = WzMeteor.cast(caster, {:ground, 150, 150}, 1, WzMeteor.definition())

    assert_receive {:packet, 1_001, %SkillUnitSpawn{group: %{group_id: meteor_id, cells: [_]}}}
    refute_receive {:packet, 1_002, %SkillUnitSpawn{group: %{group_id: ^meteor_id}}}
    assert %SkillUnitSnapshot{groups: [%{group_id: ^meteor_id}]} = SkillUnit.snapshot(@map)

    assert MapSet.new([meteor_id]) == Manager.snapshot_for(manager, 1_001, @map, 151, 150, 1)
    assert_receive {:packet, 1_001, %SkillUnitSnapshot{groups: [%{group_id: ^meteor_id}]}}

    meteor = Storage.get(meteor_id)
    assert meteor.visible?

    assert :ok = Manager.tick(manager, meteor.expires_at)
    assert Storage.get(meteor_id) == nil
    assert_receive {:packet, 1_001, %{group_id: ^meteor_id}}
    refute_receive {:packet, 1_002, %{group_id: ^meteor_id}}
  end

  test "Quagmire reconciles a real occupant and releases it after the final overlapping field", %{
    manager: manager
  } do
    :ok = UnitRegistry.register_unit(:player, @caster_id, __MODULE__, caster(), self())

    :ok =
      UnitRegistry.register_unit(
        :mob,
        @target_id,
        FieldEntity,
        estimation_target(),
        self()
      )

    :ok = SpatialIndex.add_unit(:mob, @target_id, 120, 120, @map)

    caster = caster()

    assert {:ok, ^caster} =
             WzQuagmire.cast(caster, {:ground, 120, 120}, 1, WzQuagmire.definition())

    [first] = Storage.all()
    assert :ok = Manager.trigger(manager, first.group_id, {:mob, @target_id}, :on_touch)
    assert StatusStorage.has_status?(:mob, @target_id, :sc_quagmire)

    assert {:ok, ^caster} =
             WzQuagmire.cast(caster, {:ground, 120, 120}, 5, WzQuagmire.definition())

    [second, ^first] = Storage.all() |> Enum.sort_by(& &1.level, :desc)

    assert :ok = Manager.destroy(manager, first.group_id)
    assert StatusStorage.has_status?(:mob, @target_id, :sc_quagmire)

    assert :ok = Manager.destroy(manager, second.group_id)
    refute StatusStorage.has_status?(:mob, @target_id, :sc_quagmire)
  end

  test "Water Ball turns real water into an invisible sequence rather than visible field protocol" do
    map = MapData.new(@map, 300, 300) |> MapData.set_cell(120, 120, GatType.water())
    :ets.insert(EtsTable.table_for(:map_cache), {@map, map})
    Mimic.copy(Combat)

    caster = caster()
    register_player(@caster_id, caster, 120, 120)
    register_mob(@target_id, %{estimation_target() | x: 121, y: 120})

    expect(Combat, :resolve_combatant, fn @target_id -> {:ok, %{unit_type: :mob}} end)

    assert {:ok, ^caster} =
             WzWaterball.cast(caster, {:unit, @target_id}, 1, WzWaterball.definition())

    [sequence] = Storage.all()

    refute sequence.visible?
    [sequence_cell | _] = Storage.get_cells_by_group(sequence.group_id)
    assert %SkillUnitSnapshot{groups: []} = SkillUnit.snapshot(@map)

    expect(Combat, :resolve_combatant, fn @caster_id -> {:ok, %{unit_id: @caster_id}} end)

    expect(Combat, :apply_skill_unit_damage, fn %{unit_id: @caster_id},
                                                :mob,
                                                @target_id,
                                                86,
                                                1,
                                                :water,
                                                130 ->
      :ok
    end)

    allow(Combat, self(), Process.get({Manager, :server}))

    assert :ok = Manager.tick(Process.get({Manager, :server}), sequence.next_tick_at)
    assert Storage.get_cell(sequence_cell.cell_id) == nil

    assert :ok =
             Manager.tick(
               Process.get({Manager, :server}),
               sequence.next_tick_at + sequence.interval
             )

    assert Storage.get(sequence.group_id) == nil
  end

  test "a direct Wizard spell queues its impact through the active cast boundary" do
    Mimic.copy(Combat)
    stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{unit_type: :mob}} end)

    caster = caster()

    assert {:ok, ^caster} = WzJupitel.cast(caster, {:unit, @target_id}, 3, WzJupitel.definition())
    assert_receive {:jupitel_impact, %{target: {:mob, @target_id}, skill_level: 3}}
  end

  test "Ice Wall creates targetable movement and projectile terrain, decays it, and restores the cell",
       %{
         manager: manager
       } do
    caster = caster()
    register_player(@caster_id, caster, 120, 120)

    assert {:ok, ^caster} = WzIcewall.cast(caster, {:ground, 150, 150}, 3, WzIcewall.definition())
    [wall] = Storage.all()
    [cell | _] = Storage.get_cells_by_group(wall.group_id)

    assert wall.visible?
    assert length(Storage.get_cells_by_group(wall.group_id)) == 5
    assert {:ok, ^cell} = Manager.targetable_cell(manager, cell.cell_id)
    refute MapCell.traversable?(@map, cell.x, cell.y)
    assert MapCell.blocks_projectiles?(@map, cell.x, cell.y)

    assert :ok = Manager.tick(manager, wall.next_tick_at)
    assert %{hp: 750} = Storage.get_cell(cell.cell_id)

    assert :ok = Manager.destroy(manager, wall.group_id)
    assert Storage.get_cells_by_group(wall.group_id) == []
    assert MapCell.traversable?(@map, cell.x, cell.y)
    refute MapCell.blocks_projectiles?(@map, cell.x, cell.y)
  end

  test "Estimation reaches only its caster and rejects an unavailable target" do
    target = estimation_target()
    caster = caster()

    register_unit(:mob, @target_id, target)
    register_player(@caster_id, caster, 120, 120)
    register_player(1_001, %{caster | character_id: 1_001}, 121, 120)

    assert {:ok, ^caster} =
             WzEstimation.cast(caster, {:unit, @target_id}, 1, WzEstimation.definition())

    assert_receive {:packet, @caster_id, %EstimationResult{target_id: @target_id}}
    refute_receive {:packet, 1_001, %EstimationResult{target_id: @target_id}}

    assert {:error, :invalid_target} =
             WzEstimation.validate(caster, {:unit, @caster_id}, 1, WzEstimation.definition())
  end

  test "Wizard platinum skills remain registered but cannot be learned from normal points" do
    {:ok, wizard_id} = AvailableJobs.job_name_to_id(:wizard)

    progression = %PlayerProgression{job_id: wizard_id, skill_point: 1, learned_skills: %{}}

    for skill_name <- [:wz_estimation, :wz_sightblaster] do
      {:ok, definition} = Catalog.by_name(skill_name)
      assert {:error, :not_in_tree} = SkillTree.can_learn(progression, definition.id)
    end
  end

  test "the twelve normal Wizard skills learn in prerequisite order" do
    :ok = SkillTree.reload()
    {:ok, wizard_id} = AvailableJobs.job_name_to_id(:wizard)

    learned_skills =
      for skill_name <- [
            :mg_firewall,
            :mg_lightningbolt,
            :mg_thunderstorm,
            :mg_coldbolt,
            :mg_stonecurse,
            :mg_frostdiver,
            :mg_napalmbeat,
            :mg_sight
          ],
          into: %{} do
        {:ok, definition} = Catalog.by_name(skill_name)
        {definition.id, 1}
      end

    {:ok, meteor} = Catalog.by_name(:wz_meteor)

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(
               %PlayerProgression{
                 job_id: wizard_id,
                 skill_point: 50,
                 learned_skills: learned_skills
               },
               meteor.id
             )

    learned_skills =
      [
        {:wz_firepillar, 1},
        {:wz_sightrasher, 2},
        {:wz_meteor, 1},
        {:wz_jupitel, 5},
        {:wz_vermilion, 1},
        {:wz_waterball, 1},
        {:wz_icewall, 1},
        {:wz_frostnova, 1},
        {:wz_stormgust, 1},
        {:wz_earthspike, 3},
        {:wz_heavendrive, 1},
        {:wz_quagmire, 1}
      ]
      |> Enum.reduce(learned_skills, fn {skill_name, levels}, learned ->
        {:ok, definition} = Catalog.by_name(skill_name)

        Enum.reduce(1..levels, learned, fn _level, learned ->
          progression = %PlayerProgression{
            job_id: wizard_id,
            skill_point: 50,
            learned_skills: learned
          }

          assert :ok = SkillTree.can_learn(progression, definition.id)
          Map.update(learned, definition.id, 1, &(&1 + 1))
        end)
      end)

    assert Enum.count(learned_skills, fn {skill_id, _level} ->
             {:ok, definition} = Catalog.by_id(skill_id)
             String.starts_with?(Atom.to_string(definition.name), "wz_")
           end) == 12
  end

  test "Sight Blaster arms, hits on contact, and consumes its status" do
    # `ensure_living_target` (and `on_contact`, which re-fetches the caster
    # from the registry) need a real living `PlayerState`, not a bare map.
    caster = %PlayerState{
      character_id: @caster_id,
      x: 120,
      y: 120,
      map_name: @map,
      movement_state: :standing,
      action_state: :idle,
      stats: %{current_state: %{hp: 100}}
    }

    target = %{instance_id: @target_id, x: 123, y: 120, map_name: @map, movement_state: :moving}

    register_unit(:player, @caster_id, caster)
    register_unit(:mob, @target_id, target)
    Mimic.copy(Combat)

    expect(Combat, :execute_magic_attack, fn ^caster,
                                             @target_id,
                                             [
                                               skill_id: 1006,
                                               skill_level: 1,
                                               skill_ratio: 600,
                                               element: :fire
                                             ] ->
      :ok
    end)

    expect(Combat, :knockback, fn :mob, @target_id, 120, 120, 3 -> {:ok, {124, 120}} end)

    assert {:ok, ^caster} = WzSightblaster.cast(caster, :self, 1, WzSightblaster.definition())

    assert StatusStorage.has_status?(:player, @caster_id, :sc_sightblaster)
    assert :ok = Movement.set_position(:mob, @target_id, %{target | x: 121}, @map)
    refute StatusStorage.has_status?(:player, @caster_id, :sc_sightblaster)
  end

  defp caster do
    %PlayerState{character_id: @caster_id, map_name: @map, x: 120, y: 120}
  end

  defp register_player(character_id, state, x, y) do
    {:ok, sink} = PacketSink.start_link(self(), character_id)
    :ok = UnitRegistry.register_unit(:player, character_id, __MODULE__, state, sink)
    :ok = SpatialIndex.add_unit(:player, character_id, x, y, @map)
  end

  defp register_unit(unit_type, unit_id, state) do
    :ok = UnitRegistry.register_unit(unit_type, unit_id, FieldEntity, state, nil)
    :ok = SpatialIndex.add_unit(unit_type, unit_id, state.x, state.y, state.map_name)
  end

  defp register_mob(unit_id, state) do
    :ok = UnitRegistry.register_unit(:mob, unit_id, FieldEntity, state, nil)
    :ok = SpatialIndex.add_unit(:mob, unit_id, state.x, state.y, state.map_name)
  end

  defp estimation_target do
    %Aesir.ZoneServer.Unit.Mob.MobState{
      instance_id: @target_id,
      mob_id: 1,
      mob_data: %Aesir.ZoneServer.Mmo.MobManagement.MobDefinition{
        id: 1,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: 1,
        hp: 100,
        def: 1,
        mdef: 1,
        stats: %{},
        attack_range: 1,
        size: :medium,
        race: :formless,
        element: {:neutral, 1},
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 400
      },
      x: 120,
      y: 120,
      map_name: @map,
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawn_ref: %Aesir.ZoneServer.Mmo.MobManagement.MobSpawn{
        mob: 1,
        amount: 1,
        respawn_time: 1_000,
        spawn_area: %Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea{x: 120, y: 120}
      },
      spawned_at: 0
    }
  end
end
