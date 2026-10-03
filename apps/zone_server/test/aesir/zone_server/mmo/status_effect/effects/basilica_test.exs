defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BasilicaTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Basilica
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.BasilicaCaster
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @holder_id 36_401
  @mob_id 36_402
  @boss_id 36_403
  @group_id 9_101

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    holder = player(@holder_id)
    :ok = UnitRegistry.register_player(holder, self())
    :ok = SpatialIndex.add_player(@holder_id, 100, 100, "prontera")
    register_mob(@mob_id, [])
    register_mob(@boss_id, [:boss])
    :ok
  end

  test "the occupant and caster statuses are unsaved, undispellable and end on map change" do
    for module <- [Basilica, BasilicaCaster] do
      metadata = module.metadata()

      assert metadata.no_save
      assert metadata.no_dispel
      assert metadata.remove_on_map_change
      assert metadata.icon == :basilica
    end

    assert Basilica.metadata().bypass_boss_immunity
    assert Basilica.metadata().target_types == [:player, :mob]
    assert BasilicaCaster.metadata().target_types == [:player]
  end

  describe "absorb_damage/4" do
    test "blocks every hit from a non-boss source" do
      for {attacker, type} <- [{{:mob, @mob_id}, :physical}, {{:player, 1}, :magic}] do
        assert {:ok, 0, _} = absorb(Basilica, %{damage: 500, dmg_type: type, attacker: attacker})
      end

      assert {:ok, 0, _} =
               absorb(BasilicaCaster, %{damage: 500, dmg_type: :misc, attacker: {:mob, @mob_id}})
    end

    test "lets a boss source through" do
      hit = %{damage: 500, dmg_type: :physical, attacker: {:mob, @boss_id}}

      assert {:ok, 500, _} = absorb(Basilica, hit)
      assert {:ok, 500, _} = absorb(BasilicaCaster, hit)
    end

    test "blocks a hit with no known source" do
      assert {:ok, 0, _} = absorb(Basilica, %{damage: 500, dmg_type: :misc})
      assert {:ok, 0, _} = absorb(Basilica, %{damage: 500, dmg_type: :misc, attacker: nil})
    end
  end

  describe "through the damage pipeline" do
    test "a holder takes nothing from a normal mob and full damage from a boss" do
      :ok = apply_occupant(:player, @holder_id)
      hit = %{dmg_type: :physical, is_short: true}

      assert {0, _} =
               DamageApplication.prepare_unit_damage(
                 :player,
                 @holder_id,
                 500,
                 hit,
                 {:mob, @mob_id}
               )

      assert {500, _} =
               DamageApplication.prepare_unit_damage(
                 :player,
                 @holder_id,
                 500,
                 hit,
                 {:mob, @boss_id}
               )
    end
  end

  describe "status-driven damage" do
    test "poison ticks and self-inflicted status costs still reach a holder" do
      :ok = apply_occupant(:player, @holder_id)

      :ok = Combat.deal_damage({:player, @holder_id}, 40)

      assert_receive {:"$gen_cast", {:unit, {:apply_damage, 40, nil}}}
    end
  end

  describe "absorb order" do
    test "a blocked hit never reaches the holder's Kyrie barrier" do
      :ok =
        Interpreter.apply_status(:player, @holder_id, :sc_kyrie,
          val1: 10,
          val2: 1_000,
          val3: 10,
          duration: 120_000,
          caster_id: @holder_id
        )

      :ok = apply_occupant(:player, @holder_id)
      hit = %{dmg_type: :physical, is_short: true}

      for _hit <- 1..3 do
        assert {0, _} =
                 DamageApplication.prepare_unit_damage(
                   :player,
                   @holder_id,
                   300,
                   hit,
                   {:mob, @mob_id}
                 )
      end

      assert %{state: %{shield_hp: 1_000, hits_remaining: 10}} =
               StatusStorage.get_status(:player, @holder_id, :sc_kyrie)
    end
  end

  describe "gating" do
    test "an occupant can neither attack nor cast, but may still move" do
      :ok = apply_occupant(:player, @holder_id)

      refute Interpreter.can_attack?(:player, @holder_id)
      refute Interpreter.can_use_skill?(:player, @holder_id, 28)
      refute Interpreter.can_use_skill?(:player, @holder_id, 362)
      assert Interpreter.can_move?(:player, @holder_id)
    end

    test "the caster is rooted and may only recast Basilica" do
      :ok = apply_caster(@holder_id)

      refute Interpreter.can_attack?(:player, @holder_id)
      refute Interpreter.can_move?(:player, @holder_id)
      refute Interpreter.can_use_skill?(:player, @holder_id, 28)
      assert Interpreter.can_use_skill?(:player, @holder_id, 362)
    end

    test "a boss mob can carry the occupant status" do
      assert :ok = apply_occupant(:mob, @boss_id)
      refute Interpreter.can_attack?(:mob, @boss_id)
    end
  end

  describe "occupant tick" do
    test "keeps the status while its holder stands on a Basilica cell" do
      :ok = Storage.insert(basilica_group([{100, 100}]))
      entry = %StatusEntry{type: :sc_basilica, val1: 1}

      assert {:ok, ^entry} = Basilica.on_tick({:player, @holder_id}, entry, %{})
    end

    test "drops the status once its holder is off every Basilica cell" do
      :ok = Storage.insert(basilica_group([{110, 110}]))

      assert :remove =
               Basilica.on_tick(
                 {:player, @holder_id},
                 %StatusEntry{type: :sc_basilica, val1: 1},
                 %{}
               )
    end
  end

  test "ending the caster status destroys its sanctuary group" do
    Mimic.copy(Unit)
    expect(Unit, :destroy_async, fn @group_id -> :ok end)

    assert :ok =
             BasilicaCaster.on_expire(
               {:player, @holder_id},
               %StatusEntry{type: :sc_basilica_caster, val1: 1, val2: @group_id},
               %{}
             )
  end

  defp absorb(module, hit_info) do
    entry = %StatusEntry{type: module.metadata().id, val1: 1}
    module.absorb_damage({:player, @holder_id}, entry, hit_info, %{})
  end

  defp apply_occupant(unit_type, unit_id) do
    Interpreter.apply_status(unit_type, unit_id, :sc_basilica,
      val1: 1,
      duration: 20_000,
      caster_id: 1,
      source_type: :player
    )
  end

  defp apply_caster(unit_id) do
    Interpreter.apply_status(:player, unit_id, :sc_basilica_caster,
      val1: 1,
      val2: @group_id,
      duration: 20_000,
      caster_id: unit_id
    )
  end

  defp basilica_group(cells) do
    %Group{
      group_id: @group_id,
      skill_id: 362,
      skill_name: :hp_basilica,
      level: 1,
      caster_id: 1,
      caster_type: :player,
      map_name: "prontera",
      center: hd(cells),
      cells: cells,
      next_tick_at: 0,
      expires_at: 0,
      interval: 300,
      state: %{basilica: true}
    }
  end

  defp register_mob(id, modes) do
    mob_data = %MobDefinition{
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 50,
      sp: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      atk: 7,
      matk: 0,
      def: 0,
      mdef: 0,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 400,
      attack_delay: 1_872,
      attack_motion: 672,
      client_attack_motion: 672,
      damage_motion: 480,
      element: {:water, 1},
      race: :plant,
      size: :medium,
      modes: modes
    }

    spawn_ref = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(id, mob_data, spawn_ref, "prontera", 101, 100)
    UnitRegistry.register_unit(:mob, id, MobState, state, self())
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Basilica #{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "F",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4009
    })
  end
end
