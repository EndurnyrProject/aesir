defmodule Aesir.ZoneServer.Mmo.Skills.Ensemble.BdEternalchaosTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.Skills.Ensemble.BdEternalchaos
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EternalChaos
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 7_001
  @mob_id 7_002

  Mimic.copy(Perform)

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    player = player_defender()
    mob = mob_defender()

    :ok = UnitRegistry.register_player(player, self())
    :ok = UnitRegistry.register_unit(:mob, mob.instance_id, MobState, mob, self())
    Catalog.reload()

    %{player: player, mob: mob}
  end

  test "definition carries the pinned Eternal Chaos data" do
    assert {:ok, BdEternalchaos} = Catalog.active_module_for(:bd_eternalchaos)

    assert %{
             id: 308,
             max_level: 1,
             target_type: :self,
             damage_type: :no_damage,
             damage_kind: :misc,
             splash_radius: 4,
             range: 0,
             unit_duration: [],
             sp_cost: [120],
             duration: [60_000],
             cast_time: [1_000],
             fixed_cast_time: [500],
             after_cast_delay: [300],
             cooldown: [60_000],
             require_weapon: [:musical, :whip]
           } = BdEternalchaos.definition()

    assert :ensemble in BdEternalchaos.__skill_capabilities__()
    refute :performance in BdEternalchaos.__skill_capabilities__()
  end

  test "status lasts 60 seconds and declares the canonical mutual exclusion list" do
    assert %{duration: 60_000, calc_flags: [:def, :def2], properties: [:debuff]} =
             EternalChaos.metadata()

    assert EternalChaos.metadata().end_on_start == [
             :sc_richmankim,
             :sc_eternalchaos,
             :sc_drumbattle,
             :sc_nibelungen,
             :sc_rokisweil,
             :sc_intoabyss,
             :sc_siegfried
           ]
  end

  test "casts through the ensemble performer as an enemy snapshot" do
    caster = %PlayerState{character_id: 1}
    definition = BdEternalchaos.definition()

    expect(Perform, :perform, fn ^caster,
                                 ^definition,
                                 1,
                                 :sc_eternalchaos,
                                 params_fun,
                                 [scope: :enemy] ->
      assert params_fun.(1) == []
      {:ok, caster}
    end)

    assert {:ok, ^caster} = BdEternalchaos.cast(caster, :self, 1, definition)
  end

  test "Eternal Chaos resolves both player and mob defense as zero in the damage pipeline", %{
    player: player,
    mob: mob
  } do
    attacker = CombatTestHelper.create_player_combatant(unit_id: 8_001, str: 100)

    for {unit_type, unit_id, defender} <- [
          {:player, player.character_id, PlayerState.to_combatant(player)},
          {:mob, mob.instance_id, MobState.to_combatant(mob)}
        ] do
      assert :ok =
               StatusInterpreter.apply_status(unit_type, unit_id, :sc_eternalchaos,
                 bypass_resistance: true
               )

      :rand.seed(:exsss, {1, 2, 3})

      assert {:ok, %{damage: affected_damage}} =
               DamageCalculator.calculate_damage(attacker, defender, skip_crit: true)

      :rand.seed(:exsss, {1, 2, 3})

      assert {:ok, %{damage: zero_defense_damage}} =
               DamageCalculator.calculate_damage(attacker, zero_defenses(defender),
                 skip_crit: true
               )

      assert affected_damage == zero_defense_damage
    end
  end

  defp player_defender do
    %Character{
      id: @player_id,
      account_id: @player_id,
      name: "EternalChaosPlayer",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 50,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 1,
      class: 0
    }
    |> PlayerState.new()
    |> then(fn state ->
      put_in(state.stats.combat_stats.def, 100)
    end)
  end

  defp mob_defender do
    mob_data = %MobDefinition{
      id: @mob_id,
      aegis_name: "ETERNAL_CHAOS_TEST_MOB",
      name: "Eternal Chaos Test Mob",
      level: 50,
      hp: 10_000,
      sp: 0,
      stats: %{str: 40, agi: 30, vit: 50, int: 20, dex: 35, luk: 15},
      atk: 50,
      matk: 60,
      def: 100,
      mdef: 10,
      attack_range: 1,
      walk_speed: 200,
      attack_delay: 1_200,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300,
      element: {:neutral, 1},
      race: :formless,
      size: :medium
    }

    spawn_ref = %MobSpawn{
      mob: @mob_id,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(@mob_id, mob_data, spawn_ref, "prontera", 100, 100)
  end

  defp zero_defenses(defender) do
    %{
      defender
      | combat_stats: %{defender.combat_stats | def: 0},
        base_stats: Map.put(defender.base_stats, :vit, 0)
    }
  end
end
