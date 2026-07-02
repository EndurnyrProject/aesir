defmodule Aesir.ZoneServer.Unit.Player.Handlers.CartHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.UnitStateChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 7001
  @pushcart_level 5
  @cart1_bit Option.id(:cart1)

  setup do
    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 50, base_level: 50, str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}
       }}
    end)

    :ok
  end

  defp character(opts) do
    %Character{
      id: @char_id,
      account_id: 2000,
      name: "Merchy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 0,
      hp: 800,
      sp: 300,
      cart: Keyword.get(opts, :cart, 0),
      learned_skills: Keyword.get(opts, :learned_skills, %{})
    }
  end

  defp state(opts) do
    base = PlayerState.new(character(opts))

    game_state = %{
      base
      | cart: Keyword.get(opts, :cart_map, %{}),
        cart_type: Keyword.get(opts, :cart_type, 0),
        inventory: Keyword.get(opts, :inventory, %{})
    }

    %{connection_pid: self(), game_state: game_state, interaction_lock: nil}
  end

  defp item(nameid, amount) do
    %InventoryItem{
      id: 11,
      char_id: @char_id,
      nameid: nameid,
      amount: amount,
      equip: 0,
      identify: 1,
      refine: 0,
      attribute: 0,
      card0: 0,
      card1: 0,
      card2: 0,
      card3: 0,
      random_options: %{},
      bound: 0,
      favorite: 0
    }
  end

  defp stub_item_definition do
    stub(ItemManagement, :get_item_by_id, fn nameid ->
      {:ok,
       %ItemDefinition{
         id: nameid,
         aegis_name: "Apple",
         name: "Apple",
         type: :healing,
         weight: 10,
         view: 0
       }}
    end)
  end

  describe "mount/1" do
    test "with MC_PUSHCART learned sets cart_type, persists, sends CartInfo, broadcasts the sprite" do
      test_pid = self()
      learned = %{Integer.to_string(catalog_pushcart_id()) => @pushcart_level}

      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      stub(SpatialIndex, :get_unit_position, fn :player, @char_id ->
        {:ok, {150, 150, "prontera"}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:cart_sprite, packet})
        :ok
      end)

      expect(CharacterPersistence, :update_character, fn @char_id, %{cart: 1}, async: true ->
        :ok
      end)

      assert {:noreply, new_state} = CartHandler.mount(state(learned_skills: learned))

      assert new_state.game_state.cart_type == 1
      assert StatusStorage.has_status?(:player, @char_id, :sc_push_cart)

      assert_received {:send, :bulk, {:cart_info, %CartInfo{items: []}}}

      assert_received {:cart_sprite,
                       %UnitStateChange{unit_id: @char_id, effect_state: effect_state}}

      assert (effect_state &&& @cart1_bit) == @cart1_bit
    end

    test "without MC_PUSHCART learned is rejected with no state change" do
      reject(&CharacterPersistence.update_character/3)

      base = state(learned_skills: %{})

      assert {:noreply, ^base} = CartHandler.mount(base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_push_cart)
      refute_received {:send, :bulk, {:cart_info, _}}
    end
  end

  describe "unmount/1" do
    test "is rejected while the cart is not empty" do
      reject(&CharacterPersistence.update_character/3)

      base = state(cart_type: 1, cart_map: %{0 => item(501, 2)})

      assert {:noreply, ^base} = CartHandler.unmount(base)
    end
  end

  describe "move_to_cart/3" do
    test "moves an inventory item and emits the paired ItemRemoved + CartItemAdded" do
      stub_item_definition()
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      moved = item(501, 4)
      new_cart = %{0 => moved}

      stub(CartOps, :move_to_cart, fn @char_id, _inv, _cart, 0, 4 ->
        {:ok, %{}, new_cart, {:removed, 0}, {:added, 0, moved}}
      end)

      base = state(cart_type: 1, cart_map: %{}, learned_skills: %{})
      client_index = PlayerState.client_index(0)

      assert {:noreply, committed} =
               CartHandler.move_to_cart(client_index, 4, base)

      assert committed.game_state.cart == new_cart

      assert_received {:send, :gameplay,
                       {:item_removed, %ItemRemoved{index: ^client_index, amount: 4}}}

      assert_received {:send, :gameplay,
                       {:cart_item_added,
                        %CartItemAdded{index: ^client_index, nameid: 501, amount: 4}}}
    end

    test "a weight/availability error changes nothing and emits no deltas" do
      reject(&UnitRegistry.update_unit_state/3)

      stub(CartOps, :move_to_cart, fn @char_id, _inv, _cart, 0, 4 -> {:error, :overweight} end)

      base = state(cart_type: 1)
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = CartHandler.move_to_cart(client_index, 4, base)
      refute_received {:send, :gameplay, {:item_removed, _}}
      refute_received {:send, :gameplay, {:cart_item_added, _}}
    end

    test "is rejected while the cart is not mounted, writing nothing" do
      reject(&CartOps.move_to_cart/5)
      reject(&UnitRegistry.update_unit_state/3)

      base = state(cart_type: 0, inventory: %{0 => item(501, 4)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = CartHandler.move_to_cart(client_index, 4, base)
      refute_received {:send, :gameplay, {:item_removed, _}}
      refute_received {:send, :gameplay, {:cart_item_added, _}}
    end

    test "is rejected for an equipped source item, writing nothing" do
      reject(&CartOps.move_to_cart/5)

      equipped = %{item(1201, 1) | equip: 2}
      base = state(cart_type: 1, inventory: %{0 => equipped})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = CartHandler.move_to_cart(client_index, 1, base)
    end

    test "is rejected for a favorited source item, writing nothing" do
      reject(&CartOps.move_to_cart/5)

      favorited = %{item(501, 4) | favorite: 1}
      base = state(cart_type: 1, inventory: %{0 => favorited})
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = CartHandler.move_to_cart(client_index, 4, base)
    end
  end

  describe "move_to_inventory/3" do
    test "moves a cart item and emits the paired CartItemRemoved + ItemAdded" do
      stub_item_definition()
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      moved = item(501, 3)
      new_inventory = %{0 => moved}

      stub(CartOps, :move_to_inventory, fn @char_id, _inv, _cart, %Stats{}, 0, 3 ->
        {:ok, new_inventory, %{}, {:added, 0, moved}, {:removed, 0}}
      end)

      base = state(cart_type: 1, cart_map: %{0 => item(501, 3)})
      client_index = PlayerState.client_index(0)

      assert {:noreply, committed} =
               CartHandler.move_to_inventory(client_index, 3, base)

      assert committed.game_state.inventory == new_inventory

      assert_received {:send, :gameplay,
                       {:cart_item_removed, %CartItemRemoved{index: ^client_index, amount: 3}}}

      assert_received {:send, :gameplay,
                       {:item_added, %ItemAdded{index: ^client_index, nameid: 501, amount: 3}}}
    end

    test "is rejected while the cart is not mounted, writing nothing" do
      reject(&CartOps.move_to_inventory/6)
      reject(&UnitRegistry.update_unit_state/3)

      base = state(cart_type: 0)
      client_index = PlayerState.client_index(0)

      assert {:noreply, ^base} = CartHandler.move_to_inventory(client_index, 3, base)
      refute_received {:send, :gameplay, {:cart_item_removed, _}}
      refute_received {:send, :gameplay, {:item_added, _}}
    end
  end

  describe "load_on_spawn/2" do
    test "restores cart contents, sets the tier, and re-applies SC_PUSHCART" do
      stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

      row = %CartItem{
        id: 42,
        char_id: @char_id,
        nameid: 501,
        amount: 7,
        equip: 0,
        identify: 1,
        refine: 0,
        attribute: 0,
        card0: 0,
        card1: 0,
        card2: 0,
        card3: 0,
        random_options: %{},
        favorite: 0,
        bound: 0,
        unique_id: 0,
        equip_switch: 0,
        enchant_grade: 0
      }

      stub(Cart, :load_cart, fn @char_id -> [row] end)

      learned = %{Integer.to_string(catalog_pushcart_id()) => @pushcart_level}
      character = character(cart: 1, learned_skills: learned)

      base = %{
        connection_pid: self(),
        game_state: %{PlayerState.new(character) | cart: %{}, cart_type: 0},
        interaction_lock: nil
      }

      restored = CartHandler.load_on_spawn(character, base)

      assert restored.game_state.cart_type == 1
      assert %{0 => %InventoryItem{nameid: 501, amount: 7}} = restored.game_state.cart
      assert StatusStorage.has_status?(:player, @char_id, :sc_push_cart)
      assert restored.game_state.walk_speed > 150
    end

    test "is a no-op when the character has no cart" do
      base = state(learned_skills: %{})
      character = character(cart: 0)

      assert ^base = CartHandler.load_on_spawn(character, base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_push_cart)
    end
  end

  describe "change_cart_tier/2" do
    @cart2_bit Option.id(:cart2)
    @cart3_bit Option.id(:cart3)

    setup do
      test_pid = self()

      stub(SpatialIndex, :get_unit_position, fn :player, @char_id ->
        {:ok, {150, 150, "prontera"}}
      end)

      stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, packet, _opts ->
        send(test_pid, {:cart_sprite, packet})
        :ok
      end)

      StatusStorage.apply_status(:player, @char_id, :sc_push_cart, val1: @pushcart_level, val2: 1)
      :ok
    end

    test "at the tier-2 base level sets cart_type 2, persists, RMWs val2, broadcasts cart2" do
      expect(CharacterPersistence, :update_character, fn @char_id, %{cart: 2}, async: true ->
        :ok
      end)

      game_state = state(cart_type: 1).game_state

      assert {:ok, updated} = CartHandler.change_cart_tier(game_state, 50)

      assert updated.cart_type == 2
      assert StatusStorage.get_status(:player, @char_id, :sc_push_cart).val2 == 2

      assert_received {:cart_sprite,
                       %UnitStateChange{unit_id: @char_id, effect_state: effect_state}}

      assert (effect_state &&& @cart2_bit) == @cart2_bit
    end

    test "jumps straight to tier 3 above the tier-3 base level" do
      expect(CharacterPersistence, :update_character, fn @char_id, %{cart: 3}, async: true ->
        :ok
      end)

      game_state = state(cart_type: 1).game_state

      assert {:ok, updated} = CartHandler.change_cart_tier(game_state, 70)

      assert updated.cart_type == 3
      assert StatusStorage.get_status(:player, @char_id, :sc_push_cart).val2 == 3

      assert_received {:cart_sprite,
                       %UnitStateChange{unit_id: @char_id, effect_state: effect_state}}

      assert (effect_state &&& @cart3_bit) == @cart3_bit
    end

    test "below the tier-2 base level returns an error and changes nothing" do
      reject(&CharacterPersistence.update_character/3)

      game_state = state(cart_type: 1).game_state

      assert {:error, :no_cart_upgrade} = CartHandler.change_cart_tier(game_state, 30)

      assert StatusStorage.get_status(:player, @char_id, :sc_push_cart).val2 == 1
      refute_received {:cart_sprite, _}
    end
  end

  describe "packet dispatch" do
    test "CartMountRequest{mount: true} dispatches to CartHandler.mount/1" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(CartHandler, :mount, fn st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%Aesir.Net.CartMountRequest{mount: true}, base)
    end

    test "MoveToCartRequest dispatches move_to_cart with the client index/amount" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(CartHandler, :move_to_cart, fn 5, 2, st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %Aesir.Net.MoveToCartRequest{inventory_index: 5, amount: 2},
                 base
               )
    end

    test "MoveFromCartRequest dispatches move_to_inventory with the client index/amount" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(CartHandler, :move_to_inventory, fn 3, 4, st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(
                 %Aesir.Net.MoveFromCartRequest{cart_index: 3, amount: 4},
                 base
               )
    end
  end

  defp catalog_pushcart_id do
    {:ok, definition} = Catalog.by_name(:mc_pushcart)
    definition.id
  end
end
