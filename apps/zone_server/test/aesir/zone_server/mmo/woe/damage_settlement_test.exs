defmodule Aesir.ZoneServer.Mmo.Woe.DamageSettlementTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @castle_map "aldeg_cas01"

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    :ok = MapFlags.reload()
    :ok
  end

  test "off-hours castle ground applies the ordinary damage rate" do
    attacker = register_player(10, @castle_map)
    target = register_player(20, @castle_map)

    expect_damage(target.pid, 80, {:player, 10})

    assert {80, hit_info} = prepare(20, 100, ordinary_hit(), {:player, 10})
    assert hit_info.ground_damage_rate == 80
    assert hit_info.equipment_return_basis == 100
    assert hit_info.status_return_basis == 80

    assert :ok = deliver(target, 80, hit_info, {:player, 10})
    assert Process.alive?(attacker.pid)
  end

  test "a partial shield absorbs before the castle-ground rate" do
    _attacker = register_player(11, @castle_map)
    target = register_player(21, @castle_map)

    :ok = StatusInterpreter.apply_status(:player, 21, :sc_kyrie, val2: 30, val3: 5)
    expect_damage(target.pid, 56, {:player, 11})

    assert {56, hit_info} = prepare(21, 100, ordinary_hit(), {:player, 11})
    refute StatusStorage.has_status?(:player, 21, :sc_kyrie)
    assert hit_info.equipment_return_basis == 100
    assert hit_info.status_return_basis == 56
    assert :ok = deliver(target, 56, hit_info, {:player, 11})
  end

  test "hand components apply their own positive castle-ground minima after one aggregate status mutation" do
    _attacker = register_player(12, @castle_map)
    target = register_player(22, @castle_map)

    :ok = StatusInterpreter.apply_status(:player, 22, :sc_aeterna)
    expect_damage(target.pid, 2, {:player, 12})

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               22,
               swing(1, 1),
               ordinary_hit(),
               {:player, 12}
             )

    refute StatusStorage.has_status?(:player, 22, :sc_aeterna)
    assert settled.raw_total == 2
    assert settled.primary.damage == 1
    assert settled.secondary.damage == 1
    assert settled.primary.damage + settled.secondary.damage == 2
  end

  test "unprepared attack delivery uses the same shield then rate settlement" do
    _attacker = register_player(13, @castle_map)
    target = register_player(23, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 23, :sc_kyrie, val2: 30, val3: 5)
    expect_damage(target.pid, 56, {:player, 13})

    assert :ok = deliver(target, 100, ordinary_hit(), {:player, 13})
    refute StatusStorage.has_status?(:player, 23, :sc_kyrie)
  end

  test "equipment and status returns use distinct bases and bypass the source's statuses" do
    attacker = register_player(14, @castle_map, %{short_weapon_damage_return: 100})
    target = register_player(24, @castle_map, %{short_weapon_damage_return: 30})
    :ok = StatusInterpreter.apply_status(:player, 24, :sc_kyrie, val2: 30, val3: 5)
    :ok = StatusInterpreter.apply_status(:player, 24, :sc_reflectshield, val1: 10)
    :ok = StatusInterpreter.apply_status(:player, 14, :sc_kyrie, val2: 1_000, val3: 5)
    :ok = StatusInterpreter.apply_status(:player, 14, :sc_aeterna)
    :ok = StatusInterpreter.apply_status(:player, 14, :sc_reflectshield, val1: 10)

    expect_damage(target.pid, 56, {:player, 14})
    expect_damage(attacker.pid, 41, nil)

    assert {56, hit_info} = prepare(24, 100, ordinary_hit(), {:player, 14})
    assert :ok = deliver(target, 56, hit_info, {:player, 14})
    assert StatusStorage.has_status?(:player, 14, :sc_aeterna)

    assert %{state: %{shield_hp: 1_000, hits_remaining: 5}} =
             StatusStorage.get_status(:player, 14, :sc_kyrie)
  end

  test "raw self costs and status ticks on castle ground are not classified as attacks" do
    target = register_player(25, @castle_map, %{no_magic_damage: 50})
    expect_damage(target.pid, 100, {:player, 25})
    expect_damage(target.pid, 100, nil)

    assert :ok = deliver(target, 100, %{}, {:player, 25})

    tick = %{dmg_type: :magic, skill_id: nil, skill_level: nil, from_caster?: false}
    assert {100, hit_info} = prepare(25, 100, tick, nil)
    assert :ok = deliver(target, 100, hit_info, nil)
  end

  for {name, map, flags, ordinary, skill} <- [
        {"off-hours castle", @castle_map, [], 80, 60},
        {"active castle", @castle_map, [gvg: true], 80, 60},
        {"GvG without castle", "prontera", [gvg: true], 80, 60},
        {"ordinary PvE", "prontera", [], 100, 100},
        {"ordinary PvP", "prontera", [pvp: true], 100, 100}
      ] do
    test "#{name} rates distinguish ordinary range and skill origin" do
      map = unquote(map)
      Enum.each(unquote(flags), fn {flag, value} -> MapFlags.set_runtime(map, flag, value) end)
      _attacker = register_player(30, map)
      target = register_player(31, map)

      for short? <- [true, false] do
        expect_damage(target.pid, unquote(ordinary), {:player, 30})
        hit = %{ordinary_hit() | is_short: short?}
        assert {unquote(ordinary), prepared} = prepare(31, 100, hit, {:player, 30})
        assert :ok = deliver(target, unquote(ordinary), prepared, {:player, 30})
      end

      for type <- [:physical, :magic, :misc], direct? <- [true, false] do
        expect_damage(target.pid, unquote(skill), {:player, 30})

        expect(PlayerSession, :record_skill_hit, fn pid, 19, 1 ->
          assert pid == target.pid
          :ok
        end)

        hit = %{skill_hit(type) | from_caster?: direct?}
        assert {unquote(skill), prepared} = prepare(31, 100, hit, {:player, 30})
        assert :ok = deliver(target, unquote(skill), prepared, {:player, 30})
      end
    end
  end

  test "weapon skill returns each apply the original skill's rate" do
    attacker = register_player(32, @castle_map)
    target = register_player(33, @castle_map, %{short_weapon_damage_return: 30})
    :ok = StatusInterpreter.apply_status(:player, 33, :sc_kyrie, val2: 30, val3: 5)
    :ok = StatusInterpreter.apply_status(:player, 33, :sc_reflectshield, val1: 10)
    expect_damage(target.pid, 42, {:player, 32})

    expect(PlayerSession, :record_skill_hit, fn pid, 19, 1 ->
      assert pid == target.pid
      :ok
    end)

    expect_damage(attacker.pid, 27, nil)

    assert {42, hit_info} = prepare(33, 100, skill_hit(:physical), {:player, 32})
    assert :ok = deliver(target, 42, hit_info, {:player, 32})
  end

  test "each positive return has its own minimum but a rounded-zero return stays zero" do
    attacker = register_player(34, @castle_map)
    target = register_player(35, @castle_map, %{short_weapon_damage_return: 20})
    :ok = StatusInterpreter.apply_status(:player, 35, :sc_reflectshield, val1: 10)
    expect_damage(target.pid, 4, {:player, 34})
    expect_damage(attacker.pid, 2, nil)
    assert :ok = deliver(target, 5, ordinary_hit(), {:player, 34})

    expect_damage(target.pid, 1, {:player, 34})
    assert :ok = deliver(target, 1, ordinary_hit(), {:player, 34})
  end

  test "a fully blocked hit preserves zero HP loss and only its pre-status equipment return" do
    attacker = register_player(36, @castle_map)
    target = register_player(37, @castle_map, %{short_weapon_damage_return: 30})
    :ok = StatusInterpreter.apply_status(:player, 37, :sc_kyrie, val2: 1_000, val3: 5)
    :ok = StatusInterpreter.apply_status(:player, 37, :sc_reflectshield, val1: 10)
    expect_damage(target.pid, 0, {:player, 36})
    expect_damage(attacker.pid, 24, nil)

    assert :ok = deliver(target, 100, ordinary_hit(), {:player, 36})

    assert %{state: %{shield_hp: 900, hits_remaining: 4}} =
             StatusStorage.get_status(:player, 37, :sc_kyrie)
  end

  test "handed partial absorption distributes the remainder before component rates" do
    _attacker = register_player(38, @castle_map)
    target = register_player(39, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 39, :sc_kyrie, val2: 2, val3: 5)
    expect_damage(target.pid, 6, {:player, 38})

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               39,
               swing(7, 4),
               ordinary_hit(),
               {:player, 38}
             )

    assert settled.raw_total == 11
    assert settled.primary.damage == 4
    assert settled.secondary.damage == 2
    refute StatusStorage.has_status?(:player, 39, :sc_kyrie)
  end

  test "handed returns use raw equipment basis and the component-settled status basis" do
    attacker = register_player(67, @castle_map)
    target = register_player(68, @castle_map, %{short_weapon_damage_return: 100})
    :ok = StatusInterpreter.apply_status(:player, 68, :sc_aeterna)
    :ok = StatusInterpreter.apply_status(:player, 68, :sc_reflectshield, val1: 10)
    expect_damage(target.pid, 17, {:player, 67})
    expect_damage(attacker.pid, 12, nil)

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               68,
               swing(7, 4),
               ordinary_hit(),
               {:player, 67}
             )

    assert settled.raw_total == 11
    assert settled.primary.damage == 11
    assert settled.secondary.damage == 6
    refute StatusStorage.has_status?(:player, 68, :sc_aeterna)
  end

  test "primary-only settlement retains an absent secondary and the attack outcome" do
    _attacker = register_player(69, @castle_map)
    target = register_player(70, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 70, :sc_kyrie, val2: 30, val3: 5)
    expect_damage(target.pid, 56, {:player, 69})
    attack = %{swing(100, 0) | secondary: nil, outcome: :critical}

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               70,
               attack,
               ordinary_hit(),
               {:player, 69}
             )

    assert settled.primary.damage == 56
    assert settled.secondary == nil
    assert settled.outcome == :critical
  end

  test "fully blocked hands consume one shield hit and do not acquire minima" do
    _attacker = register_player(40, @castle_map)
    target = register_player(41, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 41, :sc_kyrie, val2: 100, val3: 5)
    expect_damage(target.pid, 0, {:player, 40})

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               41,
               swing(7, 4),
               ordinary_hit(),
               {:player, 40}
             )

    assert settled.primary.damage == 0
    assert settled.secondary.damage == 0

    assert %{state: %{shield_hp: 89, hits_remaining: 4}} =
             StatusStorage.get_status(:player, 41, :sc_kyrie)
  end

  test "zero hands and scalar zero do not consume Lex or create returns" do
    _attacker = register_player(42, @castle_map)
    target = register_player(43, @castle_map, %{short_weapon_damage_return: 100})
    :ok = StatusInterpreter.apply_status(:player, 43, :sc_aeterna)
    expect_damage(target.pid, 0, {:player, 42})
    assert :ok = deliver(target, 0, ordinary_hit(), {:player, 42})

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               43,
               swing(0, 0),
               ordinary_hit(),
               {:player, 42}
             )

    assert settled.primary.damage + settled.secondary.damage == 0
    assert StatusStorage.has_status?(:player, 43, :sc_aeterna)
  end

  for {shape, forwarded} <- [scalar: 56, handed: 55] do
    test "#{shape} Devotion forwards only settled damage without recipient absorption or returns" do
      _attacker = register_player(44, @castle_map)
      target = register_player(45, @castle_map)
      crusader = register_player(46, @castle_map, %{short_weapon_damage_return: 100})
      link_devotion(45, 46, @castle_map)
      :ok = StatusInterpreter.apply_status(:player, 45, :sc_kyrie, val2: 30, val3: 5)
      :ok = StatusInterpreter.apply_status(:player, 46, :sc_kyrie, val2: 1_000, val3: 5)
      :ok = StatusInterpreter.apply_status(:player, 46, :sc_aeterna)
      :ok = StatusInterpreter.apply_status(:player, 46, :sc_reflectshield, val1: 10)
      expect_damage(crusader.pid, unquote(forwarded), {:player, 44})
      expect_damage(target.pid, 0, {:player, 44})

      case unquote(shape) do
        :scalar ->
          assert {0, prepared} = prepare(45, 100, ordinary_hit(), {:player, 44})
          assert :ok = deliver(target, 0, prepared, {:player, 44})

        :handed ->
          assert {settled, :ok} =
                   DamageApplication.apply_weapon_swing(
                     :player,
                     target.pid,
                     45,
                     swing(60, 40),
                     ordinary_hit(),
                     {:player, 44}
                   )

          assert settled.primary.damage + settled.secondary.damage == 0
      end

      refute StatusStorage.has_status?(:player, 45, :sc_kyrie)
      assert StatusStorage.has_status?(:player, 46, :sc_aeterna)

      assert %{state: %{shield_hp: 1_000, hits_remaining: 5}} =
               StatusStorage.get_status(:player, 46, :sc_kyrie)
    end
  end

  test "blocked Devotion does not forward minimum-one damage" do
    _attacker = register_player(47, @castle_map)
    target = register_player(48, @castle_map)
    _crusader = register_player(49, @castle_map)
    link_devotion(48, 49, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 48, :sc_kyrie, val2: 100, val3: 5)
    expect_damage(target.pid, 0, {:player, 47})
    assert :ok = deliver(target, 10, ordinary_hit(), {:player, 47})

    assert %{state: %{shield_hp: 90, hits_remaining: 4}} =
             StatusStorage.get_status(:player, 48, :sc_kyrie)
  end

  test "non-ground Devotion still forwards before the devotee's shield" do
    _attacker = register_player(50, "prontera")
    target = register_player(51, "prontera")
    crusader = register_player(52, "prontera")
    link_devotion(51, 52, "prontera")
    :ok = StatusInterpreter.apply_status(:player, 51, :sc_kyrie, val2: 30, val3: 5)
    expect_damage(crusader.pid, 100, {:player, 50})
    expect_damage(target.pid, 0, {:player, 50})
    assert {0, hit_info} = prepare(51, 100, ordinary_hit(), {:player, 50})
    assert :ok = deliver(target, 0, hit_info, {:player, 50})

    assert %{state: %{shield_hp: 30, hits_remaining: 5}} =
             StatusStorage.get_status(:player, 51, :sc_kyrie)
  end

  test "non-ground returns retain delivered basis and source absorption" do
    attacker = register_player(53, "prontera")
    target = register_player(54, "prontera", %{short_weapon_damage_return: 30})
    :ok = StatusInterpreter.apply_status(:player, 54, :sc_kyrie, val2: 30, val3: 5)
    :ok = StatusInterpreter.apply_status(:player, 54, :sc_reflectshield, val1: 10)
    :ok = StatusInterpreter.apply_status(:player, 53, :sc_aeterna)
    expect_damage(target.pid, 70, {:player, 53})
    expect_damage(attacker.pid, 98, nil)
    assert {70, hit_info} = prepare(54, 100, ordinary_hit(), {:player, 53})
    assert :ok = deliver(target, 70, hit_info, {:player, 53})
    refute StatusStorage.has_status?(:player, 53, :sc_aeterna)
  end

  test "ineligible Emperium settlement leaves shields and Lex untouched in both entry shapes" do
    _attacker = register_player(55, @castle_map)
    {:ok, mob_data} = Mobs.by_id(1288)

    spawn = %MobSpawn{
      mob: 1288,
      amount: 1,
      respawn_time: 0,
      spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50}
    }

    mob = MobState.new(56, mob_data, spawn, @castle_map, 50, 50)
    :ok = UnitRegistry.register_unit(:mob, 56, MobState, mob, self())

    :ok =
      StatusInterpreter.apply_status(:mob, 56, :sc_kyrie,
        loaded: true,
        duration: 60_000,
        val2: 100,
        val3: 5
      )

    :ok = StatusInterpreter.apply_status(:mob, 56, :sc_aeterna, loaded: true, duration: 60_000)
    reject(&MobSession.apply_damage/3)
    reject(&MobSession.note_hit_type/3)

    assert {0, hit_info} =
             DamageApplication.prepare_unit_damage(:mob, 56, 10, ordinary_hit(), {:player, 55})

    assert {:error, :siege_inactive} =
             DamageApplication.apply_unit_damage(:mob, self(), 56, 0, hit_info, {:player, 55})

    assert {:error, :siege_inactive} =
             DamageApplication.apply_unit_damage(
               :mob,
               self(),
               56,
               10,
               ordinary_hit(),
               {:player, 55}
             )

    assert {settled, {:error, :siege_inactive}} =
             DamageApplication.apply_weapon_swing(
               :mob,
               self(),
               56,
               swing(7, 4),
               ordinary_hit(),
               {:player, 55}
             )

    assert settled.primary.damage + settled.secondary.damage == 0
    assert StatusStorage.has_status?(:mob, 56, :sc_aeterna)

    assert %{state: %{shield_hp: 100, hits_remaining: 5}} =
             StatusStorage.get_status(:mob, 56, :sc_kyrie)
  end

  test "reflected original magic retains skill reduction, Lex and one destination rate" do
    reflector = register_player(57, @castle_map, %{magic_damage_return: 100})
    caster = register_player(58, @castle_map, %{no_magic_damage: 50, magic_damage_return: 100})
    _crusader = register_player(59, @castle_map)
    link_devotion(58, 59, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 58, :sc_aeterna)
    :ok = StatusInterpreter.apply_status(:player, 58, :sc_kyrie, val2: 1_000, val3: 5)
    expect_damage(caster.pid, 60, {:player, 57})

    expect(PlayerSession, :record_skill_hit, fn pid, 19, 1 ->
      assert pid == caster.pid
      :ok
    end)

    reflected = Map.put(skill_hit(:magic), :reflected, true)
    assert {60, prepared} = prepare(58, 100, reflected, {:player, 57})
    assert prepared.skill_id == 19
    assert prepared.skill_level == 1
    assert :ok = deliver(caster, 60, prepared, {:player, 57})
    refute StatusStorage.has_status?(:player, 58, :sc_aeterna)

    assert %{state: %{shield_hp: 1_000, hits_remaining: 5}} =
             StatusStorage.get_status(:player, 58, :sc_kyrie)

    assert Process.alive?(reflector.pid)
  end

  test "fully immune redirected magic stays zero without consuming Lex" do
    _reflector = register_player(60, @castle_map)
    caster = register_player(61, @castle_map, %{no_magic_damage: 100})
    :ok = StatusInterpreter.apply_status(:player, 61, :sc_aeterna)
    expect_damage(caster.pid, 0, {:player, 60})

    expect(PlayerSession, :record_skill_hit, fn pid, 19, 1 ->
      assert pid == caster.pid
      :ok
    end)

    reflected = Map.put(skill_hit(:magic), :reflected, true)
    assert {0, prepared} = prepare(61, 100, reflected, {:player, 60})
    assert :ok = deliver(caster, 0, prepared, {:player, 60})
    assert StatusStorage.has_status?(:player, 61, :sc_aeterna)
  end

  test "same-owner Homunculus settlement and prepared returns remain local effects" do
    homunculus = %HomunculusState{
      id: 62,
      world_gid: 62,
      owner_character_id: 63,
      owner_session_pid: self(),
      class_id: 6001,
      name: "settlement",
      lifecycle: :active,
      map_name: @castle_map,
      x: 50,
      y: 50,
      hp: 100,
      max_hp: 100
    }

    :ok = UnitRegistry.register_unit(:homunculus, 62, HomunculusState, homunculus, self())
    _owner = register_player(63, @castle_map)
    target = register_player(64, @castle_map, %{short_weapon_damage_return: 30})
    :ok = StatusInterpreter.apply_status(:homunculus, 62, :sc_aeterna)

    assert {:local_effects, [{:homunculus, {:apply_damage, 62, 160, prepared, {:player, 64}}}]} =
             DamageApplication.apply_unit_damage(
               :homunculus,
               self(),
               62,
               100,
               ordinary_hit(),
               {:player, 64}
             )

    assert prepared.pre_delivery_prepared?
    refute StatusStorage.has_status?(:homunculus, 62, :sc_aeterna)
    :ok = StatusInterpreter.apply_status(:homunculus, 62, :sc_aeterna)
    expect_damage(target.pid, 80, {:homunculus, 62})

    assert {:local_effects, [{:homunculus, {:apply_damage, 62, 24, returned, nil}}]} =
             deliver(target, 100, ordinary_hit(), {:homunculus, 62})

    assert returned.pre_delivery_prepared?
    assert returned.reflected
    assert StatusStorage.has_status?(:homunculus, 62, :sc_aeterna)
  end

  test "zero hand components are not raised while a surviving secondary retains its minimum" do
    _attacker = register_player(65, @castle_map)
    target = register_player(66, @castle_map)
    :ok = StatusInterpreter.apply_status(:player, 66, :sc_kyrie, val2: 2, val3: 5)
    expect_damage(target.pid, 1, {:player, 65})

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               66,
               swing(0, 3),
               ordinary_hit(),
               {:player, 65}
             )

    assert settled.primary.damage == 0
    assert settled.secondary.damage == 1
  end

  defp skill_hit(type) do
    %{ordinary_hit() | dmg_type: type, skill_id: 19, skill_level: 1, basic_attack?: false}
  end

  defp link_devotion(devotee, crusader, map) do
    SpatialIndex.add_player(devotee, 50, 50, map)
    SpatialIndex.add_player(crusader, 51, 50, map)

    StatusStorage.apply_status(:player, devotee, :sc_devotion,
      state: %{peer: {:player, crusader}, link_id: make_ref(), range: 7}
    )
  end

  defp prepare(target_id, damage, hit_info, attacker) do
    DamageApplication.prepare_unit_damage(:player, target_id, damage, hit_info, attacker)
  end

  defp deliver(target, damage, hit_info, attacker) do
    DamageApplication.apply_unit_damage(
      :player,
      target.pid,
      target.state.character_id,
      damage,
      hit_info,
      attacker
    )
  end

  defp expect_damage(target_pid, damage, attacker) do
    expect(PlayerSession, :apply_damage, fn ^target_pid, ^damage, ^attacker -> :ok end)
  end

  defp register_player(id, map_name, equip_modifiers \\ %{}) do
    pid = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(pid, :kill) end)

    player =
      PlayerStateFixture.build(%{
        character_id: id,
        account_id: id,
        map_name: map_name,
        x: id,
        y: id,
        stats: %{
          base_stats: %{vit: 0, luk: 0},
          combat_stats: %CombatStats{},
          modifiers: %{equipment: equip_modifiers}
        }
      })

    :ok = UnitRegistry.register_player(player, pid)
    %{pid: pid, state: player}
  end

  defp swing(primary, secondary) do
    %HandedAttack{
      primary: %{damage: primary, is_critical: false},
      secondary: %{damage: secondary, is_critical: false},
      raw_total: primary + secondary,
      display_divisions: 1,
      outcome: :hit,
      primary_element: :neutral
    }
  end

  defp ordinary_hit do
    %{
      dmg_type: :physical,
      is_short: true,
      element: :neutral,
      skill_id: nil,
      skill_level: nil,
      from_caster?: true,
      basic_attack?: true
    }
  end
