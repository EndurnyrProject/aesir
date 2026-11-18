defmodule Aesir.ZoneServer.Mmo.Combat.MiscHitReportTest do
  use ExUnit.Case, async: true
  import Aesir.TestEtsSetup
  import Mimic
  import Aesir.ZoneServer.Factory

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    caster =
      PlayerState.new(
        Aesir.Factory.build(:character,
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
        )
      )

    :ok = UnitRegistry.register_player(caster, self())
    {:ok, definition} = Mobs.by_id(1002)

    mob = build(:mob_state, instance_id: 42, mob_data: definition, x: 101)

    mob = %{mob | calculated: %{mob.calculated | max_hp: 2000}}
    %{caster: caster, mob: mob}
  end

  test "misc hits report delivered damage and exact lethal boundaries without waiting for the target",
       %{caster: caster, mob: mob} do
    for {hp, survives} <- [{999, false}, {1000, false}, {1001, true}] do
      target = %{mob | hp: hp}
      :ok = UnitRegistry.register_unit(:mob, 42, MobState, target, self())
      stub(TargetResolver, :resolve, fn {:mob, 42} -> {:ok, self(), target, :mob} end)

      assert {:ok, %{hit?: true, damage: 1000, target_survives?: ^survives}} =
               SkillAttack.execute_misc_attack(caster, {:mob, 42},
                 skill_id: 489,
                 skill_level: 5,
                 base_damage: 1000,
                 report_hit: true
               )
    end
  end

  test "signed misc divisions normalize before target preparation", %{caster: caster, mob: mob} do
    target = %{mob | hp: 1000}
    :ok = UnitRegistry.register_unit(:mob, 42, MobState, target, self())
    stub(TargetResolver, :resolve, fn {:mob, 42} -> {:ok, self(), target, :mob} end)

    for {divisions, expected} <- [{3, 303}, {-3, 99}, {-5, 100}] do
      expect(DamageApplication, :prepare_unit_damage, fn :mob, 42, ^expected, hit, _source ->
        {expected, Map.put(hit, :pre_delivery_prepared?, true)}
      end)

      assert {:ok, %{damage: ^expected}} =
               SkillAttack.execute_misc_attack(caster, {:mob, 42},
                 skill_id: 489,
                 skill_level: 5,
                 base_damage: 101,
                 hit_divisions: divisions,
                 report_hit: true
               )
    end
  end

  test "survival uses settled rather than raw damage", %{caster: caster, mob: mob} do
    target = %{mob | hp: 750}
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
               report_hit: true
             )
  end
end
