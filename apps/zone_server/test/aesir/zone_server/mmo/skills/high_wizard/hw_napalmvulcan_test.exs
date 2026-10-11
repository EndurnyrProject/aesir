defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwNapalmvulcanTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwNapalmvulcan
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  setup do
    stub(Combat, :resolve_combatant, fn 3001 ->
      {:ok, %{unit_type: :mob, unit_id: 3001, position: {110, 100}}}
    end)

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

    expect(Combat, :execute_magic_splash, fn ^caster, {110, 100}, 1, opts ->
      assert opts[:skill_ratio] == 125
      assert opts[:split]
      []
    end)

    assert {:ok, ^caster} = cast(caster, 5)
  end

  # The splash runs the skill's on-hit effect once per connected hit, with the
  # hit's effective source.
  defp run_effect_per_hit(opts, source, refs) do
    effect = Keyword.fetch!(opts, :additional_effect)
    Enum.each(refs, &effect.(source, &1))
    refs
  end

  test "each struck target receives the 5% per level curse chance" do
    caster = mob()
    source = MobState.to_combatant(caster)
    test_pid = self()

    stub(Combat, :execute_magic_splash, fn ^caster, _center, 1, opts ->
      run_effect_per_hit(opts, source, [{:player, 7}, {:mob, 8}])
    end)

    stub(StatusInterpreter, :apply_status, fn type, id, :sc_curse, params ->
      assert params[:success_rate] == 15
      send(test_pid, {:cursed, type, id, params[:duration], params[:source_type]})
      :ok
    end)

    assert {:ok, ^caster} = cast(caster, 3)

    duration = if Aesir.Commons.GameMode.mode() == :renewal, do: 18_000, else: 30_000
    assert_received {:cursed, :player, 7, ^duration, :mob}
    assert_received {:cursed, :mob, 8, ^duration, :mob}
  end

  test "forwards the 5% per level curse chance" do
    caster = player()
    source = PlayerState.to_combatant(caster)

    stub(Combat, :execute_magic_splash, fn ^caster, _center, 1, opts ->
      run_effect_per_hit(opts, source, [{:mob, 8}])
    end)

    expect(StatusInterpreter, :apply_status, fn :mob, 8, :sc_curse, params ->
      assert params[:success_rate] == 15
      {:error, :resisted}
    end)

    assert {:ok, ^caster} = cast(caster, 3)
  end

  test "a reflected round curses the caster with the reflector as its source" do
    caster = player()
    test_pid = self()
    reflector = %{unit_type: :mob, unit_id: 8}

    stub(Combat, :execute_magic_splash, fn ^caster, _center, 1, opts ->
      run_effect_per_hit(opts, reflector, [{:player, 1001}])
    end)

    stub(StatusInterpreter, :apply_status, fn type, id, :sc_curse, params ->
      assert params[:success_rate] == 15
      send(test_pid, {:cursed, type, id, params[:caster_id], params[:source_type]})
      :ok
    end)

    assert {:ok, ^caster} = cast(caster, 3)
    assert_received {:cursed, :player, 1001, 8, :mob}
  end
end