end

defmodule Aesir.ZoneServer.Mmo.Woe.DamageSettlementDeliveryTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicAttack
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    :ok = MapFlags.set_runtime("prontera", :pvp, true)
    :ok
  end

  test "real sessions receive one settled hit and prepared returns without touching source shields" do
    source = player({150, 150}, %{short_weapon_damage_return: 100})
    target = player({151, 150}, %{short_weapon_damage_return: 30})
    source_id = source.character.id
    target_id = target.character.id
    :ok = StatusInterpreter.apply_status(:player, target_id, :sc_kyrie, val2: 30, val3: 5)
    :ok = StatusInterpreter.apply_status(:player, target_id, :sc_reflectshield, val1: 10)
    :ok = StatusInterpreter.apply_status(:player, source_id, :sc_kyrie, val2: 1_000, val3: 5)
    before_source = hp(source)
    before_target = hp(target)

    assert :ok =
             DamageApplication.apply_unit_damage(
               :player,
               target.pid,
               target_id,
               100,
               melee_hit(),
               {:player, source_id}
             )

    assert_eventually(fn -> hp(target) == before_target - 56 end)
    assert_eventually(fn -> hp(source) == before_source - 41 end)

    assert %{state: %{shield_hp: 1_000, hits_remaining: 5}} =
             StatusStorage.get_status(:player, source_id, :sc_kyrie)
  end

  test "handed packet components equal the single real session HP loss" do
    source = player({150, 150}, %{})
    target = player({151, 150}, %{})
    target_id = target.character.id
    :ok = StatusInterpreter.apply_status(:player, target_id, :sc_aeterna)
    before = hp(target)

    swing = %HandedAttack{
      primary: %{damage: 1, is_critical: false},
      secondary: %{damage: 1, is_critical: false},
      raw_total: 2,
      display_divisions: 1,
      outcome: :hit,
      primary_element: :neutral
    }

    assert {settled, :ok} =
             DamageApplication.apply_weapon_swing(
               :player,
               target.pid,
               target_id,
               swing,
               melee_hit(),
               {:player, source.character.id}
             )

    attacker = PlayerState.to_combatant(get_player_state(source.pid))
    defender = PlayerState.to_combatant(get_player_state(target.pid))
    packet = PacketFactory.build_weapon_swing_packet(attacker, defender, settled)
    :ok = DamageApplication.broadcast_nearby(defender, packet)

    assert_eventually(fn -> hp(target) == before - 2 end)
    assert_receive {:packet_sent, %DamageDealt{target_id: ^target_id, damage: 1, damage2: 1}, _}
    refute StatusStorage.has_status?(:player, target_id, :sc_aeterna)
  end

  for {reduction, damage} <- [{50, 60}, {100, 0}] do
    test "original reflected spell with #{reduction}% equipment reduction matches packet and HP" do
      caster =
        player({150, 150}, %{no_magic_damage: unquote(reduction), magic_damage_return: 100})

      reflector = player({151, 150}, %{magic_damage_return: 100})
      caster_id = caster.character.id
      :ok = StatusInterpreter.apply_status(:player, caster_id, :sc_aeterna)
      before_caster = hp(caster)
      before_reflector = hp(reflector)

      assert {:ok, {:player, ^caster_id}} =
               MagicAttack.execute_magic_damage(
                 get_player_state(caster.pid),
                 {:player, reflector.character.id},
                 100,
                 skill_id: 19,
                 skill_level: 1,
                 element: :fire,
                 skip_range: true
               )

      assert_receive {:packet_sent,
                      %SkillDamage{
                        target_id: ^caster_id,
                        skill_id: 19,
                        damage: unquote(damage)
                      }, _}

      assert_eventually(fn -> hp(caster) == before_caster - unquote(damage) end)
      assert hp(reflector) == before_reflector
      assert StatusStorage.has_status?(:player, caster_id, :sc_aeterna) == (unquote(damage) == 0)
    end
  end

  defp player(position, equipment) do
    player = start_player_session(position: position, base_level: 99, vit: 0, luk: 0)

    :sys.replace_state(player.pid, fn session ->
      stats = session.game_state.stats

      stats = %{
        stats
        | current_state: %{stats.current_state | hp: stats.derived_stats.max_hp},
          modifiers: %{stats.modifiers | equipment: equipment}
      }

      %{session | game_state: %{session.game_state | stats: stats}}
    end)

    :ok =
      UnitRegistry.update_unit_state(:player, player.character.id, get_player_state(player.pid))

    player
  end

  defp hp(player), do: get_player_state(player.pid).stats.current_state.hp

  defp melee_hit do
    %{
      dmg_type: :physical,
      is_short: true,
      element: :neutral,
      skill_id: nil,
      skill_level: nil,
      basic_attack?: true,
      from_caster?: true
    }
  end
end
