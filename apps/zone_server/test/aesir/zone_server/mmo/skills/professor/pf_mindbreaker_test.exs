defmodule Aesir.ZoneServer.Mmo.Skills.Professor.PfMindbreakerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Professor.PfMindbreaker
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :setup_ets_tables

  @caster %PlayerState{character_id: 9_101, map_name: "prontera", x: 100, y: 100}
  @mob_id 9_201
  @player_id 9_102

  defp register_mob(mob_id \\ 1002) do
    {:ok, definition} = Mobs.by_id(mob_id)

    spawn = %MobSpawn{
      mob: mob_id,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    mob = MobState.new(@mob_id, definition, spawn, "prontera", 101, 100)
    :ok = UnitRegistry.register_unit(:mob, @mob_id, MobState, mob, self())
  end

  defp cast(target_id, level, roll),
    do:
      PfMindbreaker.cast(@caster, {:unit, target_id}, level, PfMindbreaker.definition(),
        rng: fn 100 -> roll end
      )

  defp expect_applied(type, id) do
    expect(StatusInterpreter, :apply_status, fn ^type, ^id, :sc_mindbreaker, params ->
      assert params[:val1] == 1
      assert params[:duration] == 30_000
      :ok
    end)
  end

  test "an undead-element target is refused" do
    register_mob(1015)

    assert PfMindbreaker.validate(@caster, {:unit, @mob_id}, 1, PfMindbreaker.definition()) ==
             {:error, :invalid_target}
  end

  test "a target already holding the status is a free no-op" do
    register_mob()
    :ok = StatusStorage.apply_status(:mob, @mob_id, :sc_mindbreaker, val1: 1)
    reject(&StatusInterpreter.apply_status/4)

    assert cast(@mob_id, 1, 1) == {:ok, @caster, :no_consume}
  end

  test "a landed roll on a mob applies it, cancels the cast and turns the mob on the caster" do
    register_mob()
    pid = self()
    expect_applied(:mob, @mob_id)
    expect(MobSession, :interrupt_cast, fn ^pid -> {:error, :not_casting} end)
    expect(MobSession, :set_target, fn ^pid, {:player, 9_101} -> :ok end)

    assert cast(@mob_id, 1, 60) == {:ok, @caster}
  end

  test "a landed roll on a player cancels their cast" do
    player = %PlayerState{character_id: @player_id, map_name: "prontera", x: 101, y: 100}
    :ok = UnitRegistry.register_unit(:player, @player_id, PlayerState, player, self())
    pid = self()
    expect_applied(:player, @player_id)
    expect(PlayerSession, :interrupt_cast, fn ^pid -> :ok end)

    assert cast(@player_id, 1, 60) == {:ok, @caster}
  end

  test "a missed roll applies nothing and still costs SP" do
    register_mob()
    reject(&StatusInterpreter.apply_status/4)
    reject(&MobSession.interrupt_cast/1)

    assert cast(@mob_id, 1, 61) == {:ok, @caster}
  end
end
