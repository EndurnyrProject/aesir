defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgIntimidateTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgIntimidate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  setup do
    Mimic.copy(Cell)
    :ok
  end

  @caster_id 1_000
  @target_id 2_000

  test "deals 100 plus 30 percent per level, then defers the warp by 800 ms" do
    Catalog.reload()
    assert {:ok, definition} = Catalog.by_id(219)

    caster = player()
    target = mob()
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 219
      assert opts[:skill_level] == 4
      assert opts[:skill_ratio] == 220
      assert opts[:skip_range] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true, damage: 10, target_survives?: true}}
    end)

    assert {:ok, ^caster} = RgIntimidate.cast(caster, {:unit, @target_id}, 4, definition)

    refute_receive {:skill, {:deferred, RgIntimidate, _payload}}, 700

    assert_receive {:skill,
                    {:deferred, RgIntimidate,
                     %{
                       target: @target_id,
                       map_name: "prontera",
                       caster_id: @caster_id,
                       deferred_epoch: 7
                     }}},
                   300
  end

  test "the warp needs damage, not the hit's additional-effect stage" do
    caster = player()
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), mob(), :mob} end)

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
      {:ok, %{hit?: false, blocked?: true, damage: 10, target_survives?: true}}
    end)

    assert {:ok, ^caster} = RgIntimidate.cast(caster, {:unit, @target_id}, 1, definition())
    assert_receive {:skill, {:deferred, RgIntimidate, _payload}}, 1_000

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
      {:ok, %{hit?: false, blocked?: true, damage: 0, target_survives?: true}}
    end)

    assert {:ok, ^caster} = RgIntimidate.cast(caster, {:unit, @target_id}, 1, definition())
    refute_receive {:skill, {:deferred, RgIntimidate, _payload}}, 1_000
  end

  test "no warp against a status-immune target or when the chance fails" do
    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
      {:ok, %{hit?: true, damage: 10, target_survives?: true}}
    end)

    boss = %{
      mob()
      | mob_data: %{mob().mob_data | modes: [:detector, :status_immune, :knockback_immune]}
    }

    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), boss, :mob} end)
    assert {:ok, _caster} = RgIntimidate.cast(player(), {:unit, @target_id}, 5, definition())

    # 50 + 5 * 5 + (1 - 99) is below zero: the roll can never land.
    strong = %{mob() | mob_data: %{mob().mob_data | level: 99}}
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), strong, :mob} end)
    weak_caster = put_in(player().stats.progression.base_level, 1)
    assert {:ok, _caster} = RgIntimidate.cast(weak_caster, {:unit, @target_id}, 5, definition())

    refute_receive {:skill, {:deferred, RgIntimidate, _payload}}, 1_000
  end

  test "a monster's damaging hit on a Homunculus rolls with the Homunculus level" do
    caster = %{mob() | instance_id: @caster_id, deferred_epoch: 7}

    homunculus = %HomunculusState{
      id: 9,
      owner_character_id: 1,
      class_id: 6001,
      name: "Lif",
      level: 1
    }

    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), homunculus, :homunculus} end)

    stub(Combat, :execute_skill_attack, fn _caster, @target_id, _opts ->
      {:ok, %{hit?: true, damage: 10, target_survives?: true}}
    end)

    # 50 + 5 + (1 - 1) leaves a 55% chance; the seed below rolls under it.
    :rand.seed(:exsss, {1, 2, 3})
    assert {:ok, ^caster} = RgIntimidate.cast(caster, {:unit, @target_id}, 1, definition())
    assert_receive {:skill, {:deferred, RgIntimidate, _payload}}, 1_000
  end

  defp definition do
    Catalog.reload()
    {:ok, definition} = Catalog.by_id(219)
    definition
  end

  @payload %{map_name: "prontera", caster_id: @caster_id, deferred_epoch: 7}

  test "warps the caster to a random cell and a player target beside it" do
    caster = player()
    target = player(@target_id, 3)
    caster_pid = self()
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(target_pid, :kill) end)

    stub(TargetResolver, :resolve, fn {:player, @target_id} ->
      {:ok, target_pid, target, :player}
    end)

    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {44, 55}} end)
    expect(Cell, :random_traversable_near, fn "prontera", {44, 55}, 1 -> {45, 54} end)
    expect(PlayerSession, :warp, fn ^caster_pid, "prontera", 44, 55 -> :ok end)
    expect(PlayerSession, :warp, fn ^target_pid, "prontera", 45, 54 -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_intimidate, opts ->
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :player
      :ok
    end)

    assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:player, @target_id}), caster)
  end

  test "warps a mob target beside the caster's new cell" do
    caster = player()
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(target_pid, :kill) end)

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, target_pid, mob(), :mob} end)
    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {66, 77}} end)
    expect(Cell, :random_traversable_near, fn "prontera", {66, 77}, 1 -> {66, 78} end)
    expect(PlayerSession, :warp, fn _caster_pid, "prontera", 66, 77 -> :ok end)
    expect(MobSession, :warp, fn ^target_pid, "prontera", 66, 78 -> :ok end)
    stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_intimidate, _opts -> :ok end)

    assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:mob, @target_id}), caster)
  end

  test "a Homunculus target moves through its owner's session" do
    owner_pid = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(owner_pid, :kill) end)

    homunculus = %HomunculusState{
      id: 9,
      world_gid: 9,
      owner_character_id: 1,
      class_id: 6001,
      name: "Lif",
      map_name: "prontera",
      x: 11,
      y: 10,
      hp: 50,
      lifecycle: :active,
      action_state: :idle
    }

    stub(TargetResolver, :resolve, fn {:homunculus, 9} ->
      {:ok, owner_pid, homunculus, :homunculus}
    end)

    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {30, 30}} end)
    expect(Cell, :random_traversable_near, fn "prontera", {30, 30}, 1 -> {31, 30} end)
    expect(PlayerSession, :warp, fn _caster_pid, "prontera", 30, 30 -> :ok end)

    expect(PlayerSession, :warp_homunculus, fn ^owner_pid, 9, 11, 10, "prontera", 31, 30 ->
      :ok
    end)

    stub(StatusInterpreter, :apply_status, fn :homunculus, 9, :sc_intimidate, _opts -> :ok end)

    assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:homunculus, 9}), player())
  end

  test "a dead, vanished or more than 14 cells away target stays behind while the caster warps alone" do
    dead = %{mob() | hp: 0, is_dead: true}
    away = %{mob() | x: 10 + 15}
    edge = %{mob() | x: 10 + 14}

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), edge, :mob} end)
    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {44, 55}} end)
    stub(Cell, :random_traversable_near, fn "prontera", {44, 55}, 1 -> {45, 55} end)
    expect(PlayerSession, :warp, fn _caster_pid, "prontera", 44, 55 -> :ok end)
    expect(MobSession, :warp, fn _pid, "prontera", 45, 55 -> :ok end)
    stub(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_intimidate, _opts -> :ok end)
    assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:mob, @target_id}), player())

    for resolved <- [{:ok, self(), dead, :mob}, {:error, :not_found}, {:ok, self(), away, :mob}] do
      stub(TargetResolver, :resolve, fn {:mob, @target_id} -> resolved end)
      expect(Cell, :random_traversable, fn "prontera" -> {:ok, {44, 55}} end)
      stub(Cell, :random_traversable_near, fn "prontera", {44, 55}, 1 -> {45, 55} end)
      expect(PlayerSession, :warp, fn _caster_pid, "prontera", 44, 55 -> :ok end)
      reject(&MobSession.warp/4)
      reject(&StatusInterpreter.apply_status/4)

      assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:mob, @target_id}), player())
    end
  end

  test "a target in view coordinates on another map stops the warp" do
    elsewhere = %{mob() | map_name: "geffen"}

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), elsewhere, :mob} end)
    reject(&Cell.random_traversable/1)
    reject(&PlayerSession.warp/4)
    reject(&MobSession.warp/4)

    assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:mob, @target_id}), player())
  end

  test "a player caster on a no-teleport map does not move" do
    Mimic.copy(MapFlags)
    stub(MapFlags, :get, fn "prontera", :noteleport -> true end)
    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), mob(), :mob} end)
    reject(&Cell.random_traversable/1)
    reject(&PlayerSession.warp/4)
    reject(&MobSession.warp/4)

    assert :ok = RgIntimidate.deferred(Map.put(@payload, :target, {:mob, @target_id}), player())
  end

  defp player(character_id \\ @caster_id, deferred_epoch \\ 7) do
    %PlayerState{
      character_id: character_id,
      map_name: "prontera",
      x: 10,
      y: 10,
      action_state: :idle,
      deferred_epoch: deferred_epoch,
      stats: %Stats{
        current_state: %CurrentState{hp: 100, sp: 100},
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{base_level: 99}
      }
    }
  end

  defp mob do
    %MobState{
      instance_id: @target_id,
      mob_id: 1_002,
      mob_data: %{element: {:neutral, 1}, race: :formless, modes: [], level: 1},
      spawn_ref: nil,
      map_name: "prontera",
      x: 10,
      y: 11,
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0,
      deferred_epoch: 3
    }
  end
end
