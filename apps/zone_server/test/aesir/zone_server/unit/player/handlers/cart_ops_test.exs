defmodule Aesir.ZoneServer.Unit.Player.Handlers.CartOpsTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Cart.Persistence, as: CartPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  # Real item ids from priv/db/items (loaded into :persistent_term at boot).
  @potion 501
  @sword 1101
  @poring_card 4001

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Mimic.copy(CartPersistence)
    :ok
  end

  setup do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "testuser",
        userid: "testuser",
        user_pass: "password",
        email: "test@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "TestChar",
        class: 1,
        base_level: 99,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    %{account: account, character: character, stats: Stats.from_character(character)}
  end

  describe "apply_change/4 — cart table" do
    test "added inserts the cart row and reflects its db id into the map", %{character: char} do
      def_ = def!(@sword)
      {:ok, new_cart, {:added, 0, _} = change} = Cart.add(%{}, def_, 1)

      assert {:ok, persisted} = CartOps.apply_change(char.id, %{}, new_cart, change)

      assert %{0 => %InventoryItem{id: id, nameid: @sword}} = persisted
      assert is_integer(id)
      assert [%CartItem{nameid: @sword}] = CartPersistence.load_cart(char.id)
    end
  end

  describe "move_to_cart/5" do
    test "reduces the inventory row and inserts the cart row, both committed", %{character: char} do
      seed_inv(char.id, @potion, 10)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, p_inv, p_cart, {:reduced, ^index, 6}, {:added, 0, _}} =
               CartOps.move_to_cart(char.id, inventory, %{}, index, 4)

      assert %{^index => %InventoryItem{amount: 6}} = p_inv
      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = p_cart

      assert [%InventoryItem{amount: 6}] = InventoryPersistence.load_inventory(char.id)
      assert [%CartItem{nameid: @potion, amount: 4}] = CartPersistence.load_cart(char.id)
    end

    test "removes the inventory row entirely when the whole stack moves", %{character: char} do
      seed_inv(char.id, @potion, 4)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, p_inv, _p_cart, {:removed, ^index}, {:added, 0, _}} =
               CartOps.move_to_cart(char.id, inventory, %{}, index, 4)

      assert p_inv == %{}
      assert [] = InventoryPersistence.load_inventory(char.id)
      assert [%CartItem{amount: 4}] = CartPersistence.load_cart(char.id)
    end

    test "stacks onto an existing plain cart stack", %{character: char} do
      seed_inv(char.id, @potion, 10, %{identify: 1})
      seed_cart(char.id, @potion, 5, %{identify: 1})
      inventory = inv_map(char.id)
      cart = cart_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, _p_inv, _p_cart, {:reduced, ^index, 7}, {:stacked, _, 8}} =
               CartOps.move_to_cart(char.id, inventory, cart, index, 3)

      assert [%CartItem{amount: 8}] = CartPersistence.load_cart(char.id)
    end

    test "preserves refine/cards and does not merge a carded item with a plain stack", %{
      character: char
    } do
      seed_cart(char.id, @potion, 5)
      seed_inv(char.id, @potion, 1, %{refine: 7, card0: @poring_card})
      inventory = inv_map(char.id)
      cart = cart_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, _p_inv, _p_cart, _inv_change, {:added, _, _}} =
               CartOps.move_to_cart(char.id, inventory, cart, index, 1)

      rows = CartPersistence.load_cart(char.id)
      assert length(rows) == 2

      plain = Enum.find(rows, &(&1.card0 == 0))
      carded = Enum.find(rows, &(&1.card0 == @poring_card))

      assert plain.amount == 5
      assert carded.amount == 1
      assert carded.refine == 7
      assert carded.card0 == @poring_card
    end

    test "rejects an over-cap cart with :overweight and writes nothing", %{character: char} do
      # 1143 potions weigh 80_010 > the flat 80_000 cart cap (1142 = 79_940 would fit).
      seed_inv(char.id, @potion, 1200)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:error, :overweight} = CartOps.move_to_cart(char.id, inventory, %{}, index, 1143)

      assert [%InventoryItem{amount: 1200}] = InventoryPersistence.load_inventory(char.id)
      assert [] = CartPersistence.load_cart(char.id)
    end
  end

  describe "move_to_inventory/6" do
    test "reduces the cart row and adds the inventory row, both committed", %{
      character: char,
      stats: stats
    } do
      seed_cart(char.id, @potion, 10)
      cart = cart_map(char.id)
      index = index_of(cart, @potion)

      assert {:ok, p_inv, _p_cart, {:added, 0, _}, {:reduced, ^index, 6}} =
               CartOps.move_to_inventory(char.id, %{}, cart, stats, index, 4)

      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = p_inv
      assert [%InventoryItem{amount: 4}] = InventoryPersistence.load_inventory(char.id)
      assert [%CartItem{amount: 6}] = CartPersistence.load_cart(char.id)
    end

    test "deletes the cart row when the whole stack moves back", %{character: char, stats: stats} do
      seed_cart(char.id, @potion, 4)
      cart = cart_map(char.id)
      index = index_of(cart, @potion)

      assert {:ok, _p_inv, p_cart, {:added, 0, _}, {:removed, ^index}} =
               CartOps.move_to_inventory(char.id, %{}, cart, stats, index, 4)

      assert p_cart == %{}
      assert [%InventoryItem{amount: 4}] = InventoryPersistence.load_inventory(char.id)
      assert [] = CartPersistence.load_cart(char.id)
    end

    test "rejects when the player would be overweight and writes nothing", %{
      character: char,
      stats: stats
    } do
      max = Weight.max_weight(stats)
      fill = div(max, 70)

      seed_inv(char.id, @potion, fill)
      seed_cart(char.id, @potion, 1)
      inventory = inv_map(char.id)
      cart = cart_map(char.id)
      index = index_of(cart, @potion)

      assert {:error, :overweight} =
               CartOps.move_to_inventory(char.id, inventory, cart, stats, index, 1)

      assert [%InventoryItem{amount: ^fill}] = InventoryPersistence.load_inventory(char.id)
      assert [%CartItem{amount: 1}] = CartPersistence.load_cart(char.id)
    end
  end

  describe "atomicity across both tables" do
    test "a forced failure on the cart write rolls back the inventory write", %{character: char} do
      seed_inv(char.id, @potion, 10)
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      stub(CartPersistence, :insert_item, fn _char_id, _attrs -> {:error, :forced_failure} end)

      assert {:error, :forced_failure} =
               CartOps.move_to_cart(char.id, inventory, %{}, index, 4)

      # The inventory reduce (10 -> 6) must have rolled back with the cart insert.
      assert [%InventoryItem{amount: 10}] = InventoryPersistence.load_inventory(char.id)
      assert [] = CartPersistence.load_cart(char.id)
    end

    test "a forced failure on the cart update rolls back the inventory add", %{
      character: char,
      stats: stats
    } do
      seed_cart(char.id, @potion, 10, %{identify: 1})
      cart = cart_map(char.id)
      index = index_of(cart, @potion)

      stub(CartPersistence, :update_item, fn _row, _attrs -> {:error, :forced_failure} end)

      assert {:error, :forced_failure} =
               CartOps.move_to_inventory(char.id, %{}, cart, stats, index, 4)

      # The inventory add must have rolled back with the cart reduce.
      assert [] = InventoryPersistence.load_inventory(char.id)
      assert [%CartItem{amount: 10}] = CartPersistence.load_cart(char.id)
    end
  end

  describe "sequential moves on the returned maps (persist-first invariant)" do
    test "stacking a second move into the returned cart map commits", %{character: char} do
      seed_inv(char.id, @potion, 10, %{identify: 1})
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, p_inv1, p_cart1, {:reduced, ^index, 7}, {:added, 0, _}} =
               CartOps.move_to_cart(char.id, inventory, %{}, index, 3)

      # The just-inserted in-memory cart item must carry char_id, or the second
      # move's stack-update changeset would fail validate_required([:char_id]).
      assert %{0 => %InventoryItem{char_id: cid}} = p_cart1
      assert cid == char.id

      assert {:ok, p_inv2, p_cart2, {:reduced, ^index, 5}, {:stacked, 0, 5}} =
               CartOps.move_to_cart(char.id, p_inv1, p_cart1, index, 2)

      assert %{0 => %InventoryItem{amount: 5}} = p_cart2
      assert %{^index => %InventoryItem{amount: 5}} = p_inv2
      assert [%CartItem{amount: 5}] = CartPersistence.load_cart(char.id)
      assert [%InventoryItem{amount: 5}] = InventoryPersistence.load_inventory(char.id)
    end

    test "reducing a just-inserted cart slot via the returned map commits", %{
      character: char,
      stats: stats
    } do
      seed_inv(char.id, @potion, 10, %{identify: 1})
      inventory = inv_map(char.id)
      index = index_of(inventory, @potion)

      assert {:ok, p_inv1, p_cart1, {:reduced, ^index, 4}, {:added, 0, _}} =
               CartOps.move_to_cart(char.id, inventory, %{}, index, 6)

      assert {:ok, p_inv2, p_cart2, {:stacked, ^index, 6}, {:reduced, 0, 4}} =
               CartOps.move_to_inventory(char.id, p_inv1, p_cart1, stats, 0, 2)

      assert %{0 => %InventoryItem{amount: 4}} = p_cart2
      assert %{^index => %InventoryItem{amount: 6}} = p_inv2
      assert [%CartItem{amount: 4}] = CartPersistence.load_cart(char.id)
      assert [%InventoryItem{amount: 6}] = InventoryPersistence.load_inventory(char.id)
    end
  end

  defp seed_inv(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      InventoryPersistence.insert_item(
        char_id,
        Map.merge(%{nameid: nameid, amount: amount}, attrs)
      )

    item
  end

  defp seed_cart(char_id, nameid, amount, attrs \\ %{}) do
    {:ok, item} =
      CartPersistence.insert_item(char_id, Map.merge(%{nameid: nameid, amount: amount}, attrs))

    item
  end

  defp inv_map(char_id) do
    items = InventoryPersistence.load_inventory(char_id)
    PlayerState.from_list(items)
  end

  defp cart_map(char_id) do
    rows = CartPersistence.load_cart(char_id)

    rows
    |> Enum.map(&cart_row_to_item/1)
    |> PlayerState.from_list()
  end

  defp cart_row_to_item(%CartItem{} = c) do
    %InventoryItem{
      id: c.id,
      char_id: c.char_id,
      nameid: c.nameid,
      amount: c.amount,
      equip: c.equip,
      identify: c.identify,
      refine: c.refine,
      attribute: c.attribute,
      card0: c.card0,
      card1: c.card1,
      card2: c.card2,
      card3: c.card3,
      random_options: c.random_options,
      bound: c.bound,
      favorite: c.favorite,
      unique_id: c.unique_id,
      expire_time: c.expire_time,
      equip_switch: c.equip_switch,
      enchant_grade: c.enchant_grade
    }
  end

  defp def!(id) do
    {:ok, d} = ItemManagement.get_item_by_id(id)
    d
  end

  defp index_of(map, nameid) do
    Enum.find_value(map, fn {index, item} ->
      if item.nameid == nameid, do: index
    end)
  end
end
