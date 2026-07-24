defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrSpearquickenTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Crusader.CrSpearquicken
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment

  setup :verify_on_exit!

  @caster_id 3000
  @one_handed_spear_id 1400
  @two_handed_spear_id 1410
  @dagger_id 1201

  defp caster(equipment \\ %Equipment{}),
    do: %PlayerState{character_id: @caster_id, stats: %{equipment: equipment}}

  defp mob_caster do
    mob_data = %MobDefinition{
      id: 1004,
      aegis_name: "test_crusader",
      name: "Test Crusader",
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
      mob: 1004,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    MobState.new(9003, mob_data, spawn_ref, "prontera", 100, 100)
  end

  describe "catalog registration" do
    test "by_id(258) resolves cr_spearquicken" do
      assert {:ok, definition} = Catalog.by_id(258)
      assert definition.name == :cr_spearquicken
      assert definition.display_name == "Spear Quicken"
      assert definition.max_level == 10
      assert definition.target_type == :self
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 258}} = Catalog.by_name(:cr_spearquicken)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, CrSpearquicken} = Catalog.active_module_for(:cr_spearquicken)
    end
  end

  describe "metadata" do
    test "sp_cost and duration match the per-level tables" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)

      assert definition.sp_cost == [24, 28, 32, 36, 40, 44, 48, 52, 56, 60]

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
    test "rejects a cast without a spear equipped" do
      assert {:error, :requires_spear} =
               CrSpearquicken.validate(
                 caster(%Equipment{right_hand: @dagger_id}),
                 :self,
                 1,
                 %{}
               )
    end

    test "rejects a bare-handed cast" do
      assert {:error, :requires_spear} = CrSpearquicken.validate(caster(), :self, 1, %{})
    end

    test "allows a cast with a one-handed spear equipped" do
      assert :ok =
               CrSpearquicken.validate(
                 caster(%Equipment{right_hand: @one_handed_spear_id}),
                 :self,
                 1,
                 %{}
               )
    end

    test "allows a cast with a two-handed spear equipped" do
      assert :ok =
               CrSpearquicken.validate(
                 caster(%Equipment{right_hand: @two_handed_spear_id}),
                 :self,
                 1,
                 %{}
               )
    end
  end

  describe "validate/4 (mob caster bypass)" do
    test "always allows a mob caster regardless of weapon" do
      assert :ok = CrSpearquicken.validate(mob_caster(), :self, 1, %{})
    end
  end

  describe "cast/4" do
    test "lv1 applies sc_spearquicken with val1=1, val2=7 and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      caster = caster(%Equipment{right_hand: @one_handed_spear_id})

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_spearquicken, params ->
        assert params[:val1] == 1
        assert params[:val2] == 7
        assert params[:caster_id] == @caster_id
        assert params[:duration] == 30_000
        :ok
      end)

      assert {:ok, ^caster} = CrSpearquicken.cast(caster, :self, 1, definition)
    end

    test "lv10 applies sc_spearquicken with val1=10, val2=7 and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      caster = caster(%Equipment{right_hand: @two_handed_spear_id})

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_spearquicken, params ->
        assert params[:val1] == 10
        assert params[:val2] == 7
        assert params[:duration] == 300_000
        :ok
      end)

      assert {:ok, ^caster} = CrSpearquicken.cast(caster, :self, 10, definition)
    end

    test "a mistargeted {:unit, id} row still buffs the caster, not the given id" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      caster = caster(%Equipment{right_hand: @one_handed_spear_id})

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_spearquicken, params ->
        assert params[:val1] == 4
        assert params[:caster_id] == @caster_id
        :ok
      end)

      assert {:ok, ^caster} = CrSpearquicken.cast(caster, {:unit, 999_999}, 4, definition)
    end

    test "a mob caster self-applies through :mob, not :player" do
      {:ok, definition} = Catalog.by_name(:cr_spearquicken)
      mob = mob_caster()

      expect(StatusInterpreter, :apply_status, fn :mob, 9003, :sc_spearquicken, params ->
        assert params[:val1] == 5
        assert params[:val2] == 7
        assert params[:caster_id] == 9003
        assert params[:duration] == 150_000
        :ok
      end)

      assert {:ok, ^mob} = CrSpearquicken.cast(mob, :self, 5, definition)
    end
  end
end
