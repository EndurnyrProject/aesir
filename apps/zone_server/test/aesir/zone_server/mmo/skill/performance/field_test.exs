defmodule Aesir.ZoneServer.Mmo.Skill.Performance.FieldTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {"prontera", MapData.new("prontera", 20, 20)})
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
    Process.put({Manager, :server}, manager)
    :ok
  end

  @tag game_mode: :pre_renewal
  test "field start places a 7x7 per-cell song and locks only the performer" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    assert {:ok, remembered} =
             Field.start(caster, definition, 5, :sc_whistle, [val2: 25],
               kind: :song,
               reach: :everyone,
               upkeep: 5,
               linger_ms: 20_000,
               lesson_level: 10
             )

    assert remembered.last_song == %{skill_id: definition.id, level: 5}
    assert [group] = Storage.get_groups_by_caster(:player, 17)
    assert group.center == {10, 10}
    assert length(group.cells) == 49
    assert group.expires_at - group.created_at == 60_000
    assert group.unit_range == 0
    skill_id = definition.id

    assert %{val1: ^skill_id, val2: group_id, val3: 10, val4: nil} =
             StatusStorage.get_status(:player, 17, :sc_dancing)

    assert group_id == group.group_id
    assert Group.follows_caster?(group)
    refute StatusStorage.has_status?(:player, 17, :sc_whistle)

    assert {:error, :already_performing} =
             Field.start(caster, definition, 5, :sc_whistle, [],
               kind: :song,
               upkeep: 5,
               linger_ms: 20_000
             )
  end

  @tag game_mode: :pre_renewal
  test "an ensemble field stays put and pairs both performers' locks" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = UnitRegistry.register_player(player(18), self())
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    {:ok, _} =
      Field.start(caster, definition, 5, :sc_whistle, [],
        kind: :ensemble,
        upkeep: 5,
        linger_ms: 0,
        partners: [18]
      )

    [group] = Storage.get_groups_by_caster(:player, 17)
    refute Group.follows_caster?(group)
    assert %{val4: 18} = StatusStorage.get_status(:player, 17, :sc_dancing)
    assert %{val4: 17} = StatusStorage.get_status(:player, 18, :sc_dancing)
  end

  @tag game_mode: :pre_renewal
  test "a refused performer lock keeps the field and does not lock the partner" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_unit(:player, 17, 10, 10, "prontera")
    :ok = UnitRegistry.register_player(player(18), self())
    :ok = SpatialIndex.add_unit(:player, 18, 11, 10, "prontera")
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    expect(StatusInterpreter, :apply_status, fn :player, 17, :sc_dancing, _params ->
      {:error, :status_not_allowed}
    end)

    assert {:ok, remembered} =
             Field.start(caster, definition, 5, :sc_whistle, [],
               kind: :song,
               upkeep: 5,
               linger_ms: 20_000,
               partners: [18]
             )

    assert remembered.last_song == %{skill_id: definition.id, level: 5}
    assert [_group] = Storage.get_groups_by_caster(:player, 17)
    refute StatusStorage.has_status?(:player, 17, :sc_dancing)
    refute StatusStorage.has_status?(:player, 18, :sc_dancing)
  end

  @tag game_mode: :pre_renewal
  test "field reach includes the performer, never placed on its own song; a dissonant cell grants nothing; expiry unlocks" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_unit(:player, 17, 10, 10, "prontera")
    :ok = UnitRegistry.register_player(player(18), self())
    :ok = SpatialIndex.add_unit(:player, 18, 11, 10, "prontera")
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    {:ok, _} =
      Field.start(caster, definition, 5, :sc_whistle, [],
        kind: :song,
        upkeep: 5,
        linger_ms: 20_000
      )

    [group] = Storage.get_groups_by_caster(:player, 17)

    support = Field.field_support(group)
    assert support.target?.({:player, 17})
    assert support.target?.({:player, 18})
    assert support.linger_ms == 20_000
    assert support.params[:caster_id] == 17

    :ok = Storage.insert(%{group | group_id: 9_002, caster_id: 20, cells: [{11, 10}]})
    assert Field.field_support(group).target?.({:player, 18})
    assert :skipped = FieldSupport.onplace(group, {:player, 18})
    assert :skipped = FieldSupport.onplace(group, {:player, 17})
    assert :ok = Field.on_expire(group)
    refute StatusStorage.has_status?(:player, 17, :sc_dancing)
  end

  @tag game_mode: :pre_renewal
  test "a monster performs a song field as its only performer and is unlocked when it ends" do
    mob =
      %MobState{
        instance_id: 42,
        mob_id: 1002,
        mob_data: %MobDefinition{
          id: 1002,
          aegis_name: "PORING",
          name: "Poring",
          level: 1,
          hp: 100,
          stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
          attack_range: 1,
          size: :medium,
          race: :plant,
          element: {:water, 1},
          walk_speed: 400,
          attack_delay: 1_000,
          attack_motion: 500,
          client_attack_motion: 500,
          damage_motion: 400,
          class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([]),
          modes: []
        },
        spawn_ref: nil,
        x: 10,
        y: 10,
        map_name: "prontera",
        hp: 100,
        sp: 1,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 100, max_sp: 1)

    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob, self())
    {:ok, definition} = Catalog.by_name(:ba_dissonance)

    assert {:ok, ^mob} =
             Field.start(mob, definition, 5, nil, [],
               kind: :song,
               reach: :enemy,
               upkeep: 3,
               linger_ms: 0,
               tick: :dissonance
             )

    assert [group] = Storage.get_groups_by_caster(:mob, 42)
    assert group.state.performance.performers == []
    assert Group.follows_caster?(group)
    group_id = group.group_id
    assert %{val2: ^group_id} = StatusStorage.get_status(:mob, 42, :sc_dancing)
    refute Field.field_support(group).target?.({:mob, 42})

    assert {:error, :already_performing} =
             Field.start(mob, definition, 5, nil, [], kind: :song, upkeep: 3, linger_ms: 0)

    assert :ok = Field.on_expire(group)
    refute StatusStorage.has_status?(:mob, 42, :sc_dancing)
  end

  @tag game_mode: :pre_renewal
  test "a unit standing on a Basilica cell receives no song status" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_unit(:player, 17, 10, 10, "prontera")
    :ok = UnitRegistry.register_player(player(18), self())
    :ok = SpatialIndex.add_unit(:player, 18, 11, 10, "prontera")
    :ok = UnitRegistry.register_player(player(19), self())
    :ok = SpatialIndex.add_unit(:player, 19, 9, 10, "prontera")
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    {:ok, _} =
      Field.start(caster, definition, 5, :sc_whistle, [],
        kind: :song,
        upkeep: 5,
        linger_ms: 20_000
      )

    [group] = Storage.get_groups_by_caster(:player, 17)

    :ok =
      Storage.insert(%Group{
        group_id: 9_001,
        skill_id: 362,
        skill_name: :hp_basilica,
        level: 1,
        caster_id: 20,
        caster_type: :player,
        map_name: "prontera",
        center: {11, 10},
        cells: [{11, 10}],
        next_tick_at: 0,
        expires_at: 0,
        interval: 300,
        state: %{basilica: true}
      })

    support = Field.field_support(group)
    assert support.target?.({:player, 18})
    refute support.grants?.({:player, 18})
    assert support.grants?.({:player, 19})
  end

  @tag game_mode: :pre_renewal
  test "reach can select party members, the performer included, or enemies" do
    caster = %{player(17) | party_id: 2}
    ally = %{player(18) | party_id: 2}
    stranger = %{player(19) | party_id: 3}

    for state <- [caster, ally, stranger] do
      :ok = UnitRegistry.register_player(state, self())
      :ok = SpatialIndex.add_unit(:player, state.character_id, 10, 10, "prontera")
    end

    mob =
      %MobState{
        instance_id: 42,
        mob_id: 1002,
        mob_data: Aesir.TestMob.definition(),
        spawn_ref: nil,
        x: 10,
        y: 10,
        map_name: "prontera",
        hp: 100,
        sp: 0,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, 42, 10, 10, "prontera")
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    {:ok, _} =
      Field.start(caster, definition, 5, :sc_whistle, [],
        kind: :song,
        upkeep: 5,
        linger_ms: 20_000
      )

    [group] = Storage.get_groups_by_caster(:player, 17)

    party = put_in(group.state.performance.reach, :party) |> Field.field_support()
    assert party.target?.({:player, 18})
    refute party.target?.({:player, 19})
    assert party.target?.({:player, 17})

    enemy = put_in(group.state.performance.reach, :enemy) |> Field.field_support()
    assert enemy.target?.({:mob, 42})
    refute enemy.target?.({:player, 18})
  end

  test "renewal performs through the unchanged snapshot with only snapshot options" do
    Mimic.copy(Snapshot)
    stub(GameMode, :mode, fn -> :renewal end)
    caster = player(17)
    {:ok, definition} = Catalog.by_name(:ba_whistle)
    test_pid = self()

    stub(Snapshot, :snapshot, fn ^caster, ^definition, 5, :sc_whistle, [val2: 25], opts ->
      send(test_pid, {:snapshot_opts, opts})
      {:ok, caster}
    end)

    assert {:ok, ^caster} =
             Performance.perform(caster, definition, 5, :sc_whistle, [val2: 25],
               kind: :song,
               upkeep: 5,
               scope: :party,
               radius: 15
             )

    assert_received {:snapshot_opts, [scope: :party, radius: 15]}
  end

  test "field roots and upkeep amount are stored on every performer's lock" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = UnitRegistry.register_player(player(18), self())
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    assert {:ok, _} =
             Field.start(caster, definition, 5, nil, [],
               kind: :ensemble,
               upkeep: 10,
               upkeep_sp: 8,
               linger_ms: 0,
               root: :always,
               partners: [18]
             )

    for id <- [17, 18] do
      assert %{state: %{root: :always, upkeep_sp: 8}} =
               StatusStorage.get_status(:player, id, :sc_dancing)

      refute StatusInterpreter.can_move?(:player, id)
    end
  end

  test "default roots distinguish ensemble fields from solo songs" do
    for {id, kind, root} <- [{17, :ensemble, :ensemble}, {18, :song, :none}] do
      caster = player(id)
      :ok = UnitRegistry.register_player(caster, self())
      {:ok, definition} = Catalog.by_name(:ba_whistle)

      assert {:ok, _} =
               Field.start(caster, definition, 5, nil, [], kind: kind, upkeep: 5, linger_ms: 0)

      assert %{state: %{root: ^root, upkeep_sp: 1}} =
               StatusStorage.get_status(:player, id, :sc_dancing)
    end
  end

  test "party-or-guild reach accepts the performer, a party member, guildmate and ally but not a stranger" do
    Mimic.copy(Relations)
    stub(Relations, :allied?, fn a, b -> {a, b} == {10, 20} end)
    caster = %{player(17) | party_id: 2, guild_id: 10}

    targets = [
      %{player(18) | party_id: 2},
      %{player(19) | guild_id: 10},
      %{player(20) | guild_id: 20},
      %{player(21) | guild_id: 30}
    ]

    for p <- [caster | targets] do
      :ok = UnitRegistry.register_player(p, self())
      :ok = SpatialIndex.add_unit(:player, p.character_id, p.x, p.y, p.map_name)
    end

    {:ok, definition} = Catalog.by_name(:ba_whistle)

    assert {:ok, _} =
             Field.start(caster, definition, 5, :sc_whistle, [],
               kind: :ensemble,
               upkeep: 5,
               linger_ms: 0,
               reach: :party_or_guild
             )

    [group] = Storage.get_groups_by_caster(:player, 17)
    support = Field.field_support(group)
    for id <- [18, 19, 20], do: assert(support.target?.({:player, id}))
    refute support.target?.({:player, 21})
    assert support.target?.({:player, 17})
  end

  @dissonance %{skill_id: 317, interval: 3_000, no_overlap: true}

  @tag game_mode: :pre_renewal
  test "a buff song cell is inert alone and strikes as Dissonance at the song's level when another song covers it" do
    test_pid = self()

    stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
      send(test_pid, {:hit, target, opts[:skill_id], opts[:skill_level]})
      :ok
    end)

    :ok = UnitRegistry.register_player(player(17), self())
    :ok = UnitRegistry.register_player(player(18, 13), self())
    register_mob(42, 11, 10)
    {:ok, whistle} = Catalog.by_name(:ba_whistle)

    {:ok, _} =
      Field.start(player(17), whistle, 5, :sc_whistle, [],
        kind: :song,
        upkeep: 5,
        linger_ms: 20_000
      )

    [group] = Storage.get_groups_by_caster(:player, 17)

    assert Field.cell_profile(group, {11, 10}) == :none
    assert Field.unit_targets(group, {11, 10}, [{:mob, 42}]) == []

    {:ok, _} =
      Field.start(player(18, 13), whistle, 1, :sc_whistle, [],
        kind: :song,
        upkeep: 5,
        linger_ms: 20_000
      )

    assert Field.cell_profile(group, {11, 10}) == @dissonance
    assert Field.cell_profile(group, {7, 10}) == :none
    # Whistle's unit carries NoMob, which the dance switch keeps.
    assert Field.unit_targets(group, {11, 10}, [{:player, 17}, {:mob, 42}]) == []
    assert {:ok, ^group} = Field.on_unit_hit(group, {11, 10}, {:mob, 42}, 1_000)
    assert_received {:hit, {:mob, 42}, 317, 5}
  end

  @tag game_mode: :pre_renewal
  test "two overlapping dances strike enemies as Ugly Dance" do
    Mimic.copy(Resource)
    test_pid = self()

    stub(Resource, :drain_sp, fn type, id, amount ->
      send(test_pid, {:drained, type, id, amount})
      :ok
    end)

    :ok = UnitRegistry.register_player(player(17), self())
    :ok = UnitRegistry.register_player(player(18, 13), self())
    register_mob(42, 11, 10)
    {:ok, forget} = Catalog.by_name(:dc_dontforgetme)

    {:ok, _} =
      Field.start(player(17), forget, 5, :sc_dontforgetme, [],
        kind: :dance,
        upkeep: 5,
        linger_ms: 20_000
      )

    {:ok, _} =
      Field.start(player(18, 13), forget, 1, :sc_dontforgetme, [],
        kind: :dance,
        upkeep: 5,
        linger_ms: 20_000
      )

    [group] = Storage.get_groups_by_caster(:player, 17)

    assert Field.cell_profile(group, {11, 10}) == %{@dissonance | skill_id: 325}
    assert [{:mob, 42}] = Field.unit_targets(group, {11, 10}, [{:mob, 42}])
    assert {:ok, _group} = Field.on_unit_hit(group, {11, 10}, {:mob, 42}, 1_000)
    assert_received {:drained, :mob, 42, 30}
  end

  describe "on the unit pass" do
    setup {Aesir.MimicMode, :global}

    @describetag game_mode: :pre_renewal

    test "two overlapping Dissonance fields share the 3 s interval for one target" do
      test_pid = self()

      stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
        send(test_pid, {:hit, target, opts[:skill_id]})
        :ok
      end)

      :ok = UnitRegistry.register_player(player(17), self())
      :ok = UnitRegistry.register_player(player(18, 13), self())
      register_mob(42, 11, 10)
      {:ok, dissonance} = Catalog.by_name(:ba_dissonance)

      {:ok, _} =
        Field.start(player(17), dissonance, 1, nil, [],
          kind: :song,
          reach: :enemy,
          upkeep: 3,
          linger_ms: 0,
          tick: :dissonance,
          tick_interval: 3_000,
          no_overlap: true
        )

      {:ok, _} =
        Field.start(player(18, 13), dissonance, 1, nil, [],
          kind: :song,
          reach: :enemy,
          upkeep: 3,
          linger_ms: 0,
          tick: :dissonance,
          tick_interval: 3_000,
          no_overlap: true
        )

      [%Group{created_at: start}] = Storage.get_groups_by_caster(:player, 17)
      manager = Process.get({Manager, :server})
      :ok = Manager.tick(manager, start + 1_000)
      assert_received {:hit, {:mob, 42}, 317}
      refute_received {:hit, _, _}

      :ok = Manager.tick(manager, start + 2_000)
      :ok = Manager.tick(manager, start + 3_999)
      refute_received {:hit, _, _}

      :ok = Manager.tick(manager, start + 4_000)
      assert_received {:hit, {:mob, 42}, 317}
      refute_received {:hit, _, _}
    end

    test "a Lullaby cell on Land Protector strikes nobody while its other cells do" do
      :ok = UnitRegistry.register_player(player(17), self())
      :ok = UnitRegistry.register_player(player(18), self())
      register_mob(42, 11, 10)
      register_mob(43, 9, 10)
      {:ok, lullaby} = Catalog.by_name(:bd_lullaby)

      {:ok, _} =
        Field.start(player(17), lullaby, 1, nil, [],
          kind: :ensemble,
          partners: [18],
          layout_radius: 4,
          linger_ms: 0,
          reach: :enemy,
          upkeep: 4,
          tick: :lullaby,
          tick_interval: 6_000
        )

      [group] = Storage.get_groups_by_caster(:player, 17)
      refute Group.ignores_land_protector?(group)
      :ok = Storage.insert(land_protector({11, 10}))
      test_pid = self()

      stub(StatusInterpreter, :apply_status, fn type, id, :sc_sleep, _opts ->
        send(test_pid, {:slept, type, id})
        :ok
      end)

      :ok = Manager.tick(Process.get({Manager, :server}), group.created_at + 1_000)

      assert_received {:slept, :mob, 43}
      refute_received {:slept, :mob, 42}
    end
  end

  @tag game_mode: :pre_renewal
  test "Hermode's ensemble ignores Land Protector" do
    :ok = UnitRegistry.register_player(player(17), self())
    :ok = UnitRegistry.register_player(player(18), self())
    {:ok, hermode} = Catalog.by_name(:cg_hermode)

    {:ok, _} =
      Field.start(player(17), hermode, 1, :sc_hermode, [val1: 1],
        kind: :ensemble,
        ignore_land_protector: true,
        partners: [18],
        upkeep: 5,
        linger_ms: 0
      )

    [group] = Storage.get_groups_by_caster(:player, 17)
    assert Group.ignores_land_protector?(group)
  end

  defp land_protector(cell) do
    %Group{
      group_id: 9_100,
      skill_name: :sa_landprotector,
      map_name: "prontera",
      center: cell,
      cells: [cell],
      state: %{land_protector: true}
    }
  end

  defp register_mob(id, x, y) do
    mob =
      %MobState{
        instance_id: id,
        mob_id: 1002,
        mob_data: Aesir.TestMob.definition(),
        spawn_ref: nil,
        x: x,
        y: y,
        map_name: "prontera",
        hp: 100,
        sp: 0,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

    :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, id, x, y, "prontera")
  end

  defp player(id, x \\ 10) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Bard #{id}",
      last_map: "prontera",
      last_x: x,
      last_y: 10,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 19
    })
  end
end
