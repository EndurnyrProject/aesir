defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStealcoinTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.MobManagement
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStealcoin
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 1_000
  @target_id 2_000

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Catalog.reload()

    stub(Stats, :get_effective_stat, fn
      _stats, :dex -> 40
      _stats, :luk -> 20
    end)

    :ok
  end

  test "mugs zeny from a monster only once" do
    caster = caster()
    mob_pid = self()

    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> true end)
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, mob_pid}} end)

    expect(MobSession, :attempt_mug, fn ^mob_pid, %{dex: 40, luk: 20, base_level: 50}, 6 ->
      {:ok, 500}
    end)

    assert :ok = RgStealcoin.validate(caster, {:unit, @target_id}, 6, RgStealcoin.definition())

    stub(Combat, :execute_zero_damage_hit, fn player, @target_id, _flag -> player end)

    assert {:ok, mugged} =
             RgStealcoin.cast(caster, {:unit, @target_id}, 6, RgStealcoin.definition())

    assert mugged.zeny == 1_500

    reject(&Combat.execute_zero_damage_hit/3)

    expect(MobSession, :attempt_mug, fn ^mob_pid, %{dex: 40, luk: 20, base_level: 50}, 6 ->
      {:error, :already_mugged}
    end)

    assert {:failed, ^mugged, :skill_failed} =
             RgStealcoin.cast(mugged, {:unit, @target_id}, 6, RgStealcoin.definition())

    expect(MobSession, :attempt_mug, fn ^mob_pid, _caster, 6 -> {:error, :no_coin} end)

    assert {:failed, ^mugged, :no_coin} =
             RgStealcoin.cast(mugged, {:unit, @target_id}, 6, RgStealcoin.definition())
  end

  test "a successful mug deals the monster a zero-damage long weapon hit after crediting zeny" do
    mob_pid = self()
    flag = BattleFlags.build(:weapon, :long, false)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, mob_pid}} end)
    stub(MobSession, :attempt_mug, fn ^mob_pid, _caster, 3 -> {:ok, 500} end)

    expect(Combat, :execute_zero_damage_hit, fn %PlayerState{zeny: 1_500} = player,
                                                @target_id,
                                                ^flag ->
      %{player | zeny: 1_501}
    end)

    assert {:ok, %PlayerState{zeny: 1_501}} =
             RgStealcoin.cast(caster(), {:unit, @target_id}, 3, RgStealcoin.definition())
  end

  # skill.cpp:4664-4667: a non-monster target fails castend_id_check with USESKILL_FAIL.
  test "rejects player targets with the plain skill failure without attempting to mug" do
    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:error, :not_found} end)
    reject(&MobSession.attempt_mug/3)

    assert {:error, :skill_failed} =
             RgStealcoin.validate(caster(), {:unit, @target_id}, 1, RgStealcoin.definition())
  end

  # skill.cpp:4664-4667: a status-immune monster fails castend_id_check with USESKILL_FAIL.
  test "refuses a status-immune monster at the cast end without attempting to mug" do
    {:ok, data} = MobManagement.get_mob_by_id(1002)
    spawn = %MobSpawn{mob: 1002, amount: 1, respawn_time: 5_000, spawn_area: nil}
    mob = MobState.new(@target_id, data, spawn, "prontera", 1, 1)

    immune = %{
      mob
      | calculated: %{
          mob.calculated
          | mode: Bitwise.bor(mob.calculated.mode, MobMode.mask([:status_immune]))
        }
    }

    reject(&MobSession.attempt_mug/3)

    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, mob, self()}} end)
    assert :ok = RgStealcoin.validate(caster(), {:unit, @target_id}, 1, RgStealcoin.definition())

    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, immune, self()}} end)

    assert {:error, :skill_failed} =
             RgStealcoin.validate(caster(), {:unit, @target_id}, 1, RgStealcoin.definition())
  end

  test "does not credit zeny when the mob is immune" do
    caster = caster()
    mob_pid = self()

    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, mob_pid}} end)

    expect(MobSession, :attempt_mug, fn ^mob_pid, %{dex: 40, luk: 20, base_level: 50}, 1 ->
      {:error, :immune}
    end)

    reject(&Combat.execute_zero_damage_hit/3)

    assert {:failed, ^caster, :skill_failed} =
             RgStealcoin.cast(caster, {:unit, @target_id}, 1, RgStealcoin.definition())

    assert caster.zeny == 1_000
  end

  defp caster do
    %PlayerState{
      character_id: @caster_id,
      zeny: 1_000,
      stats: %Stats{progression: %PlayerProgression{base_level: 50}}
    }
  end
end
