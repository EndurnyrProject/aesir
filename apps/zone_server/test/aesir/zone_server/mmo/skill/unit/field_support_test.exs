defmodule Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupportTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  setup :set_mimic_private

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Ground.Trigger
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Unit.FieldSupport
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgHermode
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
    state =
      %MobState{
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
          class: Aesir.ZoneServer.Mmo.MobManagement.MobMode.class([]),
          modes: []
        },
        spawn_ref: nil,
        x: x,
        y: y,
        map_name: "prontera",
        hp: 100,
        sp: 0,
        spawned_at: 0
      }
      |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

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

    Trigger.on_step(mover, "prontera", elem(from, 0), elem(from, 1), "prontera", x, y)
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

  defmodule AllyWhistleField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{}),
      do: %{
        status_type: :sc_whistle,
        params: [val2: 5, val3: 1],
        target?: fn {_type, id} -> id != 12 end,
        linger_ms: 20_000
      }
  end

  test "a vanishing solo song lingers on a non-target too, its performer's own copy is untouched" do
    bystander = player(12, {5, 5})
    singer = player(1, {5, 5})
    volcano = group(1, VolcanoField, skill_id: 83, skill_name: :sa_volcano, cells: [{5, 5}])

    song =
      group(2, AllyWhistleField,
        skill_id: 319,
        skill_name: :ba_whistle,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :song, performers: [1]}}
      )

    :ok = StatusStorage.apply_status(:player, 12, :sc_whistle, val2: 5, val4: 0, duration: 60_000)
    :ok = StatusStorage.apply_status(:player, 12, :sc_volcano, val1: 1, duration: 60_000)
    :ok = StatusStorage.apply_status(:player, 1, :sc_whistle, val2: 5, val4: 0, duration: 60_000)
    refute FieldSupport.target?(song, bystander)
    assert FieldSupport.target?(song, singer)
    assert :performing = FieldSupport.onout(song, singer)
    assert :left = FieldSupport.onout(song, bystander)

    :ok =
      UnitRegistry.update_unit_state(:player, 12, %PlayerState{
        character_id: 12,
        action_state: :idle,
        map_name: "prontera",
        x: 5,
        y: 5,
        invincible_timer: make_ref(),
        stats: %{current_state: %{hp: 100}}
      })

    FieldSupport.out(song, song.cells, fn _ -> :ok end)
    FieldSupport.out(volcano, volcano.cells, fn _ -> :ok end)

    assert %{val4: 1} = StatusStorage.get_status(:player, 12, :sc_whistle)
    assert StatusStorage.has_status?(:player, 12, :sc_volcano)
    assert %{val4: 0} = StatusStorage.get_status(:player, 1, :sc_whistle)
  end

  defmodule RichmanField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{}),
      do: %{
        status_type: :sc_richmankim,
        params: [val1: 1, val2: 25],
        target?: fn {_type, id} -> id != 13 end
      }
  end

  test "an ensemble places its caster without the status, its partner with it, and ends a non-target performer's lock" do
    caster = player(1, {5, 5})
    partner = player(12, {5, 5})
    hidden_partner = player(13, {5, 5})

    ensemble =
      group(1, RichmanField,
        skill_id: 307,
        skill_name: :bd_richmankim,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :ensemble, performers: [1, 12, 13]}}
      )

    for {id, val4} <- [{1, 12}, {12, 1}, {13, 1}] do
      :ok =
        StatusStorage.apply_status(:player, id, :sc_dancing,
          val1: 307,
          val2: 1,
          val4: val4,
          duration: 61_000
        )
    end

    assert :placed = FieldSupport.onplace(ensemble, caster)
    refute StatusStorage.has_status?(:player, 1, :sc_richmankim)

    assert :placed = FieldSupport.onplace(ensemble, partner)
    assert StatusStorage.has_status?(:player, 12, :sc_richmankim)
    assert :left = FieldSupport.onout(ensemble, caster)

    refute FieldSupport.target?(ensemble, hidden_partner)
    assert FieldSupport.ensemble_performer?(ensemble, hidden_partner)
    refute FieldSupport.ensemble_performer?(ensemble, {:player, 99})
    FieldSupport.leave(ensemble, hidden_partner, fn _ -> flunk("on_out ran for a non-target") end)
    refute StatusStorage.has_status?(:player, 13, :sc_dancing)
    assert StatusStorage.has_status?(:player, 12, :sc_dancing)
  end

  defmodule HermodeField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{state: %{test_pid: test_pid}}),
      do: %{
        status_type: :sc_hermode,
        params: [val1: 1],
        target?: fn _ -> true end,
        on_place: fn mover -> send(test_pid, {:on_place, mover}) end
      }
  end

  test "the handler's on_place runs on every placement, before the grant and even when the status is held" do
    ally = player(12, {5, 5})

    hermode =
      group(1, HermodeField,
        skill_id: 488,
        skill_name: :cg_hermode,
        expires_at: @now + 30_000,
        state: %{test_pid: self(), performance: %{kind: :ensemble, performers: [1]}}
      )

    assert :placed = FieldSupport.onplace(hermode, ally)
    assert_received {:on_place, {:player, 12}}
    assert StatusStorage.has_status?(:player, 12, :sc_hermode)

    assert :placed = FieldSupport.onplace(hermode, ally)
    assert_received {:on_place, {:player, 12}}

    :ok = StatusStorage.remove_status(:player, 12, :sc_hermode)
    {:ok, {_module, state, _pid}} = UnitRegistry.get_unit(:player, 12)
    :ok = UnitRegistry.update_unit_state(:player, 12, %{state | action_state: :dead})
    assert :skipped = FieldSupport.onplace(hermode, ally)
    refute_received {:on_place, _}
  end

  @tag game_mode: :pre_renewal
  test "classic Hermode reaches every unit in the field and strips buffs from party allies only" do
    caster = player(1, {5, 5})
    ally = player(12, {5, 5})
    stranger = player(13, {5, 5})
    beast = mob(21, {5, 5})

    for id <- [1, 12, 13] do
      {:ok, {_module, state, _pid}} = UnitRegistry.get_unit(:player, id)

      :ok =
        UnitRegistry.update_unit_state(:player, id, %{
          state
          | party_id: if(id == 13, do: 9, else: 7)
        })

      :ok = StatusStorage.apply_status(:player, id, :sc_blessing, val1: 10, duration: 60_000)
    end

    hermode =
      group(1, CgHermode,
        skill_id: 488,
        skill_name: :cg_hermode,
        expires_at: @now + 30_000,
        party_id: 7,
        state: %{
          performance: %{
            kind: :ensemble,
            performers: [1],
            status_id: :sc_hermode,
            status_params: [val1: 1],
            reach: :all,
            linger_ms: 0
          }
        }
      )

    support = CgHermode.field_support(hermode)
    assert support.target?.(caster)
    assert support.target?.(ally)
    assert support.target?.(stranger)
    assert support.target?.(beast)

    FieldSupport.place(hermode, hermode.cells)

    refute StatusStorage.has_status?(:player, 1, :sc_hermode)
    assert StatusStorage.has_status?(:player, 12, :sc_hermode)
    assert StatusStorage.has_status?(:player, 13, :sc_hermode)
    assert StatusStorage.has_status?(:mob, 21, :sc_hermode)
    assert StatusStorage.has_status?(:player, 1, :sc_blessing)
    refute StatusStorage.has_status?(:player, 12, :sc_blessing)
    assert StatusStorage.has_status?(:player, 13, :sc_blessing)
  end

  defmodule OriginOnlyVolcanoField do
    alias Aesir.ZoneServer.Unit.SpatialIndex

    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{level: level}),
      do: %{
        status_type: :sc_volcano,
        params: [level: level, val1: level],
        target?: fn _ -> true end,
        grants?: fn {type, id} ->
          match?({:ok, {5, 5, _map}}, SpatialIndex.get_unit_position(type, id))
        end
      }
  end

  test "a step is one pass: a cell that refuses the placement ends the status inside the footprint" do
    mover = player(11, {5, 5})

    _volcano =
      group(1, OriginOnlyVolcanoField,
        skill_id: 83,
        skill_name: :sa_volcano,
        cells: [{5, 5}, {6, 5}]
      )

    FieldSupport.place(Storage.get(1), [{5, 5}])
    assert StatusStorage.has_status?(:player, 11, :sc_volcano)

    move(mover, {5, 5}, {6, 5})
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)

    move(mover, {6, 5}, {5, 5})
    assert StatusStorage.has_status?(:player, 11, :sc_volcano)
  end

  defmodule BragiField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{}),
      do: %{
        status_type: :sc_poembragi,
        params: [val1: 1, val2: 3],
        target?: fn _ -> true end,
        linger_ms: 20_000
      }
  end

  test "stepping onto a dissonant cell lingers the song on a non-target, the singer's own copy untouched" do
    bystander = player(12, {4, 5})
    singer = player(1, {4, 5})

    song =
      group(1, AllyWhistleField,
        skill_id: 319,
        skill_name: :ba_whistle,
        expires_at: @now + 60_000,
        cells: [{4, 5}, {5, 5}],
        state: %{performance: %{kind: :song, performers: [1]}}
      )

    _other_song =
      group(2, BragiField,
        skill_id: 321,
        skill_name: :ba_poembragi,
        caster_id: 2,
        expires_at: @now + 60_000,
        cells: [{5, 5}],
        state: %{performance: %{kind: :song, performers: [2]}}
      )

    :ok = StatusStorage.apply_status(:player, 12, :sc_whistle, val2: 5, val4: 0, duration: 60_000)
    :ok = StatusStorage.apply_status(:player, 1, :sc_whistle, val2: 5, val4: 0, duration: 60_000)
    assert FieldSupport.dissonant?(song, {5, 5})
    refute FieldSupport.dissonant?(song, {4, 5})

    move(bystander, {4, 5}, {5, 5})
    assert %{val4: 1} = StatusStorage.get_status(:player, 12, :sc_whistle)

    move(singer, {4, 5}, {5, 5})
    assert %{val4: 0} = StatusStorage.get_status(:player, 1, :sc_whistle)
  end

  defp dissonant_whistle do
    song =
      group(1, AllyWhistleField,
        skill_id: 319,
        skill_name: :ba_whistle,
        expires_at: @now + 60_000,
        cells: [{4, 5}, {5, 5}],
        state: %{performance: %{kind: :song, performers: [1]}}
      )

    group(2, BragiField,
      skill_id: 321,
      skill_name: :ba_poembragi,
      caster_id: 2,
      expires_at: @now + 60_000,
      cells: [{5, 5}],
      state: %{performance: %{kind: :song, performers: [2]}}
    )

    :ok = StatusStorage.apply_status(:player, 12, :sc_whistle, val2: 5, val4: 0, duration: 60_000)
    :ok = StatusStorage.apply_status(:player, 1, :sc_whistle, val2: 5, val4: 0, duration: 60_000)
    assert FieldSupport.dissonant?(song, {5, 5})
    song
  end

  test "appearing on a dissonant cell lingers the song on a non-target, the singer's own copy untouched" do
    dissonant_whistle()
    bystander = player(12, {5, 5})
    singer = player(1, {5, 5})

    assert :ok = Trigger.on_appear(bystander, "prontera", 5, 5)
    assert %{val4: 1} = StatusStorage.get_status(:player, 12, :sc_whistle)
    refute StatusStorage.has_status?(:player, 12, :sc_poembragi)

    assert :ok = Trigger.on_appear(singer, "prontera", 5, 5)
    assert %{val4: 0} = StatusStorage.get_status(:player, 1, :sc_whistle)
  end

  test "removal from a dissonant cell lingers the song on a non-target, the singer's own copy untouched" do
    dissonant_whistle()
    bystander = player(12, {5, 5})
    singer = player(1, {5, 5})

    assert :ok = Trigger.on_removed(bystander)
    assert %{val4: 1} = StatusStorage.get_status(:player, 12, :sc_whistle)

    assert :ok = Trigger.on_removed(singer)
    assert %{val4: 0} = StatusStorage.get_status(:player, 1, :sc_whistle)
  end

  test "a timer unit neither places an appearing unit nor sees a removed one leave" do
    walker = player(11, {5, 5})

    for {skill_name, id} <- [pr_sanctuary: 1, wz_firepillar: 2, ht_landmine: 3, ba_dissonance: 4] do
      group(id, VolcanoField, skill_id: 83, skill_name: skill_name)
    end

    assert :ok = Trigger.on_appear(walker, "prontera", 5, 5)
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)

    :ok = StatusStorage.apply_status(:player, 11, :sc_volcano, val1: 1, duration: 60_000)
    assert :ok = Trigger.on_removed(walker)
    assert StatusStorage.has_status?(:player, 11, :sc_volcano)
  end

  test "Spider Web never places an appearing unit but sees a removed one leave" do
    walker = player(11, {5, 5})
    group(1, VolcanoField, skill_id: 405, skill_name: :pf_spiderweb)

    assert :ok = Trigger.on_appear(walker, "prontera", 5, 5)
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)

    :ok = StatusStorage.apply_status(:player, 11, :sc_volcano, val1: 1, duration: 60_000)
    assert :ok = Trigger.on_removed(walker)
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)
  end

  test "renewal Gravitation acts on its timer only, classic Gravitation on an appearance too" do
    walker = player(11, {5, 5})
    group(1, VolcanoField, skill_id: 361, skill_name: :hw_gravitation)

    assert :ok = Trigger.on_appear(walker, "prontera", 5, 5)

    case GameMode.mode() do
      :renewal -> refute StatusStorage.has_status?(:player, 11, :sc_volcano)
      :pre_renewal -> assert StatusStorage.has_status?(:player, 11, :sc_volcano)
    end
  end

  @tag game_mode: :renewal
  test "a monster stepping through a renewal Gravitation neither gains nor loses its status" do
    beast = mob(21, {4, 5})
    group(1, VolcanoField, skill_id: 361, skill_name: :hw_gravitation, cells: [{5, 5}])

    move(beast, {4, 5}, {5, 5})
    refute StatusStorage.has_status?(:mob, 21, :sc_volcano)

    :ok = StatusStorage.apply_status(:mob, 21, :sc_volcano, val1: 1, duration: 60_000)
    move(beast, {5, 5}, {6, 5})
    assert StatusStorage.has_status?(:mob, 21, :sc_volcano)
  end

  @tag game_mode: :pre_renewal
  test "a monster stepping through a classic Gravitation gains it and loses it" do
    beast = mob(21, {4, 5})
    group(1, VolcanoField, skill_id: 361, skill_name: :hw_gravitation, cells: [{5, 5}])

    move(beast, {4, 5}, {5, 5})
    assert StatusStorage.has_status?(:mob, 21, :sc_volcano)

    move(beast, {5, 5}, {6, 5})
    refute StatusStorage.has_status?(:mob, 21, :sc_volcano)
  end

  test "a step never wakes a timer unit, and Spider Web sees a step out but not a step in" do
    walker = player(11, {4, 5})
    group(1, VolcanoField, skill_id: 70, skill_name: :pr_sanctuary, cells: [{5, 5}])
    group(2, VolcanoField, skill_id: 405, skill_name: :pf_spiderweb, cells: [{6, 5}])

    move(walker, {4, 5}, {5, 5})
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)

    :ok = StatusStorage.apply_status(:player, 11, :sc_volcano, val1: 1, duration: 60_000)
    move(walker, {5, 5}, {6, 5})
    assert StatusStorage.has_status?(:player, 11, :sc_volcano)

    move(walker, {6, 5}, {7, 5})
    refute StatusStorage.has_status?(:player, 11, :sc_volcano)
  end

  defmodule EnsembleStepField do
    def on_interval(group, _now), do: {:ok, group}

    def field_support(%Group{}),
      do: %{
        status_type: :sc_richmankim,
        params: [val1: 1, val2: 25],
        target?: fn _ -> true end
      }
  end

  test "a performer stepping off its ensemble ends its lock through the step, with no interval poll" do
    partner = player(12, {5, 5})

    ensemble =
      group(1, EnsembleStepField,
        skill_id: 307,
        skill_name: :bd_richmankim,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :ensemble, performers: [1, 12]}}
      )

    :ok =
      StatusStorage.apply_status(:player, 12, :sc_dancing,
        val1: 307,
        val2: 1,
        val4: 1,
        duration: 61_000
      )

    assert {:ok, ^ensemble} = Field.on_interval(ensemble, @now + 1_000)

    FieldSupport.place(ensemble, ensemble.cells)
    assert StatusStorage.has_status?(:player, 12, :sc_richmankim)

    move(partner, {5, 5}, {9, 9})
    refute StatusStorage.has_status?(:player, 12, :sc_dancing)
    refute StatusStorage.has_status?(:player, 12, :sc_richmankim)
  end

  test "a Hermode performer stepping off its field keeps performing" do
    partner = player(12, {5, 5})

    hermode =
      group(1, EnsembleStepField,
        skill_id: 488,
        skill_name: :cg_hermode,
        expires_at: @now + 60_000,
        state: %{performance: %{kind: :ensemble, performers: [1, 12]}}
      )

    :ok =
      StatusStorage.apply_status(:player, 12, :sc_dancing,
        val1: 488,
        val2: 1,
        val4: 1,
        duration: 61_000
      )

    FieldSupport.place(hermode, hermode.cells)
    move(partner, {5, 5}, {9, 9})

    assert StatusStorage.has_status?(:player, 12, :sc_dancing)
  end
end
