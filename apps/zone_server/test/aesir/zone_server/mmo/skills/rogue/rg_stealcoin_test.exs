defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgStealcoinTest do
  use ExUnit.Case, async: false

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.RgStealcoin
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 1_000
  @target_id 2_000

  setup :verify_on_exit!

  setup do
    Catalog.reload()

    stub(Stats, :get_effective_stat, fn
      _stats, :dex -> 40
      _stats, :luk -> 20
    end)

    :ok
  end

  test "is discovered with Mug's static definition" do
    assert {:ok, RgStealcoin} = Catalog.active_module_for(:rg_stealcoin)
    assert {:ok, definition} = Catalog.by_id(211)

    assert definition.name == :rg_stealcoin
    assert definition.display_name == "Mug"
    assert definition.max_level == 10
    assert definition.target_type == :target_enemy
    assert definition.damage_type == :no_damage
    assert definition.range == 1
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

    assert {:ok, mugged} =
             RgStealcoin.cast(caster, {:unit, @target_id}, 6, RgStealcoin.definition())

    assert mugged.zeny == 1_500

    expect(MobSession, :attempt_mug, fn ^mob_pid, %{dex: 40, luk: 20, base_level: 50}, 6 ->
      {:error, :no_coin}
    end)

    assert {:error, :no_coin} =
             RgStealcoin.cast(mugged, {:unit, @target_id}, 6, RgStealcoin.definition())
  end

  test "rejects player targets without attempting to mug" do
    stub(UnitRegistry, :unit_exists?, fn :mob, @target_id -> false end)
    reject(&MobSession.attempt_mug/3)

    assert {:error, :invalid_target} =
             RgStealcoin.validate(caster(), {:unit, @target_id}, 1, RgStealcoin.definition())
  end

  test "does not credit zeny when the mob is immune" do
    caster = caster()
    mob_pid = self()

    stub(UnitRegistry, :get_unit, fn :mob, @target_id -> {:ok, {MobSession, %{}, mob_pid}} end)

    expect(MobSession, :attempt_mug, fn ^mob_pid, %{dex: 40, luk: 20, base_level: 50}, 1 ->
      {:error, :immune}
    end)

    assert {:error, :immune} =
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
