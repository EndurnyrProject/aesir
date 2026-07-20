defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaFlamelauncherTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Sage.SaFlamelauncher
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
  @catalyst_id 6360
  @sword_id 1201

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

  defp catalyst(amount), do: %InventoryItem{nameid: @catalyst_id, amount: amount, equip: 0}

  defp stub_sword do
    stub(ItemManagement, :get_item_by_id, fn @sword_id ->
      {:ok, %ItemDefinition{id: @sword_id, aegis_name: "sword", name: "Sword", subtype: :sword}}
    end)
  end

  # `StatusEffect.Interpreter` resolves the carrier through the real registry
  # before applying a status; these tests never spin up a player process, so
  # the lookup is stubbed to answer for whichever caster id is under test.
  defp stub_entity_info do
    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id -> {:ok, %{stats: %{}}} end)
  end

  describe "catalog registration" do
    test "by_id/1 resolves id 280" do
      assert {:ok, %{name: :sa_flamelauncher}} = Catalog.by_id(280)
    end

    test "by_name/1 resolves the atom" do
      assert {:ok, %{id: 280}} = Catalog.by_name(:sa_flamelauncher)
    end

    test "active_module_for/1 resolves the module" do
      assert {:ok, SaFlamelauncher} = Catalog.active_module_for(:sa_flamelauncher)
    end
  end

  describe "metadata" do
    test "matches the rAthena renewal table (skill_db.yml:7777-7810)" do
      {:ok, definition} = Catalog.by_name(:sa_flamelauncher)

      assert definition.max_level == 5
      assert definition.target_type == :target_ally
      assert definition.damage_type == :no_damage
      assert definition.element == :fire
      assert definition.range == 9
      assert definition.cast_time == List.duplicate(1000, 5)
      assert definition.fixed_cast_time == List.duplicate(1000, 5)
      assert definition.sp_cost == List.duplicate(40, 5)
      assert definition.item_cost == [%{id: @catalyst_id, amount: 1}]

      # 300*(lv+1)s in ms - not the "600*lv" the doc trusted (that would give
      # lv2 == 1_200_000, but skill_db.yml:7796-7797 says 900_000).
      assert definition.duration == [600_000, 900_000, 1_200_000, 1_500_000, 1_800_000]
    end
  end

  describe "cast/4" do
    test "applies sc_fireweapon with val1=level and the tabulated duration" do
      {:ok, definition} = Catalog.by_name(:sa_flamelauncher)
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_fireweapon, params ->
        assert params[:val1] == 3
        assert params[:caster_id] == @caster_id
        assert params[:duration] == 1_200_000
        :ok
      end)

      assert {:ok, ^caster} = SaFlamelauncher.cast(caster, :self, 3, definition)
    end

    test "targets an ally by unit id" do
      {:ok, definition} = Catalog.by_name(:sa_flamelauncher)
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :player, 2000, :sc_fireweapon, _params ->
        :ok
      end)

      assert {:ok, ^caster} = SaFlamelauncher.cast(caster, {:unit, 2000}, 1, definition)
    end

    test "propagates the interpreter's error" do
      {:ok, definition} = Catalog.by_name(:sa_flamelauncher)
      caster = caster()

      expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_fireweapon, _params ->
        {:error, :some_reason}
      end)

      assert {:error, :some_reason} = SaFlamelauncher.cast(caster, :self, 1, definition)
    end
  end

  describe "validate/4 (bare-hand rejection)" do
    test "allows a self-cast target with a weapon equipped" do
      stub_sword()

      assert :ok =
               SaFlamelauncher.validate(caster(%Equipment{right_hand: @sword_id}), :self, 1, %{})
    end

    test "rejects a bare-handed self-cast" do
      assert {:error, :bare_handed} = SaFlamelauncher.validate(caster(), :self, 1, %{})
    end

    test "rejects a bare-handed self-cast targeted by unit id" do
      assert {:error, :bare_handed} =
               SaFlamelauncher.validate(caster(), {:unit, @caster_id}, 1, %{})
    end

    test "rejects a bare-handed ally target resolved through the unit registry" do
      stub_sword()
      target = caster(%Equipment{})

      stub(UnitRegistry, :get_unit, fn :player, 2000 -> {:ok, {nil, target, self()}} end)

      assert {:error, :bare_handed} =
               SaFlamelauncher.validate(
                 caster(%Equipment{right_hand: @sword_id}),
                 {:unit, 2000},
                 1,
                 %{}
               )
    end

    test "allows an armed ally target resolved through the unit registry" do
      target = caster(%Equipment{right_hand: @sword_id})
      stub_sword()
      stub(UnitRegistry, :get_unit, fn :player, 2000 -> {:ok, {nil, target, self()}} end)

      assert :ok = SaFlamelauncher.validate(caster(), {:unit, 2000}, 1, %{})
    end

    test "skips the check for a target that does not resolve to a player (no dstsd)" do
      stub(UnitRegistry, :get_unit, fn :player, 3000 -> {:error, :not_found} end)

      assert :ok = SaFlamelauncher.validate(caster(), {:unit, 3000}, 1, %{})
    end
  end

  describe "the validate-then-charge contract" do
    test "a bare-handed target fails before SP or the catalyst is spent" do
      reject(&StatusInterpreter.apply_status/4)

      gs = game_state(%{280 => 1}, %Equipment{}, %{0 => catalyst(1)})

      assert {:error, :bare_handed} = SkillInterpreter.cast(gs, 280, 1, :self)
    end

    test "an armed target succeeds, charging SP and consuming the catalyst" do
      stub_sword()
      stub_entity_info()

      equipment = %Equipment{right_hand: @sword_id}
      gs = game_state(%{280 => 1}, equipment, %{0 => catalyst(1)})

      assert {:ok, updated} = SkillInterpreter.cast(gs, 280, 1, :self)
      assert updated.stats.current_state.sp == 60
      assert updated.inventory == %{}

      assert StatusStorage.has_status?(:player, @caster_id, :sc_fireweapon)
      assert %{val1: 1} = StatusStorage.get_status(:player, @caster_id, :sc_fireweapon)
    end
  end

  describe "endow exclusivity" do
    for other <- [:sc_waterweapon, :sc_windweapon, :sc_earthweapon, :sc_aspersio] do
      test "casting displaces #{other}" do
        stub_entity_info()
        StatusStorage.apply_status(:player, @caster_id, unquote(other), duration: 30_000, val1: 3)

        {:ok, definition} = Catalog.by_name(:sa_flamelauncher)
        assert {:ok, _} = SaFlamelauncher.cast(caster(), :self, 1, definition)

        refute StatusStorage.has_status?(:player, @caster_id, unquote(other))
        assert StatusStorage.has_status?(:player, @caster_id, :sc_fireweapon)
      end
    end
  end
end
