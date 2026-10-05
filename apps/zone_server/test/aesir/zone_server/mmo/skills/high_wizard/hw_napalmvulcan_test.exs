defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwNapalmvulcanTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwNapalmvulcan
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  setup do
    stub(Combat, :resolve_combatant, fn 3001 -> {:ok, %{position: {110, 100}}} end)
    :ok
  end

  defp player do
    PlayerState.new(%Character{
      id: 1001,
      account_id: 1001,
      name: "HighWizard",
      class: 4010,
      sex: "M",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      base_level: 99,
      hp: 100,
      sp: 100
    })
  end

  defp mob do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    MobState.new(2001, definition, spawn, "prontera", 100, 100)
  end

  defp cast(caster, level),
    do: HwNapalmvulcan.cast(caster, {:unit, 3001}, level, HwNapalmvulcan.definition())

  @tag game_mode: :renewal
  test "renewal hits lv rounds at 70% per level, unscaled at base level 99, unsplit" do
    caster = player()
    stub(Resistance, :roll_success, fn _rate -> false end)

    expect(Combat, :execute_magic_splash, fn ^caster, {110, 100}, 1, opts ->
      assert opts[:skill_ratio] == 350
      assert opts[:hit_divisions] == 5
      assert opts[:element] == :ghost
      refute opts[:split]
      []
    end)

    assert {:ok, ^caster} = cast(caster, 5)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal splits a flat 125% among the targets" do
    caster = player()
    stub(Resistance, :roll_success, fn _rate -> false end)

    expect(Combat, :execute_magic_splash, fn ^caster, {110, 100}, 1, opts ->
      assert opts[:skill_ratio] == 125
      assert opts[:split]
      []
    end)

    assert {:ok, ^caster} = cast(caster, 5)
  end

  test "each struck target is cursed on a successful 5% per level roll" do
    caster = mob()
    test_pid = self()

    stub(Combat, :execute_magic_splash, fn ^caster, _center, 1, _opts ->
      [{:player, 7}, {:mob, 8}]
    end)

    expect(Resistance, :roll_success, 2, fn 15 -> true end)

    stub(StatusInterpreter, :apply_status, fn type, id, :sc_curse, params ->
      send(test_pid, {:cursed, type, id, params[:duration], params[:source_type]})
      :ok
    end)

    assert {:ok, ^caster} = cast(caster, 3)

    duration = if Aesir.Commons.GameMode.mode() == :renewal, do: 18_000, else: 30_000
    assert_received {:cursed, :player, 7, ^duration, :mob}
    assert_received {:cursed, :mob, 8, ^duration, :mob}
  end

  test "a failed roll curses nobody" do
    stub(Combat, :execute_magic_splash, fn _caster, _center, 1, _opts -> [{:mob, 8}] end)
    stub(Resistance, :roll_success, fn _rate -> false end)
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, _caster} = cast(player(), 3)
  end
end
