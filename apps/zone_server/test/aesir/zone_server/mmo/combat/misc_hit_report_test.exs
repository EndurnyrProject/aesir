defmodule Aesir.ZoneServer.Mmo.Combat.MiscHitReportTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    Mimic.copy(DamageApplication)

    caster =
      PlayerState.new(%Character{
        id: 17,
        account_id: 17,
        name: "Misc caster",
        class: 0,
        base_level: 50,
        job_level: 1,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        str: 10,
        agi: 10,
        vit: 0,
        int: 10,
        dex: 10,
        luk: 0
      })

    :ok = UnitRegistry.register_player(caster, self())
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 101, y: 100, xs: 0, ys: 0}
    }

    mob = MobState.new(42, definition, spawn, "prontera", 101, 100)
    %{caster: caster, mob: mob}
  end

  test "misc hits report delivered damage and exact lethal boundaries without waiting for the target",
       %{caster: caster, mob: mob} do
    for {hp, survives} <- [{999, false}, {1000, false}, {1001, true}] do
      target = %{mob | hp: hp, max_hp: 2000}
      :ok = UnitRegistry.register_unit(:mob, 42, MobState, target, self())
      stub(TargetResolver, :resolve, fn {:mob, 42} -> {:ok, self(), target, :mob} end)

      assert {:ok, %{hit?: true, damage: 1000, target_survives?: ^survives}} =
               SkillAttack.execute_misc_attack(caster, {:mob, 42},
                 skill_id: 489,
                 skill_level: 5,
                 base_damage: 1000,
                 ignore_element: true,
                 report_hit: true
               )
    end
  end

  test "survival uses settled rather than raw damage", %{caster: caster, mob: mob} do
    target = %{mob | hp: 750, max_hp: 2000}
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, target, self())
    stub(TargetResolver, :resolve, fn {:mob, 42} -> {:ok, self(), target, :mob} end)

    stub(DamageApplication, :prepare_unit_damage, fn :mob, 42, 1000, hit, _source ->
      {500, Map.put(hit, :pre_delivery_prepared?, true)}
    end)

    assert {:ok, %{damage: 500, target_survives?: true}} =
             SkillAttack.execute_misc_attack(caster, {:mob, 42},
               skill_id: 489,
               skill_level: 5,
               base_damage: 1000,
               ignore_element: true,
               report_hit: true
             )
  end
end
