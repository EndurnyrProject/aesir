defmodule Aesir.ZoneServer.Mmo.Skills.SaFrostweaponTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.SaFrostweapon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  setup :verify_on_exit!

  @caster_id 1000
  @catalyst_id 6361

  defp caster(equipment \\ %Equipment{}),
    do: %{character_id: @caster_id, stats: %{equipment: equipment}}

  defp game_state(learned, equipment, inventory) do
    %{
      character_id: @caster_id,
      x: 10,
      y: 10,
      map_name: "prontera",
      zeny: 0,
      skill_cooldowns: %{},
      act_delay_until: 0,
      inventory: inventory,
      pending_inventory_persist: [],
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{learned_skills: learned},
        equipment: equipment
      }
    }
  end

  describe "catalog registration" do
    test "by_id/1 resolves id 281" do
      assert {:ok, %{name: :sa_frostweapon}} = Catalog.by_id(281)
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 281}} = Catalog.by_name(:sa_frostweapon)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, SaFrostweapon} = Catalog.active_module_for(:sa_frostweapon)
    end
  end

  describe "metadata" do
    test "matches the rAthena renewal table (skill_db.yml:7811-7844)" do
      {:ok, definition} = Catalog.by_name(:sa_frostweapon)

      assert definition.max_level == 5
      assert definition.target_type == :target_ally
      assert definition.damage_type == :no_damage
      assert definition.element == :water
      assert definition.range == 9
      assert definition.cast_time == List.duplicate(1000, 5)
      assert definition.fixed_cast_time == List.duplicate(1000, 5)
      assert definition.sp_cost == List.duplicate(40, 5)
      assert definition.item_cost == [%{id: @catalyst_id, amount: 1}]
      assert definition.duration == [600_000, 900_000, 1_200_000, 1_500_000, 1_800_000]
    end
  end

  describe "cast/4" do
    test "applies sc_waterweapon with val1=level and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:sa_frostweapon)
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_waterweapon, params ->
        assert params[:val1] == 2
        assert params[:caster_id] == @caster_id
        assert params[:duration] == 900_000
        :ok
      end)

      assert {:ok, ^caster} = SaFrostweapon.cast(caster, :self, 2, definition)
    end
  end

  describe "validate/4 (bare-hand rejection)" do
    test "rejects a bare-handed self-cast" do
      assert {:error, :bare_handed} = SaFrostweapon.validate(caster(), :self, 1, %{})
    end

    test "allows a self-cast target with a weapon equipped" do
      assert :ok = SaFrostweapon.validate(caster(%Equipment{right_hand: 1201}), :self, 1, %{})
    end
  end

  describe "the validate-then-charge contract" do
    test "a bare-handed target fails before SP or the catalyst is spent" do
      reject(&StatusInterpreter.apply_status/4)

      gs =
        game_state(%{281 => 1}, %Equipment{}, %{
          0 => %InventoryItem{nameid: @catalyst_id, amount: 1, equip: 0}
        })

      assert {:error, :bare_handed} = SkillInterpreter.cast(gs, 281, 1, :self)
    end
  end

  describe "endow exclusivity" do
    test "casting displaces sc_aspersio" do
      stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)
      StatusStorage.apply_status(:player, @caster_id, :sc_aspersio, duration: 30_000, val1: 3)

      {:ok, definition} = Catalog.by_name(:sa_frostweapon)
      assert {:ok, _} = SaFrostweapon.cast(caster(), :self, 1, definition)

      refute StatusStorage.has_status?(:player, @caster_id, :sc_aspersio)
      assert StatusStorage.has_status?(:player, @caster_id, :sc_waterweapon)
    end
  end
end
