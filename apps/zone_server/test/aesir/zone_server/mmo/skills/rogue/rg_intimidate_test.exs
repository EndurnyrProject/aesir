defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgIntimidateTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgIntimidate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Stats.CurrentState
  alias Aesir.ZoneServer.Unit.Stats.DerivedStats

  setup :verify_on_exit!

  setup do
    Mimic.copy(Cell)
    :ok
  end

  @caster_id 1_000
  @target_id 2_000

  test "is discovered and deals 30 percent per level before deferring the warp" do
    Catalog.reload()
    assert {:ok, RgIntimidate} = Catalog.active_module_for(:rg_intimidate)
    assert {:ok, definition} = Catalog.by_id(219)

    assert definition.display_name == "Snatch"
    assert definition.max_level == 5
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :damage
    assert definition.range == 1

    caster = player()
    target = mob()
    stub(TargetResolver, :resolve, fn @target_id -> {:ok, self(), target, :mob} end)

    expect(Combat, :execute_skill_attack, fn ^caster, @target_id, opts ->
      assert opts[:skill_id] == 219
      assert opts[:skill_level] == 4
      assert opts[:skill_ratio] == 120
      assert opts[:skip_range] == true
      assert opts[:report_hit] == true
      {:ok, %{hit?: true, damage: 10, target_survives?: true}}
    end)

    assert {:ok, ^caster} = RgIntimidate.cast(caster, {:unit, @target_id}, 4, definition)

    assert_receive {:skill,
                    {:deferred, RgIntimidate,
                     %{
                       target: @target_id,
                       map_name: "prontera",
                       caster_id: @caster_id,
                       deferred_epoch: 7,
                       target_epoch: 3
                     }}}
  end

  test "warps a player target and its caster to one traversable cell after a hit" do
    caster = player()
    target = player(@target_id, 3)
    caster_pid = self()
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(target_pid, :kill) end)

    stub(TargetResolver, :resolve, fn {:player, @target_id} ->
      {:ok, target_pid, target, :player}
    end)

    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {44, 55}} end)
    expect(PlayerSession, :warp, fn ^target_pid, "prontera", 44, 55 -> :ok end)
    expect(PlayerSession, :warp, fn ^caster_pid, "prontera", 44, 55 -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_intimidate, opts ->
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :player
      :ok
    end)

    payload = %{
      target: {:player, @target_id},
      map_name: "prontera",
      caster_id: @caster_id,
      deferred_epoch: 7,
      target_epoch: 3
    }

    assert :ok = RgIntimidate.deferred(payload, caster)
  end

  test "warps a mob target and its caster to one traversable cell after a hit" do
    caster = player()
    target = mob()
    caster_pid = self()
    target_pid = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(target_pid, :kill) end)

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, target_pid, target, :mob} end)
    expect(Cell, :random_traversable, fn "prontera" -> {:ok, {66, 77}} end)
    expect(MobSession, :warp, fn ^target_pid, "prontera", 66, 77 -> :ok end)
    expect(PlayerSession, :warp, fn ^caster_pid, "prontera", 66, 77 -> :ok end)

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_intimidate, opts ->
      assert opts[:caster_id] == @caster_id
      assert opts[:source_type] == :player
      :ok
    end)

    payload = %{
      target: {:mob, @target_id},
      map_name: "prontera",
      caster_id: @caster_id,
      deferred_epoch: 7,
      target_epoch: 3
    }

    assert :ok = RgIntimidate.deferred(payload, caster)
  end

  test "drops a deferred warp when the target epoch is stale" do
    caster = player()
    target = mob()

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), target, :mob} end)
    reject(&Cell.random_traversable/1)
    reject(&MobSession.warp/4)
    reject(&PlayerSession.warp/4)
    reject(&StatusInterpreter.apply_status/4)

    payload = %{
      target: {:mob, @target_id},
      map_name: "prontera",
      caster_id: @caster_id,
      deferred_epoch: 7,
      target_epoch: 4
    }

    assert :ok = RgIntimidate.deferred(payload, caster)
  end

  test "drops a deferred warp when the target died after the hit" do
    caster = player()
    target = %{mob() | hp: 0, is_dead: true}

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), target, :mob} end)
    reject(&Cell.random_traversable/1)
    reject(&MobSession.warp/4)
    reject(&PlayerSession.warp/4)
    reject(&StatusInterpreter.apply_status/4)

    payload = %{
      target: {:mob, @target_id},
      map_name: "prontera",
      caster_id: @caster_id,
      deferred_epoch: 7,
      target_epoch: 3
    }

    assert :ok = RgIntimidate.deferred(payload, caster)
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
        derived_stats: %DerivedStats{max_hp: 100, max_sp: 100}
      }
    }
  end

  defp mob do
    %MobState{
      instance_id: @target_id,
      mob_id: 1_002,
      mob_data: %{element: {:neutral, 1}, race: :formless, modes: []},
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
