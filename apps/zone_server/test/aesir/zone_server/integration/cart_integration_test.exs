defmodule Aesir.ZoneServer.Integration.CartIntegrationTest do
  @moduledoc """
  End-to-end coverage that the Merchant cart subsystem is playable on the real
  stack, mirroring the Archer integration coverage. Every step drives the live
  session/handler/status/combat/persistence subsystems (no re-stubbing of units
  already unit-tested):

    1. Learn Pushcart through the live learning flow, then mount: `cart_type`
       becomes 1, `character.cart` persists, `SC_PUSHCART` is active, the cart1
       sprite bit shows in the broadcast and the spawn aggregate, and the
       walk-speed penalty is applied.
    2. Move items inventory<->cart through the client-intent packets: both
       container maps, both DB tables, and the paired client deltas reflect the
       move in each direction.
    3. Change Cart at the tier-2 base level bumps `cart_type` to 2, persists it,
       updates the live `SC_PUSHCART` tier, and re-broadcasts the cart2 sprite;
       below the threshold (or unmounted) it changes nothing.
    4. Cart Revolution's skill ratio scales with cart weight (heavier -> higher),
       a mounted cast splashes and knocks targets back, and an unmounted cast is
       rejected with `{:error, :no_cart}`.
    5. Relog with `character.cart > 0` restores the cart contents, tier, and the
       `SC_PUSHCART` status from the database.
    6. Unmount is blocked while the cart holds items and succeeds once empty.
  """

  use Aesir.ZoneServer.IntegrationCase

  import Bitwise, only: [band: 2]

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CartInfo
  alias Aesir.Net.CartItemAdded
  alias Aesir.Net.CartItemRemoved
  alias Aesir.Net.CartMountRequest
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemRemoved
  alias Aesir.Net.Knockback
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.MoveFromCartRequest
  alias Aesir.Net.MoveToCartRequest
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillList
  alias Aesir.Net.UnitStateChange
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McCartrevolution
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McChangecart
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Cart.Persistence, as: CartPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # rAthena class id for the 1st-class Merchant; PlayerState derives job_id from it.
  @merchant_class 5
  # Red Potion (item db, weight 70) — a plain stackable used for the moves.
  @potion 501
  @status_id :sc_push_cart
  @base_walk_speed 150
  # rAthena status_calc_speed: the cart slows movement by (50 - 5*MC_PUSHCART)%.
  @pushcart_speed_penalty 50

  describe "mount" do
    test "learning Pushcart then mounting sets the tier, sprite, status and speed" do
      %{pid: pid, character: char} = start_merchant(pushcart_level: 1)

      char_id = char.id
      cart_bit = Option.id(:cart1)

      simulate_incoming_message(pid, %CartMountRequest{mount: true})

      assert_receive {:packet_sent, %CartInfo{}, _}, 1_000

      assert_receive {:packet_sent, %UnitStateChange{unit_id: ^char_id, effect_state: effect}, _}
                     when band(effect, cart_bit) != 0,
                     1_000

      state = get_player_state(pid)

      assert state.cart_type == 1

      assert %StatusEntry{val1: 1, val2: 1} =
               StatusStorage.get_status(:player, char.id, @status_id)

      assert band(StatusDisplay.spawn_state(:player, char.id).effect_state, cart_bit) != 0

      # Pushcart lv1 -> +45% speed rate -> walk_speed 217 (slower than the base 150).
      expected_speed = div(@base_walk_speed * (100 + @pushcart_speed_penalty - 5), 100)
      assert state.walk_speed == expected_speed
      assert state.walk_speed > @base_walk_speed

      assert Repo.get(Character, char.id).cart == 1
    end
  end

  describe "moving items between inventory and cart" do
    test "MoveToCart then MoveFromCart update both containers, both tables and the client" do
      %{pid: pid, character: char} =
        start_merchant(pushcart_level: 1, inventory: [{@potion, 10}])

      mount!(pid)

      inv_index = client_index_of(get_player_state(pid).inventory, @potion)

      simulate_incoming_message(pid, %MoveToCartRequest{inventory_index: inv_index, amount: 4})

      assert_receive {:packet_sent, %ItemRemoved{amount: 4}, _}, 1_000
      assert_receive {:packet_sent, %CartItemAdded{nameid: @potion, amount: 4}, _}, 1_000

      moved_in = get_player_state(pid)
      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = moved_in.cart
      assert held(moved_in.inventory, @potion) == 6

      assert [%InventoryItem{amount: 6}] = InventoryPersistence.load_inventory(char.id)
      assert [%CartItem{nameid: @potion, amount: 4}] = CartPersistence.load_cart(char.id)

      cart_index = client_index_of(moved_in.cart, @potion)

      simulate_incoming_message(pid, %MoveFromCartRequest{cart_index: cart_index, amount: 4})

      assert_receive {:packet_sent, %CartItemRemoved{amount: 4}, _}, 1_000
      # The 4 stack back onto the 6 left behind, so the ItemAdded reports the
      # resulting slot total (10), not the delta.
      assert_receive {:packet_sent, %ItemAdded{nameid: @potion, amount: 10}, _}, 1_000

      moved_out = get_player_state(pid)
      assert moved_out.cart == %{}
      assert held(moved_out.inventory, @potion) == 10

      assert [%InventoryItem{amount: 10}] = InventoryPersistence.load_inventory(char.id)
      assert [] = CartPersistence.load_cart(char.id)
    end
  end

  describe "Change Cart" do
    test "casting at a tier-2 base level bumps the tier, persists and re-broadcasts the sprite" do
      %{pid: pid, character: char} = start_merchant(pushcart_level: 1, base_level: 50)

      mount!(pid)
      flush_packets()

      char_id = char.id
      cart2_bit = Option.id(:cart2)
      mounted = get_player_state(pid)

      assert {:ok, %{cart_type: 2}} =
               McChangecart.cast(mounted, :self, 1, skill_def(:mc_changecart))

      assert_receive {:packet_sent, %UnitStateChange{unit_id: ^char_id, effect_state: effect}, _}
                     when band(effect, cart2_bit) != 0,
                     1_000

      assert %StatusEntry{val2: 2} = StatusStorage.get_status(:player, char.id, @status_id)
      assert band(StatusDisplay.spawn_state(:player, char.id).effect_state, cart2_bit) != 0
      assert Repo.get(Character, char.id).cart == 2
    end

    test "casting below the tier-2 base level (or unmounted) changes nothing" do
      %{pid: pid, character: char} = start_merchant(pushcart_level: 1, base_level: 30)

      mount!(pid)
      mounted = get_player_state(pid)

      assert {:error, :no_cart_upgrade} =
               McChangecart.cast(mounted, :self, 1, skill_def(:mc_changecart))

      assert %StatusEntry{val2: 1} = StatusStorage.get_status(:player, char.id, @status_id)
      assert Repo.get(Character, char.id).cart == 1

      assert {:error, :no_cart} =
               McChangecart.cast(%{mounted | cart_type: 0}, :self, 1, skill_def(:mc_changecart))
    end
  end

  describe "Cart Revolution" do
    test "skill ratio scales with cart weight and is 150% for an empty cart" do
      assert McCartrevolution.skill_ratio(%{}) == 150

      light = %{0 => %InventoryItem{nameid: @potion, amount: 200}}
      heavy = %{0 => %InventoryItem{nameid: @potion, amount: 800}}

      light_ratio = McCartrevolution.skill_ratio(light)
      heavy_ratio = McCartrevolution.skill_ratio(heavy)

      assert light_ratio > 150
      assert heavy_ratio > light_ratio
    end

    test "a mounted cast splashes the target's cell and knocks the edge target back" do
      %{pid: pid} = start_merchant(pushcart_level: 1)
      mount!(pid)
      flush_packets()

      center =
        start_mob_session(unit_id: 95_510, map_name: "prontera", position: {150, 151}, hp: 5000)

      edge =
        start_mob_session(unit_id: 95_511, map_name: "prontera", position: {150, 152}, hp: 5000)

      center_id = center.unit_id
      edge_id = edge.unit_id

      caster = get_player_state(pid)

      assert {:ok, ^caster} =
               McCartrevolution.cast(caster, {:unit, center_id}, 1, skill_def(:mc_cartrevolution))

      assert_receive {:packet_sent, %SkillDamage{skill_id: 153, target_id: ^center_id}, _}, 1_000
      assert_receive {:packet_sent, %SkillDamage{skill_id: 153, target_id: ^edge_id}, _}, 1_000
      assert_receive {:packet_sent, %Knockback{unit_id: ^edge_id}, _}, 1_000
    end

    test "an unmounted cast is rejected with no_cart and deals no damage" do
      %{pid: pid} = start_merchant(pushcart_level: 1)
      caster = get_player_state(pid)

      mob =
        start_mob_session(unit_id: 95_520, map_name: "prontera", position: {150, 151}, hp: 5000)

      assert {:error, :no_cart} =
               McCartrevolution.cast(
                 caster,
                 {:unit, mob.unit_id},
                 1,
                 skill_def(:mc_cartrevolution)
               )

      refute_receive {:packet_sent, %SkillDamage{skill_id: 153}, _}, 200
    end
  end

  describe "relog" do
    test "re-spawning with character.cart > 0 restores cart contents, tier and status" do
      session = start_merchant(pushcart_level: 1, inventory: [{@potion, 10}])
      %{pid: pid, character: char} = session

      mount!(pid)

      inv_index = client_index_of(get_player_state(pid).inventory, @potion)
      simulate_incoming_message(pid, %MoveToCartRequest{inventory_index: inv_index, amount: 4})
      assert_receive {:packet_sent, %CartItemAdded{}, _}, 1_000

      assert [%CartItem{nameid: @potion, amount: 4}] = CartPersistence.load_cart(char.id)
      assert Repo.get(Character, char.id).cart == 1

      # Disconnect: stop the session and wipe the in-memory status so the relog
      # assertions prove a genuine restore from the database, not leftover state.
      end_player_session(session)
      StatusStorage.remove_status(:player, char.id, @status_id)
      refute StatusStorage.has_status?(:player, char.id, @status_id)

      reloaded = Repo.get(Character, char.id)
      assert reloaded.cart == 1

      relog =
        start_player_session(character: reloaded, map_name: "prontera", position: {150, 150})

      on_exit(fn -> end_player_session(relog) end)

      restored = get_player_state(relog.pid)

      assert restored.cart_type == 1
      assert %{0 => %InventoryItem{nameid: @potion, amount: 4}} = restored.cart
      assert StatusStorage.has_status?(:player, char.id, @status_id)

      assert band(StatusDisplay.spawn_state(:player, char.id).effect_state, Option.id(:cart1)) !=
               0
    end
  end

  describe "unmount" do
    test "is blocked while the cart holds items and succeeds once empty" do
      %{pid: pid, character: char} =
        start_merchant(pushcart_level: 1, inventory: [{@potion, 10}])

      char_id = char.id

      mount!(pid)

      inv_index = client_index_of(get_player_state(pid).inventory, @potion)
      simulate_incoming_message(pid, %MoveToCartRequest{inventory_index: inv_index, amount: 4})
      assert_receive {:packet_sent, %CartItemAdded{}, _}, 1_000

      # Unmount rejected: cart still holds items, so nothing changes.
      simulate_incoming_message(pid, %CartMountRequest{mount: false})
      still_mounted = await_state(pid)
      assert still_mounted.cart_type == 1
      assert map_size(still_mounted.cart) == 1
      assert StatusStorage.has_status?(:player, char.id, @status_id)
      assert Repo.get(Character, char.id).cart == 1

      # Empty the cart, then unmount succeeds and clears the sprite. Flush first
      # so the cleared-sprite assertion can't match the cart1 UnitStateChange the
      # mount left in the mailbox.
      cart_index = client_index_of(still_mounted.cart, @potion)
      simulate_incoming_message(pid, %MoveFromCartRequest{cart_index: cart_index, amount: 4})
      assert_receive {:packet_sent, %ItemAdded{}, _}, 1_000
      flush_packets()

      simulate_incoming_message(pid, %CartMountRequest{mount: false})
      unmounted = await_state(pid)

      assert unmounted.cart_type == 0
      assert unmounted.walk_speed == @base_walk_speed
      refute StatusStorage.has_status?(:player, char.id, @status_id)
      assert Repo.get(Character, char.id).cart == 0

      # do_unmount re-broadcasts the cleared sprite (no cart option bit).
      assert_receive {:packet_sent, %UnitStateChange{unit_id: ^char_id, effect_state: 0}, _},
                     1_000
    end
  end

  defp start_merchant(opts) do
    pushcart_level = Keyword.get(opts, :pushcart_level, 1)
    base_level = Keyword.get(opts, :base_level, 50)
    inventory = Keyword.get(opts, :inventory, [])

    character = insert_merchant(base_level: base_level)
    Enum.each(inventory, fn {nameid, amount} -> seed_inventory(character.id, nameid, amount) end)

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> StatusStorage.remove_status(:player, character.id, @status_id) end)

    flush_packets()
    learn_pushcart(session.pid, pushcart_level)
    flush_packets()

    Map.put(session, :character, character)
  end

  defp insert_merchant(attrs) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "merchant#{uniq}",
        userid: "merchant#{uniq}",
        user_pass: "password",
        email: "merchant#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: "Carter#{uniq}",
            class: @merchant_class,
            base_level: 50,
            job_level: 50,
            str: 10,
            agi: 10,
            vit: 10,
            int: 10,
            dex: 10,
            luk: 10,
            skill_point: 20,
            last_map: "prontera",
            last_x: 150,
            last_y: 150,
            save_map: "prontera",
            save_x: 150,
            save_y: 150
          },
          Map.new(attrs)
        )
      )
      |> Repo.insert()

    character
  end

  defp seed_inventory(char_id, nameid, amount) do
    {:ok, item} =
      InventoryPersistence.insert_item(char_id, %{nameid: nameid, amount: amount, identify: 1})

    item
  end

  defp learn_pushcart(pid, levels) when levels > 0 do
    id = catalog_id(:mc_pushcart)
    Enum.each(1..levels, fn _ -> learn(pid, id) end)
  end

  defp learn(pid, skill_id) do
    simulate_incoming_message(pid, %LearnSkill{skill_id: skill_id})
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end

  defp mount!(pid) do
    simulate_incoming_message(pid, %CartMountRequest{mount: true})
    assert_receive {:packet_sent, %CartInfo{}, _}, 1_000
  end

  # `simulate_incoming_message` routes through `handle_info`, which enqueues the
  # handler cast *behind* an immediate `get_state`; a second `get_state` is
  # therefore guaranteed to observe a handler that emits no packet to sync on
  # (e.g. a rejected unmount).
  defp await_state(pid) do
    _ = get_player_state(pid)
    get_player_state(pid)
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp skill_def(name) do
    {:ok, definition} = Catalog.by_id(catalog_id(name))
    definition
  end

  defp client_index_of(map, nameid) do
    {server_index, _item} = Enum.find(map, fn {_index, item} -> item.nameid == nameid end)
    PlayerState.client_index(server_index)
  end

  defp held(map, nameid) do
    Enum.reduce(map, 0, fn
      {_index, %InventoryItem{nameid: ^nameid, amount: amount}}, acc -> acc + amount
      _entry, acc -> acc
    end)
  end
end
