defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnTwohandquickenTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Knight.KnTwohandquicken
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :verify_on_exit!

  @caster_id 3000
  @two_handed_sword_id 1116
  @dagger_id 1201

  defp caster(equipment \\ %Equipment{}),
    do: %PlayerState{character_id: @caster_id, stats: %{equipment: equipment}}

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1003,
      aegis_name: "test_knight",
      name: "Test Knight",
      level: 50,
      hp: 1000,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      matk: 0,
      attack_range: 1,
      size: :medium,
      race: :formless,
      element: {:neutral, 1},
      walk_speed: 200,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 400,
      damage_motion: 300
    }

    spawn_ref = %MobSpawn{
      mob: 1003,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9002, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "catalog registration" do
    test "by_id(60) resolves kn_twohandquicken" do
      assert {:ok, definition} = Catalog.by_id(60)
      assert definition.name == :kn_twohandquicken
      assert definition.display_name == "Two-Hand Quicken"
      assert definition.max_level == 10
      assert definition.target_type == :self
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 60}} = Catalog.by_name(:kn_twohandquicken)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, KnTwohandquicken} = Catalog.active_module_for(:kn_twohandquicken)
    end
  end

  describe "metadata" do
    test "sp_cost and duration match the per-level tables" do
      {:ok, definition} = Catalog.by_name(:kn_twohandquicken)

      assert definition.sp_cost == [14, 18, 22, 26, 30, 34, 38, 42, 46, 50]

      assert definition.duration ==
               [
                 30_000,
                 60_000,
                 90_000,
                 120_000,
                 150_000,
                 180_000,
                 210_000,
                 240_000,
                 270_000,
                 300_000
               ]
    end
  end

  describe "validate/4 (player weapon gate)" do
    test "rejects a cast without a two-handed sword equipped" do
      assert {:error, :wrong_weapon} =
               KnTwohandquicken.validate(
                 caster(%Equipment{right_hand: @dagger_id}),
                 :self,
                 1,
                 %{}
               )
    end

    test "rejects a bare-handed cast" do
      assert {:error, :wrong_weapon} = KnTwohandquicken.validate(caster(), :self, 1, %{})
    end

    test "allows a cast with a two-handed sword equipped" do
      assert :ok =
               KnTwohandquicken.validate(
                 caster(%Equipment{right_hand: @two_handed_sword_id}),
                 :self,
                 1,
                 %{}
               )
    end
  end

  describe "validate/4 (mob caster bypass)" do
    test "always allows a mob caster regardless of weapon" do
      assert :ok = KnTwohandquicken.validate(mob_caster(), :self, 1, %{})
    end
  end

  describe "cast/4" do
    test "lv1 applies sc_twohandquicken with val1=1, val2=7 and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:kn_twohandquicken)
      caster = caster(%Equipment{right_hand: @two_handed_sword_id})

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_twohandquicken,
                                                  params ->
        assert params[:val1] == 1
        assert params[:val2] == 7
        assert params[:caster_id] == @caster_id
        assert params[:duration] == 30_000
        :ok
      end)

      assert {:ok, ^caster} = KnTwohandquicken.cast(caster, :self, 1, definition)
    end

    test "lv10 applies sc_twohandquicken with val1=10, val2=7 and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:kn_twohandquicken)
      caster = caster(%Equipment{right_hand: @two_handed_sword_id})

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_twohandquicken,
                                                  params ->
        assert params[:val1] == 10
        assert params[:val2] == 7
        assert params[:duration] == 300_000
        :ok
      end)

      assert {:ok, ^caster} = KnTwohandquicken.cast(caster, :self, 10, definition)
    end

    test "a mistargeted {:unit, id} row still buffs the caster, not the given id" do
      {:ok, definition} = Catalog.by_name(:kn_twohandquicken)
      caster = caster(%Equipment{right_hand: @two_handed_sword_id})

      expect(StatusInterpreter, :apply_status, fn :player,
                                                  @caster_id,
                                                  :sc_twohandquicken,
                                                  params ->
        assert params[:val1] == 4
        assert params[:caster_id] == @caster_id
        :ok
      end)

      assert {:ok, ^caster} = KnTwohandquicken.cast(caster, {:unit, 999_999}, 4, definition)
    end

    test "a mob caster self-applies through :mob, not :player" do
      {:ok, definition} = Catalog.by_name(:kn_twohandquicken)
      mob = mob_caster()

      expect(StatusInterpreter, :apply_status, fn :mob, 9002, :sc_twohandquicken, params ->
        assert params[:val1] == 5
        assert params[:val2] == 7
        assert params[:caster_id] == 9002
        assert params[:duration] == 150_000
        :ok
      end)

      assert {:ok, ^mob} = KnTwohandquicken.cast(mob, :self, 5, definition)
    end
  end
end
