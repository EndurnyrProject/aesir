defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscMeteorassaultTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscMeteorassault
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    previous = Application.get_env(:zone_server, :meteor_assault_rng)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :meteor_assault_rng, previous),
        else: Application.delete_env(:zone_server, :meteor_assault_rng)
    end)

    {:ok, definition} = Catalog.by_id(406)
    %{definition: definition, caster: %PlayerState{character_id: 42, x: 10, y: 20}}
  end

  describe "skill_ratio/2" do
    @tag game_mode: :renewal
    test "renewal is 200 + 120 per level, scaled above base level 99" do
      assert AscMeteorassault.skill_ratio(10, 99) == 1400
      # 1400 * 150 / 100
      assert AscMeteorassault.skill_ratio(10, 150) == 2100
    end

    @tag game_mode: :pre_renewal
    test "classic is 40 + 40 per level" do
      assert AscMeteorassault.skill_ratio(1, 150) == 80
      assert AscMeteorassault.skill_ratio(10, 150) == 440
    end
  end

  test "splashes the 5x5 area around the caster, traps included", %{
    caster: caster,
    definition: definition
  } do
    expect(Combat, :execute_splash_attack, fn ^caster, {10, 20}, 2, opts ->
      assert opts[:skill_id] == 406
      assert opts[:skill_level] == 5
      assert opts[:skip_crit] == true
      assert opts[:target_skill_units] == true
      assert opts[:typed_results] == true
      []
    end)

    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, ^caster} = AscMeteorassault.cast(caster, :self, 5, definition)
  end

  for {draw, status} <- [{1, :sc_blind}, {2, :sc_stun}, {3, :sc_bleeding}] do
    @tag draw: draw, status: status
    test "a hit character rolls #{status} at 5 + 5 per level, a trap rolls nothing", %{
      caster: caster,
      definition: definition,
      draw: draw,
      status: status
    } do
      Application.put_env(:zone_server, :meteor_assault_rng, fn 3 -> draw end)

      stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, _opts ->
        [{:mob, 7}, {:skill_unit, 9}]
      end)

      expect(StatusInterpreter, :apply_status, fn :mob, 7, ^status, params ->
        assert params[:success_rate] == 30
        assert params[:val1] == 5
        assert params[:caster_id] == 42
        assert params[:source_type] == :player
        assert params[:duration] == AscMeteorassault.rider_duration(status)
        if status == :sc_bleeding, do: assert(params[:val2] == 42)
        :ok
      end)

      assert {:ok, ^caster} = AscMeteorassault.cast(caster, :self, 5, definition)
    end
  end

  @tag game_mode: :renewal
  test "renewal rider durations" do
    assert Enum.map([:sc_blind, :sc_stun, :sc_bleeding], &AscMeteorassault.rider_duration/1) ==
             [20_000, 5_000, 120_000]
  end

  @tag game_mode: :pre_renewal
  test "classic rider durations" do
    assert Enum.map([:sc_blind, :sc_stun, :sc_bleeding], &AscMeteorassault.rider_duration/1) ==
             [30_000, 5_000, 120_000]
  end

  test "a monster centres it on itself and rides as itself", %{definition: definition} do
    mob = %MobState{
      instance_id: 77,
      mob_id: 1_002,
      spawn_ref: nil,
      map_name: "prontera",
      hp: 100,
      sp: 0,
      spawned_at: 0,
      x: 3,
      y: 4,
      mob_data: %{level: 120}
    }

    Application.put_env(:zone_server, :meteor_assault_rng, fn 3 -> 2 end)

    expect(Combat, :execute_splash_attack, fn ^mob, {3, 4}, 2, _opts -> [{:player, 1}] end)

    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_stun, params ->
      assert params[:caster_id] == 77
      assert params[:source_type] == :mob
      :ok
    end)

    assert {:ok, ^mob} = AscMeteorassault.cast(mob, {:unit, 77}, 10, definition)
  end
end
