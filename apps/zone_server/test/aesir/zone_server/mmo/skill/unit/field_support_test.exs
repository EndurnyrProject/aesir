defmodule Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupportTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  setup :set_mimic_private

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule Entity do
    def get_entity_info(_state), do: %{stats: %{}}
  end

  defmodule QuagmireField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{level: level}),
      do: %{
        status_type: :sc_quagmire,
        params: [level: level, val1: level, val2: 5 * level],
        target?: fn _ -> true end
      }
  end

  defmodule VolcanoField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{level: level}),
      do: %{
        status_type: :sc_volcano,
        params: [level: level, val1: level],
        target?: fn _ -> true end
      }
  end

  setup :setup_ets_tables

  setup do
    manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
    Process.put({Manager, :server}, manager)
    :ok
  end

  @now 100_000

  defp player(id, {x, y}) do
    state = %PlayerState{
      character_id: id,
      action_state: :idle,
      map_name: "prontera",
      x: x,
      y: y,
      stats: %{current_state: %{hp: 100}}
    }

    :ok = UnitRegistry.register_unit(:player, id, Entity, state)
    :ok = SpatialIndex.add_unit(:player, id, x, y, "prontera")
    {:player, id}
  end

  defp mob(id, {x, y}) do
    state = %MobState{
      instance_id: id,
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
        modes: []
      },
      spawn_ref: nil,
      x: x,
      y: y,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, id, MobState, state)
    :ok = SpatialIndex.add_unit(:mob, id, x, y, "prontera")
    {:mob, id}
  end

  defp group(id, handler, attrs) do
    base = %Group{
      group_id: id,
      skill_id: 92,
      skill_name: :wz_quagmire,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: {5, 5},
      cells: [{5, 5}],
      created_at: @now,
      next_tick_at: @now + 1_000,
      expires_at: @now + 10_000,
      interval: 1_000,
      handler: handler
    }

    group = struct(base, attrs)
    :ok = Storage.insert(group)
    group
  end

  defp move(mover, from, {x, y}) do
    {type, id} = mover
    :ok = SpatialIndex.remove_unit(type, id)
    :ok = SpatialIndex.add_unit(type, id, x, y, "prontera")

    Trigger.on_leave_cell(
      mover,
      "prontera",
      elem(from, 0),
      elem(from, 1),
      "prontera",
      x,
      y
    )

    Trigger.on_enter_cell(mover, "prontera", x, y)
  end

  test "onplace starts the status for the group's whole lifetime only when the unit lacks it" do
    mover = player(11, {5, 5})
    weak = group(1, QuagmireField, level: 1, expires_at: @now + 10_000)
    strong = group(2, QuagmireField, level: 5, expires_at: @now + 25_000, cells: [{5, 5}])

    before = System.monotonic_time(:millisecond)
    assert :placed = FieldSupport.onplace(weak, mover)

    assert %{val1: 1, val2: 5, expires_at: expires_at} =
             StatusStorage.get_status(:player, 11, :sc_quagmire)

    assert expires_at >= before + 10_000
    assert expires_at <= System.monotonic_time(:millisecond) + 10_000

    assert :placed = FieldSupport.onplace(strong, mover)

    assert %{val1: 1, expires_at: ^expires_at} =
             StatusStorage.get_status(:player, 11, :sc_quagmire)
  end

  test "onleft ends the status for a player but Quagmire lets a monster keep it" do
    walker = player(11, {5, 5})
    beast = mob(21, {5, 5})
    quagmire = group(1, QuagmireField, [])

    FieldSupport.place(quagmire, quagmire.cells)
    assert StatusStorage.has_status?(:player, 11, :sc_quagmire)
    assert StatusStorage.has_status?(:mob, 21, :sc_quagmire)

    FieldSupport.onleft(quagmire, walker)
    FieldSupport.onleft(quagmire, beast)
    refute StatusStorage.has_status?(:player, 11, :sc_quagmire)
    assert StatusStorage.has_status?(:mob, 21, :sc_quagmire)
  end

  test "stepping between two fields of the same skill never ends the status, leaving does" do
    mover = player(11, {5, 5})
    _first = group(1, VolcanoField, skill_id: 83, skill_name: :sa_volcano, cells: [{5, 5}])

    _second =
      group(2, VolcanoField, skill_id: 83, skill_name: :sa_volcano, cells: [{6, 5}], caster_id: 2)

    manager = Process.get({Manager, :server})
    assert :ok = Manager.trigger(manager, 1, mover, :on_touch)
    assert %{expires_at: expires_at} = StatusStorage.get_status(:player, 11, :sc_volcano)

    move(mover, {5, 5}, {6, 5})
    assert %{expires_at: ^expires_at} = StatusStorage.get_status(:player, 11, :sc_volcano)

    move(mover, {6, 5}, {7, 5})
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)
  end

  test "an invincible player neither gains nor loses a field status through the unit events" do
    mover = player(11, {5, 5})
    :ok = StatusStorage.apply_status(:player, 11, :sc_volcano, val1: 1, duration: 60_000)

    invincible = %PlayerState{
      character_id: 11,
      action_state: :idle,
      map_name: "prontera",
      x: 5,
      y: 5,
      invincible_timer: make_ref(),
      stats: %{current_state: %{hp: 100}}
    }

    :ok = UnitRegistry.update_unit_state(:player, 11, invincible)
    volcano = group(1, VolcanoField, skill_id: 83, skill_name: :sa_volcano, cells: [{5, 5}])
    quagmire = group(2, QuagmireField, cells: [{5, 5}])

    FieldSupport.place(quagmire, quagmire.cells)
    refute StatusStorage.has_status?(:player, 11, :sc_quagmire)

    FieldSupport.out(volcano, volcano.cells, fn _ -> :ok end)
    assert StatusStorage.has_status?(:player, 11, :sc_volcano)
    refute FieldSupport.target?(volcano, mover)
  end

  test "a cell vanishing under a target runs its leave events while the group lives on" do
    player(11, {5, 5})
    quagmire = group(1, QuagmireField, cells: [{5, 5}, {6, 5}])
    FieldSupport.place(quagmire, quagmire.cells)
    assert StatusStorage.has_status?(:player, 11, :sc_quagmire)

    FieldSupport.out(quagmire, [{5, 5}], fn _ -> :ok end)
    refute StatusStorage.has_status?(:player, 11, :sc_quagmire)
  end

  defmodule WhistleField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{}),
      do: %{
        status_type: :sc_whistle,
        params: [val2: 5, val3: 1],
        target?: fn _ -> true end,
        linger_ms: 20_000
      }
  end

  test "a solo song lasts one unit pass past its field and lingers 20 s once on a player who leaves" do
    mover = player(11, {5, 5})
    beast = mob(21, {5, 5})

    song =
      group(1, WhistleField,
        skill_id: 319,
        skill_name: :ba_whistle,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :song, performers: [1]}}
      )

    before = System.monotonic_time(:millisecond)
    FieldSupport.place(song, song.cells)
    assert %{val4: 0, expires_at: full} = StatusStorage.get_status(:player, 11, :sc_whistle)
    assert full >= before + 60_100

    FieldSupport.onleft(song, mover)
    assert %{val4: 1, expires_at: linger} = StatusStorage.get_status(:player, 11, :sc_whistle)
    assert linger >= before + 20_000
    assert linger <= System.monotonic_time(:millisecond) + 20_000

    assert :placed = FieldSupport.onplace(song, mover)
    FieldSupport.onleft(song, mover)
    assert %{val4: 1, expires_at: ^linger} = StatusStorage.get_status(:player, 11, :sc_whistle)

    FieldSupport.onleft(song, beast)
    refute StatusStorage.has_status?(:mob, 21, :sc_whistle)
  end

  test "a unit removed from play leaves every field on its cell" do
    walker = player(11, {5, 5})
    beast = mob(21, {5, 5})
    volcano = group(1, VolcanoField, skill_id: 83, skill_name: :sa_volcano, cells: [{5, 5}])

    song =
      group(2, WhistleField,
        skill_id: 319,
        skill_name: :ba_whistle,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :song, performers: [1]}}
      )

    FieldSupport.place(volcano, volcano.cells)
    FieldSupport.place(song, song.cells)
    assert StatusStorage.has_status?(:player, 11, :sc_volcano)
    assert %{val4: 0} = StatusStorage.get_status(:player, 11, :sc_whistle)
    assert StatusStorage.has_status?(:mob, 21, :sc_whistle)

    before = System.monotonic_time(:millisecond)
    assert :ok = Trigger.on_removed(walker)
    assert :ok = Trigger.on_removed(beast)

    refute StatusStorage.has_status?(:player, 11, :sc_volcano)
    assert %{val4: 1, expires_at: linger} = StatusStorage.get_status(:player, 11, :sc_whistle)
    assert linger >= before + 20_000
    assert linger <= System.monotonic_time(:millisecond) + 20_000
    refute StatusStorage.has_status?(:mob, 21, :sc_whistle)
  end

  test "a unit without a position has nothing to leave" do
    assert :ok = Trigger.on_removed({:player, 404})
  end

  test "the linger leaves a status that ended meanwhile ended" do
    mover = player(11, {5, 5})

    song =
      group(1, WhistleField,
        skill_id: 319,
        skill_name: :ba_whistle,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :song, performers: [1]}}
      )

    FieldSupport.place(song, song.cells)
    %StatusEntry{} = held = StatusStorage.get_status(:player, 11, :sc_whistle)
    :ok = StatusStorage.remove_status(:player, 11, :sc_whistle)

    expect(StatusStorage, :get_status, fn :player, 11, :sc_whistle -> held end)
    stub(StatusStorage, :get_status, &call_original(StatusStorage, :get_status, [&1, &2, &3]))

    FieldSupport.onleft(song, mover)
    refute StatusStorage.has_status?(:player, 11, :sc_whistle)
  end
end
