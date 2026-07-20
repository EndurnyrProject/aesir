defmodule Aesir.ZoneServer.Mmo.Skills.PrBenedictioTest do
  @moduledoc """
  Renewal parity coverage for `src/map/skill.cpp:7907-8001,8012-8078,8552-8557,9388-9390`
  and `src/map/skills/acolyte/bssacramenti.cpp:12-38`.
  """
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.PrBenedictio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @caster_id 1_000

  defp player(id, x, y, opts) do
    %PlayerState{
      character_id: id,
      x: x,
      y: y,
      map_name: "prontera",
      dir: Keyword.get(opts, :dir, 0),
      action_state: Keyword.get(opts, :action_state, :idle),
      party_id: Keyword.get(opts, :party_id, 0),
      temp_vars: Keyword.get(opts, :temp_vars, %{}),
      stats: %{
        progression: %{job_id: Keyword.get(opts, :job_id, 4)},
        current_state: %{hp: Keyword.get(opts, :hp, 100), sp: Keyword.get(opts, :sp, 100)}
      }
    }
  end

  defp register_player(
         %PlayerState{character_id: id, x: x, y: y} = state,
         pid \\ self(),
         module \\ PlayerState
       ) do
    :ok = UnitRegistry.register_unit(:player, id, module, state, pid)
    :ok = SpatialIndex.add_unit(:player, id, x, y, state.map_name)
    state
  end

  defp real_player(id, x, y, opts \\ []) do
    state =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Benedictio#{id}",
        last_map: "prontera",
        last_x: x,
        last_y: y,
        class: 0,
        base_level: 100,
        job_level: 50,
        sex: "M",
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })

    state =
      case Keyword.get(opts, :defense_element) do
        nil -> state
        element -> put_in(state.stats.modifiers.status_effects, %{element_override: element})
      end

    if Keyword.get(opts, :dead, false) do
      state
      |> put_in([Access.key!(:stats), Access.key!(:current_state), Access.key!(:hp)], 0)
      |> Map.put(:action_state, :dead)
    else
      state
    end
  end

  defp mob(id, race, element, x, y) do
    definition = %MobDefinition{
      id: id,
      aegis_name: "BENEDICTIO_TARGET",
      name: "Benedictio Target",
      level: 1,
      hp: 1_000,
      sp: 1,
      base_exp: 0,
      job_exp: 0,
      atk: 1,
      matk: 1,
      def: 0,
      mdef: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      skill_range: 1,
      chase_range: 1,
      element: {element, 1},
      race: race,
      size: :medium,
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400,
      ai_type: 0,
      modes: [],
      drops: []
    }

    %MobState{
      instance_id: id,
      mob_id: id,
      mob_data: definition,
      spawn_ref: %MobSpawn{
        mob: id,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: x, y: y, xs: 0, ys: 0}
      },
      x: x,
      y: y,
      map_name: "prontera",
      hp: 1_000,
      max_hp: 1_000,
      sp: 1,
      max_sp: 1,
      is_dead: false,
      spawned_at: 0
    }
  end

  defp register_mob(%MobState{instance_id: id, x: x, y: y} = state) do
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, x, y, state.map_name)
    state
  end

  defp register_formation(caster_opts \\ []) do
    caster = register_player(player(@caster_id, 150, 150, [dir: 4] ++ caster_opts))
    west = register_player(player(1_001, 149, 150, job_id: 4, sp: 0, party_id: 41))
    east = register_player(player(1_002, 151, 150, job_id: 4_005, sp: 0, party_id: 42))
    {caster, west, east}
  end

  test "exposes the exact Renewal metadata without a ground-unit capability" do
    assert {:ok, definition} = Catalog.by_id(69)
    assert definition.name == :pr_benedictio
    assert definition.status == :sc_benedictio
    assert definition.max_level == 5
    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.damage_kind == :magic
    assert definition.range == 9
    assert definition.element == :holy
    assert definition.splash_radius == 1
    assert definition.sp_cost == List.duplicate(20, 5)
    assert definition.duration == [40_000, 80_000, 120_000, 160_000, 200_000]
    assert PrBenedictio.__skill_capabilities__() == [:active]
  end

  test "requires exactly two castable living Acolyte-family companions in the relative side cells" do
    {caster, _west, _east} = register_formation()
    register_player(player(1_003, 151, 151, job_id: 4_027))
    register_player(player(1_004, 150, 149, job_id: 4))

    assert :ok = PrBenedictio.validate(caster, {:ground, 160, 160}, 1, PrBenedictio.definition())

    UnitRegistry.unregister_unit(:player, 1_002)

    assert {:error, :insufficient_companions} =
             PrBenedictio.validate(caster, {:ground, 160, 160}, 1, PrBenedictio.definition())
  end

  test "candidate eligibility checks caster SP rather than companion SP and does not require a party" do
    {caster, _west, _east} = register_formation(sp: 10)

    assert :ok = PrBenedictio.validate(caster, {:ground, 150, 150}, 1, PrBenedictio.definition())

    caster = put_in(caster.stats.current_state.sp, 9)

    assert {:error, :insufficient_companions} =
             PrBenedictio.validate(caster, {:ground, 150, 150}, 1, PrBenedictio.definition())
  end

  test "dead, non-Acolyte, and skill-blocked neighbors are not eligible" do
    caster = register_player(player(@caster_id, 150, 150, dir: 4, sp: 100))
    register_player(player(1_001, 149, 150, job_id: 5))
    register_player(player(1_002, 151, 150, job_id: 4, hp: 0, action_state: :dead))
    register_player(player(1_003, 149, 150, job_id: 4))
    register_player(player(1_004, 151, 150, job_id: 4))

    stub(StatusInterpreter, :can_use_skill?, fn
      :player, 1_003 -> false
      :player, _id -> true
    end)

    assert {:error, :insufficient_companions} =
             PrBenedictio.validate(caster, {:ground, 150, 150}, 1, PrBenedictio.definition())
  end

  test "completion caps the participant set at two and ignores both companion charge failures" do
    test_pid = self()
    {caster, _west, _east} = register_formation()
    register_player(player(1_003, 149, 150, job_id: 4_027), test_pid)
    register_player(real_player(2_001, 160, 160), test_pid)

    stub(PlayerSession, :try_consume_sp, fn pid, 10 ->
      send(test_pid, {:charge, pid})
      {:error, :insufficient_sp}
    end)

    stub(StatusInterpreter, :apply_status, fn :player, target_id, :sc_benedictio, params ->
      send(test_pid, {:buff, target_id, params})
      :ok
    end)

    stub(Combat, :splash_targets, fn "prontera", {160, 160}, 1, @caster_id -> [] end)

    assert {:ok, ^caster} =
             PrBenedictio.cast(caster, {:ground, 160, 160}, 3, PrBenedictio.definition())

    assert_received {:buff, 2_001, params}
    assert params[:val1] == 3
    assert params[:duration] == 120_000
    assert params[:caster_id] == @caster_id
    assert_received {:charge, _pid}
    assert_received {:charge, _pid}
    refute_received {:charge, _pid}
  end

  test "completion revalidates the formation before charging or applying either area pass" do
    {caster, _west, _east} = register_formation()
    :ok = SpatialIndex.update_unit_position(:player, 1_002, 170, 170, "prontera")

    reject(&PlayerSession.try_consume_sp/2)
    reject(&StatusInterpreter.apply_status/4)
    reject(&Combat.splash_targets/4)

    assert {:error, :insufficient_companions} =
             PrBenedictio.cast(caster, {:ground, 160, 160}, 1, PrBenedictio.definition())
  end

  test "the immediate PC pass buffs only living non-undead and non-demon players in the 3x3 square" do
    test_pid = self()
    {caster, _west, _east} = register_formation()
    register_player(real_player(2_001, 160, 160), test_pid)
    register_player(real_player(2_002, 161, 161, defense_element: {:undead, 1}), test_pid)
    register_player(real_player(2_003, 160, 161, dead: true), test_pid)
    register_player(real_player(2_004, 162, 160), test_pid)

    stub(PlayerSession, :try_consume_sp, fn _pid, 10 -> :ok end)
    stub(Combat, :splash_targets, fn "prontera", {160, 160}, 1, @caster_id -> [] end)

    stub(StatusInterpreter, :apply_status, fn :player, target_id, :sc_benedictio, _params ->
      send(test_pid, {:buff, target_id})
      :ok
    end)

    assert {:ok, ^caster} =
             PrBenedictio.cast(caster, {:ground, 160, 160}, 1, PrBenedictio.definition())

    assert_received {:buff, 2_001}
    refute_received {:buff, 2_002}
    refute_received {:buff, 2_003}
    refute_received {:buff, 2_004}
  end

  test "the immediate enemy pass deals Holy magic only to undead and demon characters" do
    test_pid = self()
    {caster, _west, _east} = register_formation()
    register_mob(mob(3_001, :undead, :neutral, 160, 160))
    register_mob(mob(3_002, :formless, :undead, 161, 161))
    register_mob(mob(3_003, :demon, :dark, 159, 160))
    register_mob(mob(3_004, :brute, :neutral, 160, 159))

    stub(PlayerSession, :try_consume_sp, fn _pid, 10 -> :ok end)
    stub(StatusInterpreter, :apply_status, fn _type, _id, _status, _params -> :ok end)

    stub(Combat, :splash_targets, fn "prontera", {160, 160}, 1, @caster_id ->
      [{:mob, 3_001}, {:mob, 3_002}, {:mob, 3_003}, {:mob, 3_004}]
    end)

    stub(Combat, :execute_magic_attack, fn ^caster, target_id, opts ->
      send(test_pid, {:damage, target_id, opts})
      :ok
    end)

    assert {:ok, ^caster} =
             PrBenedictio.cast(caster, {:ground, 160, 160}, 5, PrBenedictio.definition())

    for target_id <- [3_001, 3_002, 3_003] do
      assert_received {:damage, ^target_id, opts}
      assert opts[:skill_id] == 69
      assert opts[:skill_level] == 5
      assert opts[:skill_ratio] == 100
      assert opts[:element] == :holy
      assert opts[:ignore_mdef]
      assert opts[:skip_range]
    end

    refute_received {:damage, 3_004, _opts}
  end
end
