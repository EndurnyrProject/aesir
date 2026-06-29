defmodule Aesir.ZoneServer.Mmo.Skills.McCartrevolutionTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.McCartrevolution
  alias Aesir.ZoneServer.Unit.Cart.Weight

  setup :verify_on_exit!

  @target_id 5000
  @item_weight 100

  defp definition do
    {:ok, definition} = Catalog.by_name(:mc_cartrevolution)
    definition
  end

  defp cart(amount), do: %{0 => %InventoryItem{nameid: 501, amount: amount}}

  defp stub_item_weight do
    stub(ItemManagement, :get_item_by_id, fn _nameid -> {:ok, %{weight: @item_weight}} end)
  end

  describe "catalog registration" do
    test "Catalog.by_id(153) resolves to :mc_cartrevolution" do
      assert {:ok, definition} = Catalog.by_id(153)
      assert definition.name == :mc_cartrevolution
    end

    test "Catalog.by_name(:mc_cartrevolution) resolves" do
      assert {:ok, definition} = Catalog.by_name(:mc_cartrevolution)
      assert definition.id == 153
    end

    test "Catalog.active_module_for/1 resolves mc_cartrevolution" do
      assert {:ok, McCartrevolution} = Catalog.active_module_for(:mc_cartrevolution)
    end

    test "definition carries the rAthena splash/knockback/element/sp values" do
      definition = definition()
      assert definition.max_level == 1
      assert definition.target_type == :target_enemy
      assert definition.damage_type == :damage
      assert definition.splash_radius == 1
      assert definition.knockback == 2
      assert definition.element == :neutral
      assert definition.sp_cost == [12]
    end
  end

  describe "skill_ratio/1 (scales with cart weight)" do
    test "an empty cart yields the 150% floor" do
      assert McCartrevolution.skill_ratio(%{}) == 150
    end

    test "a full cart yields the 250% ceiling" do
      stub_item_weight()

      full_amount = div(Weight.max_weight(), @item_weight)

      assert McCartrevolution.skill_ratio(cart(full_amount)) == 250
    end

    test "a heavier cart yields a strictly higher ratio than a lighter one" do
      stub_item_weight()

      light = McCartrevolution.skill_ratio(cart(10))
      heavy = McCartrevolution.skill_ratio(cart(40))

      assert heavy > light
      assert light == 150 + div(100 * 10 * @item_weight, Weight.max_weight())
      assert heavy == 150 + div(100 * 40 * @item_weight, Weight.max_weight())
    end
  end

  describe "cast/4" do
    test "without a mounted cart returns {:error, :no_cart} and deals no damage" do
      reject(&Combat.execute_splash_attack/4)
      reject(&Combat.knockback/5)

      caster = %{cart_type: 0, cart: %{}}

      assert {:error, :no_cart} =
               McCartrevolution.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "with a mounted cart splashes the target cell with the weight-scaled ratio and knocks back" do
      stub_item_weight()
      caster = %{cart_type: 1, cart: cart(40)}
      expected_ratio = McCartrevolution.skill_ratio(caster.cart)

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {15, 25}}} end)

      expect(Combat, :execute_splash_attack, fn ^caster, {15, 25}, 1, opts ->
        assert opts[:skill_id] == definition().id
        assert opts[:skill_level] == 1
        assert opts[:skill_ratio] == expected_ratio
        assert opts[:skip_crit] == true
        [101, 102]
      end)

      expect(Combat, :knockback, 2, fn :mob, target_id, 15, 25, 2 ->
        assert target_id in [101, 102]
        {:ok, {0, 0}}
      end)

      assert {:ok, ^caster} = McCartrevolution.cast(caster, {:unit, @target_id}, 1, definition())
    end

    test "a heavier cart produces a higher splash ratio than a lighter cart" do
      stub_item_weight()
      light = %{cart_type: 1, cart: cart(10)}
      heavy = %{cart_type: 1, cart: cart(40)}

      stub(Combat, :resolve_combatant, fn @target_id -> {:ok, %{position: {0, 0}}} end)
      stub(Combat, :knockback, fn _, _, _, _, _ -> {:ok, {0, 0}} end)

      test_pid = self()

      stub(Combat, :execute_splash_attack, fn _caster, _center, _radius, opts ->
        send(test_pid, {:ratio, opts[:skill_ratio]})
        []
      end)

      McCartrevolution.cast(light, {:unit, @target_id}, 1, definition())
      assert_received {:ratio, light_ratio}

      McCartrevolution.cast(heavy, {:unit, @target_id}, 1, definition())
      assert_received {:ratio, heavy_ratio}

      assert heavy_ratio > light_ratio
    end

    test "propagates a target resolution error" do
      caster = %{cart_type: 1, cart: %{}}

      stub(Combat, :resolve_combatant, fn @target_id -> {:error, :target_not_found} end)

      assert {:error, :target_not_found} =
               McCartrevolution.cast(caster, {:unit, @target_id}, 1, definition())
    end
  end
end
