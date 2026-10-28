defmodule Aesir.ZoneServer.Mmo.Skills.Stalker.StFullstripTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobSkill.Importer
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Mmo.Skills.Stalker.StFullstrip
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(TargetResolver)
    Mimic.copy(PlayerSession)
    Mimic.copy(PlayerState)
    Mimic.copy(MobState)
    Mimic.copy(StripCommon)
    :ok
  end

  @caster_id 1_000
  @target_id 2_000
  @slots [:right_hand, :left_hand, :armor, :head_top]
  @protections [:sc_cp_weapon, :sc_cp_shield, :sc_cp_armor, :sc_cp_helm]

  test "a player caster facing all four Chemical Protections is told the target is coated" do
    caster = player(@caster_id)
    target = player(@target_id)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)

    stub(StatusStorage, :has_status?, fn :player, @target_id, status -> status in @protections end)

    reject(&StripCommon.roll_success?/1)
    reject(&PlayerSession.strip_equip/3)

    assert {:failed, ^caster, :fullstrip_coated} =
             StFullstrip.cast(caster, {:unit, {:player, @target_id}}, 3, definition())
  end

  test "three Chemical Protections still send every slot, which the target masks itself" do
    caster = player(@caster_id)
    target = player(@target_id)
    stub_dex(caster, 70, target, 20)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(StatusStorage, :has_status?, fn :player, @target_id, status -> status != :sc_cp_helm end)
    stub(StripCommon, :roll_success?, fn _rate -> true end)

    expect(PlayerSession, :strip_equip, fn _pid, @slots, opts ->
      assert opts[:skill_id] == 476
      assert opts[:kind] == :full
      assert opts[:duration] == 130_003
      assert opts[:report_to] == @caster_id
      :ok
    end)

    assert {:ok, ^caster} =
             StFullstrip.cast(caster, {:unit, {:player, @target_id}}, 3, definition())
  end

  test "a monster caster is never told a target is coated and strips as usual" do
    caster = mob(@caster_id)
    target = player(@target_id)
    stub_dex(caster, 20, target, 20)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)

    stub(StatusStorage, :has_status?, fn :player, @target_id, status -> status in @protections end)

    stub(StripCommon, :roll_success?, fn _rate -> true end)

    expect(PlayerSession, :strip_equip, fn _pid, @slots, opts ->
      assert opts[:report_to] == nil
      :ok
    end)

    assert {:ok, ^caster} =
             StFullstrip.cast(caster, {:unit, {:player, @target_id}}, 1, definition())
  end

  test "monster skill rows can cast it" do
    assert Importer.classify(476) == :castable
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(476)
    definition
  end

  defp stub_dex(caster, caster_dex, target, target_dex) do
    stub(PlayerState, :get_stats, fn
      ^caster -> %{dex: caster_dex}
      ^target -> %{dex: target_dex}
    end)

    stub(MobState, :get_stats, fn ^caster -> %{dex: caster_dex} end)
  end

  defp player(id), do: %PlayerState{character_id: id, map_name: "prontera", x: 10, y: 10}

  defp mob(id) do
    %MobState{
      instance_id: id,
      mob_id: 1_002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: nil,
      map_name: "prontera",
      x: 10,
      y: 10,
      hp: 100,
      sp: 100,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 100)
  end
end
