defmodule Aesir.ZoneServer.Mmo.Skill.Performance.FieldTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Snapshot
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
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
    :ok
  end

  @tag game_mode: :pre_renewal
  test "field start places a 7x7 song and locks only the performer" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    {:ok, definition} = Catalog.by_name(:ba_whistle)

    assert {:ok, remembered} =
             Field.start(caster, definition, 5, :sc_whistle, [val2: 25],
               kind: :song,
               reach: :everyone,
               upkeep: 5,
               lesson_level: 10
             )

    assert remembered.last_song == %{skill_id: definition.id, level: 5}
    assert [group] = Storage.get_groups_by_caster(:player, 17)
    assert group.center == {10, 10}
    assert length(group.cells) == 49
    assert group.expires_at - group.created_at == 60_000
    assert group.state.performance.next_overlap_at == 0
    skill_id = definition.id

    assert %{val1: ^skill_id, val2: group_id, val3: 10, val4: nil} =
             StatusStorage.get_status(:player, 17, :sc_dancing)

    assert group_id == group.group_id
    assert Group.follows_caster?(group)
    refute StatusStorage.has_status?(:player, 17, :sc_whistle)

    assert {:error, :already_performing} =
             Field.start(caster, definition, 5, :sc_whistle, [], kind: :song, upkeep: 5)
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
        partners: [18]
      )

    [group] = Storage.get_groups_by_caster(:player, 17)
    refute Group.follows_caster?(group)
    assert %{val4: 18} = StatusStorage.get_status(:player, 17, :sc_dancing)
    assert %{val4: 17} = StatusStorage.get_status(:player, 18, :sc_dancing)
  end

  @tag game_mode: :pre_renewal
  test "field reach excludes the performer, marks dissonant cells, and unlocks on expiry" do
    caster = player(17)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_unit(:player, 17, 10, 10, "prontera")
    :ok = UnitRegistry.register_player(player(18), self())
    :ok = SpatialIndex.add_unit(:player, 18, 11, 10, "prontera")
    {:ok, definition} = Catalog.by_name(:ba_whistle)
    {:ok, _} = Field.start(caster, definition, 5, :sc_whistle, [], kind: :song, upkeep: 5)
    [group] = Storage.get_groups_by_caster(:player, 17)

    support = Field.field_support(group)
    refute support.target?.({:player, 17})
    assert support.target?.({:player, 18})
    assert support.linger_ms == 20_000
    assert support.params[:caster_id] == 17

    marked = put_in(group.state.performance.dissonant_cells, MapSet.new([{11, 10}]))
    refute Field.field_support(marked).target?.({:player, 18})
    assert :ok = Field.on_expire(group)
    refute StatusStorage.has_status?(:player, 17, :sc_dancing)
  end

  @tag game_mode: :pre_renewal
  test "reach can select party members, enemies or mobs without selecting the performer" do
    caster = %{player(17) | party_id: 2}
    ally = %{player(18) | party_id: 2}
    stranger = %{player(19) | party_id: 3}

    for state <- [caster, ally, stranger] do
      :ok = UnitRegistry.register_player(state, self())
      :ok = SpatialIndex.add_unit(:player, state.character_id, 10, 10, "prontera")
    end

    mob = %MobState{
      instance_id: 42,
      mob_id: 1002,
      mob_data: nil,
      spawn_ref: nil,
      x: 10,
      y: 10,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob, self())
    :ok = SpatialIndex.add_unit(:mob, 42, 10, 10, "prontera")
    {:ok, definition} = Catalog.by_name(:ba_whistle)
    {:ok, _} = Field.start(caster, definition, 5, :sc_whistle, [], kind: :song, upkeep: 5)
    [group] = Storage.get_groups_by_caster(:player, 17)

    party = put_in(group.state.performance.reach, :party) |> Field.field_support()
    assert party.target?.({:player, 18})
    refute party.target?.({:player, 19})
    refute party.target?.({:player, 17})

    enemy = put_in(group.state.performance.reach, :enemy) |> Field.field_support()
    assert enemy.target?.({:mob, 42})
    refute enemy.target?.({:player, 18})

    mobs = put_in(group.state.performance.reach, :mobs) |> Field.field_support()
    assert mobs.target?.({:mob, 42})
    refute mobs.target?.({:player, 18})
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

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Bard #{id}",
      last_map: "prontera",
      last_x: 10,
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
