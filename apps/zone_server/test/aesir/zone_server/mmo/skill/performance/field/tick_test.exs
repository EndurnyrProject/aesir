defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Field.TickTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field.Tick
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(Resource)
    Mimic.copy(DamageApplication)
    :ok
  end

  describe "effects" do
    setup :set_mimic_private

    test "Dissonance sends neutral misc damage with the performer's current Music Lessons" do
      test_pid = self()

      stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
        send(test_pid, {target, opts})
        :ok
      end)

      group = group(3, :dissonance, 0)
      assert :ok = Tick.dissonance(group, lessons(315, 10), [{:mob, 42}])
      assert_received {{:mob, 42}, opts}
      assert opts[:skill_id] == 317
      assert opts[:skill_level] == 3
      assert opts[:base_damage] == 90
      assert opts[:element] == :neutral
    end

    test "Ugly Dance drains SP by the performer's current Dancing Lessons" do
      test_pid = self()

      stub(Resource, :drain_sp, fn type, id, amount ->
        send(test_pid, {type, id, amount})
        :ok
      end)

      assert :ok = Tick.ugly_dance(group(3, :ugly_dance, 0), lessons(323, 10), [{:mob, 42}])
      assert_received {:mob, 42, 50}
    end

    # Only the classic song heals on its unit; renewal Apple of Idun has none.
    @tag game_mode: :pre_renewal
    test "Idun heals a player unit by the performer's current VIT but never targets its caster" do
      test_pid = self()

      stub(DamageApplication, :apply_heal, fn type, id, amount, source ->
        send(test_pid, {type, id, amount, source})
        :ok
      end)

      :ok = UnitRegistry.register_player(player(1, 12), self())
      :ok = UnitRegistry.register_player(player(42), self())
      group = group(5, :idun_heal, 0)

      refute Tick.target?(group, :idun_heal, {:player, 1})
      assert Tick.target?(group, :idun_heal, {:player, 42})
      assert :ok = Tick.apply(:idun_heal, group, {:player, 42})
      # 30 + 5 * level + half the performer's effective VIT (job bonus included).
      expected = 30 + 25 + div(Caster.stat(player(1, 12), :vit), 2)
      assert_received {:player, 42, ^expected, 1}
    end

    test "Idun never targets a monster" do
      :ok = UnitRegistry.register_player(player(1), self())
      :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(42), self())

      group = %{group(5, :idun_heal, 0) | skill_name: :ba_appleidun}
      refute Tick.target?(group, :idun_heal, {:mob, 42})
    end

    test "a NoMob song never reaches a monster, even striking as Dissonance" do
      stub_caster_combatant()
      :ok = UnitRegistry.register_player(player(1), self())
      :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(42), self())

      refute Tick.target?(%{group(5, nil, 0) | skill_name: :ba_whistle}, :dissonance, {:mob, 42})
      assert Tick.target?(group(5, :dissonance, 0), :dissonance, {:mob, 42})
    end

    # Only the classic song heals on its unit; renewal Apple of Idun has none.
    @tag game_mode: :pre_renewal
    test "Idun heals a homunculus" do
      test_pid = self()

      stub(DamageApplication, :apply_heal, fn type, id, amount, source ->
        send(test_pid, {type, id, amount, source})
        :ok
      end)

      :ok = UnitRegistry.register_player(player(1), self())

      homunculus = %HomunculusState{
        id: 5,
        owner_character_id: 2,
        class_id: 6001,
        name: "Lif",
        lifecycle: :active,
        action_state: :idle,
        hp: 50,
        max_hp: 100,
        world_gid: 77
      }

      :ok = UnitRegistry.register_unit(:homunculus, 77, HomunculusState, homunculus, self())
      group = group(5, :idun_heal, 0)

      assert Tick.target?(group, :idun_heal, {:homunculus, 77})
      assert :ok = Tick.apply(:idun_heal, group, {:homunculus, 77})
      expected = 30 + 25 + div(Caster.stat(player(1), :vit), 2)
      assert_received {:homunculus, 77, ^expected, 1}
    end

    test "a dissonant cell strikes an enemy as Dissonance even when the song has no ordinary tick" do
      :ok = UnitRegistry.register_player(player(1), self())
      :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(42), self())
      stub_caster_combatant()
      test_pid = self()

      stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
        send(test_pid, {:hit, target, opts[:skill_id], opts[:skill_level]})
        :ok
      end)

      song = %{group(3, nil, 10) | skill_id: 319, cells: [{2, 2}]}
      other = %{group(1, nil, 0) | group_id: 8, caster_id: 2, cells: [{2, 2}]}
      :ok = Storage.insert(song)
      :ok = Storage.insert(other)

      assert Field.cell_profile(song, {2, 2}) == %{
               skill_id: 317,
               interval: 3_000,
               no_overlap: true
             }

      assert [{:mob, 42}] = Field.unit_targets(song, {2, 2}, [{:player, 1}, {:mob, 42}])
      assert {:ok, ^song} = Field.on_unit_hit(song, {2, 2}, {:mob, 42}, 1_000)
      assert_received {:hit, {:mob, 42}, 317, 3}
    end
  end

  describe "the unit pass" do
    setup {Aesir.MimicMode, :global}

    setup do
      manager = start_supervised!({Manager, name: nil, schedule_tick: fn _, _ -> :ok end})
      Process.put({Manager, :server}, manager)
      test_pid = self()

      stub(Combat, :execute_misc_attack, fn _caster, target, opts ->
        send(test_pid, {:hit, target, opts[:skill_id]})
        :ok
      end)

      stub_caster_combatant()
      :ok = UnitRegistry.register_unit(:mob, 42, MobState, mob(42), self())
      :ok = SpatialIndex.add_unit(:mob, 42, 2, 2, "prontera")
      %{manager: manager}
    end

    test "the first pass strikes at once, even on a negative clock, the next only after the Unit interval",
         %{manager: manager} do
      :ok = UnitRegistry.register_player(player(1), self())
      :ok = Manager.register(manager, unit_field())

      :ok = Manager.tick(manager, -5_000)
      assert_received {:hit, {:mob, 42}, 317}

      :ok = Manager.tick(manager, -4_000)
      :ok = Manager.tick(manager, -2_001)
      refute_received {:hit, _, _}

      :ok = Manager.tick(manager, -2_000)
      assert_received {:hit, {:mob, 42}, 317}
    end

    test "an absent caster strikes nothing", %{manager: manager} do
      :ok = Manager.register(manager, unit_field())

      :ok = Manager.tick(manager, 1_000)

      refute_received {:hit, _, _}
    end
  end

  defp unit_field do
    %{
      group(3, :dissonance, 0)
      | cells: [{2, 2}],
        center: {2, 2},
        created_at: 0,
        expires_at: 100_000,
        interval: 1_000,
        unit_range: 0,
        no_overlap: false,
        handler: Field
    }
  end

  defp stub_caster_combatant do
    stub(Combat, :resolve_combatant, fn :player, 1 ->
      {:ok, %{unit_type: :player, unit_id: 1, map_name: "prontera"}}
    end)
  end

  defp lessons(skill_id, level),
    do: %{stats: %{progression: %{learned_skills: %{skill_id => level}}}}

  defp group(level, tick, lesson) do
    %Group{
      group_id: 7,
      skill_name: :performance,
      skill_id: 317,
      level: level,
      caster_type: :player,
      caster_id: 1,
      map_name: "prontera",
      cells: [],
      state: %{
        performance: %{
          kind: :song,
          status_id: nil,
          status_params: [],
          reach: :enemy,
          linger_ms: 0,
          performers: [1],
          tick: tick,
          tick_interval: 3_000,
          no_overlap: true,
          lesson_level: lesson,
          caster_vit: 0
        }
      }
    }
  end

  defp player(id, vit \\ 1) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Bard #{id}",
      last_map: "prontera",
      last_x: 2,
      last_y: 2,
      sex: "M",
      str: 1,
      agi: 1,
      vit: vit,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 19
    })
  end

  defp mob(id) do
    %MobState{
      instance_id: id,
      mob_id: 1002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: nil,
      x: 2,
      y: 2,
      map_name: "prontera",
      hp: 100,
      sp: 0,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)
  end
end
