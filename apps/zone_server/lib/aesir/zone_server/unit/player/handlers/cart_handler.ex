defmodule Aesir.ZoneServer.Unit.Player.Handlers.CartHandler do
  @moduledoc """
  Mounts/unmounts the pushcart, moves items between the inventory and the cart,
  and restores the cart on spawn (design "Flows").

  `PlayerSession` is the single writer; every public function takes and returns
  the session `state` map and runs inside a `handle_cast` (or, for
  `load_on_spawn/2`, inside `init/1`). The `SC_PUSHCART` status apply/remove is
  routed through `StatusManager` so the walk-speed recalc + `ParamChange`
  broadcast (Task 7) happen exactly as for any other status.

  ## Sprite broadcast

  `SC_PUSHCART` carries no static `:option`, so the generic apply/remove display
  path (`StatusDisplay.on_applied/on_removed`) skips its `UnitStateChange`. Mount,
  unmount, and tier change must therefore call `StatusDisplay.broadcast_state/2`
  explicitly to light up or clear the cart sprite. That broadcast already reaches
  every player in range including the owner, so `CartInfo` (the only message sent
  directly to the owner) is the only owner-directed packet — the sprite is never
  double-received.

  On spawn the sprite needs no explicit broadcast: it rides the spawn packet's
  `effect_state`, which `build_unit_spawn/1` folds from `StatusDisplay.spawn_state/2`.

  `load_on_spawn/2` is an exception to the GenServer-native dispatch contract:
  it runs inside `init/1`, before the GenServer loop starts, so it takes and
  returns bare session `state` rather than a GenServer tuple — a lifecycle
  helper, not a dispatch entry point.
  """

  require Logger

  alias Aesir.Commons.Models.CartItem
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.CartMountResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McPushcart
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Cart
  alias Aesir.ZoneServer.Unit.Player.Handlers.CartOps
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Rental

  @status_id :sc_push_cart
  @first_tier 1

  # rAthena `clif_parse_ChangeCart` base-level gates (strict `>`). Tiers 4-5 are
  # out of scope (3rd-job cart decorations), so the sprite tops out at tier 3.
  @tier2_min_level 40
  @tier3_min_level 65

  @doc """
  Mounts the cart.

  Requires `MC_PUSHCART` learned; without it the mount is rejected and the client
  is told with `CartMountResult{ok: false, reason: 1}`. When the player has no
  cart yet it sets `cart_type` to the first tier, applies the permanent
  `SC_PUSHCART` (`val1` = learned Pushcart level, `val2` = tier), persists
  `character.cart`, broadcasts the cart sprite, sends the owner the current
  `CartInfo`, and confirms with `CartMountResult{ok: true}`. A second mount while
  already mounted is rejected with `reason: 2`.
  """
  @spec mount(map()) :: {:noreply, map()}
  def mount(%{game_state: game_state} = state) do
    cond do
      pushcart_level(game_state) == 0 ->
        Logger.debug(
          "Cart mount rejected for #{game_state.character_id}: MC_PUSHCART not learned"
        )

        reject_mount(state, :CART_SKILL_NOT_LEARNED)

      game_state.cart_type > 0 ->
        reject_mount(state, :CART_ALREADY_MOUNTED)

      true ->
        do_mount(state)
    end
  end

  @doc """
  Unmounts the cart.

  Rejected unless the cart is empty so no items can be lost. On success it clears
  `cart_type`, persists `character.cart = 0`, removes `SC_PUSHCART`, and broadcasts
  the cleared sprite.
  """
  @spec unmount(map()) :: {:noreply, map()}
  def unmount(%{game_state: game_state} = state) do
    cond do
      game_state.cart_type == 0 ->
        {:noreply, state}

      map_size(game_state.cart) > 0 ->
        Logger.debug("Cart unmount rejected for #{game_state.character_id}: cart not empty")
        {:noreply, state}

      true ->
        do_unmount(state)
    end
  end

  @doc """
  Moves `amount` of the inventory item at the client `index` into the cart.

  Rejected (no state change, no client delta) when the cart is not mounted or the
  source item is equipped or favorited: the server is authoritative and must not
  trust a client requesting an illegal move. An unmounted move would otherwise
  commit a `cart_inventory` row that orphans against `character.cart = 0` and is
  lost on relog (`load_on_spawn/2` short-circuits when the character has no cart).
  Otherwise it delegates the atomic cross-container move to `CartOps`, commits
  both container maps, and emits the paired client deltas (inventory `ItemRemoved`
  + cart `CartItemAdded`). A weight/availability error from `CartOps` is handled
  the same way.
  """
  @spec move_to_cart(non_neg_integer(), non_neg_integer(), map()) :: {:noreply, map()}
  def move_to_cart(index, amount, %{game_state: game_state} = state)
      when is_integer(amount) and amount > 0 do
    server_index = PlayerState.server_index(index)
    char_id = game_state.character_id

    with :ok <- ensure_mounted(game_state),
         :ok <- ensure_movable_to_cart(game_state.inventory, server_index),
         {:ok, inventory, cart, inv_change, cart_change} <-
           CartOps.move_to_cart(
             char_id,
             game_state.inventory,
             game_state.cart,
             server_index,
             amount
           ) do
      committed =
        StatsManager.update_game_state(state, %{game_state | inventory: inventory, cart: cart})

      notify_inventory_removed(committed.connection_pid, inv_change, amount)
      notify_cart_added(committed.connection_pid, cart, cart_change)
      {:noreply, committed}
    else
      {:error, reason} ->
        Logger.debug("move_to_cart rejected for #{char_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def move_to_cart(_index, _amount, state), do: {:noreply, state}

  @doc """
  Moves `amount` of the cart item at the client `index` back into the inventory.

  Rejected (no state change, no client delta) when the cart is not mounted.
  Otherwise it delegates the atomic cross-container move to `CartOps`, commits
  both container maps, and emits the paired client deltas (cart `CartItemRemoved`
  + inventory `ItemAdded`). A weight/availability error from `CartOps` is handled
  the same way. No equipped/favorite guard is needed here: cart items are never
  equipped or favorited.
  """
  @spec move_to_inventory(non_neg_integer(), non_neg_integer(), map()) :: {:noreply, map()}
  def move_to_inventory(index, amount, %{game_state: game_state} = state)
      when is_integer(amount) and amount > 0 do
    server_index = PlayerState.server_index(index)
    char_id = game_state.character_id

    with :ok <- ensure_mounted(game_state),
         {:ok, inventory, cart, inv_change, cart_change} <-
           CartOps.move_to_inventory(
             char_id,
             game_state.inventory,
             game_state.cart,
             game_state.stats,
             server_index,
             amount
           ) do
      committed =
        StatsManager.update_game_state(state, %{game_state | inventory: inventory, cart: cart})

      notify_cart_removed(committed.connection_pid, cart_change, amount)
      InventoryManager.notify_added(committed.connection_pid, inventory, inv_change)
      {:noreply, committed}
    else
      {:error, reason} ->
        Logger.debug("move_to_inventory rejected for #{char_id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def move_to_inventory(_index, _amount, state), do: {:noreply, state}

  @doc """
  Restores a mounted cart on spawn.

  When the character has a cart (`character.cart > 0`) it loads the cart rows into
  `game_state.cart`, sets `cart_type`, and re-applies the permanent `SC_PUSHCART`
  (so the sprite folds into the spawn `effect_state` and the speed penalty is
  recomputed). The owner-facing `CartInfo` is sent by the map-load path alongside
  the inventory dump. Returns the committed session state.
  """
  @spec load_on_spawn(Character.t(), map()) :: map()
  def load_on_spawn(%Character{cart: tier}, state) when tier > 0 do
    do_load_on_spawn(tier, state)
  end

  def load_on_spawn(%Character{}, state), do: state

  @doc """
  Upgrades the mounted cart's sprite tier to the highest one `base_level` permits
  and commits it, for the `MC_CHANGECART` self-cast (design "Change Cart flow").

  Unlike the mount/unmount handlers this runs inside a skill `cast/4`, so it takes
  and returns the player's `game_state` (`PlayerState`) rather than the session
  `state` map; the interpreter's `commit_cast` writes the returned state back. It
  picks the tier from `base_level` (rAthena `clif_parse_ChangeCart` gates: tier 2
  above base level 40, tier 3 above 65), sets `cart_type`, persists
  `character.cart`, read-modify-writes the live `SC_PUSHCART` `val2` to the new
  tier (a whole-entry write via `StatusStorage.update_status/4`, never an
  `update_element` on a nested field), and rebroadcasts the cart sprite. When
  `base_level` grants no tier above the current one it changes nothing and returns
  `{:error, :no_cart_upgrade}` so the cast fizzles without spending SP.
  """
  @spec change_cart_tier(PlayerState.t(), non_neg_integer()) ::
          {:ok, PlayerState.t()} | {:error, :no_cart_upgrade}
  def change_cart_tier(%{character_id: char_id, cart_type: current} = game_state, base_level) do
    case tier_for_base_level(base_level) do
      tier when tier > current ->
        persist_cart_type(char_id, tier)

        StatusStorage.update_status(:player, char_id, @status_id, fn entry ->
          %{entry | val2: tier}
        end)

        StatusDisplay.broadcast_state(:player, char_id)
        {:ok, %{game_state | cart_type: tier}}

      _tier ->
        {:error, :no_cart_upgrade}
    end
  end

  @spec tier_for_base_level(non_neg_integer()) :: 1..3
  defp tier_for_base_level(base_level) when base_level > @tier3_min_level, do: 3
  defp tier_for_base_level(base_level) when base_level > @tier2_min_level, do: 2
  defp tier_for_base_level(_base_level), do: 1

  @spec do_mount(map()) :: {:noreply, map()}
  defp do_mount(%{game_state: game_state} = state) do
    char_id = game_state.character_id
    params = [val1: pushcart_level(game_state), val2: @first_tier]

    case StatusManager.handle_apply_status(@status_id, params, state) do
      {:reply, :ok, applied} ->
        persist_cart_type(char_id, @first_tier)

        committed =
          StatsManager.update_game_state(applied, %{applied.game_state | cart_type: @first_tier})

        StatusDisplay.broadcast_state(:player, char_id)

        MessageRouter.send_to(
          committed.connection_pid,
          InventoryView.cart_info(committed.game_state.cart)
        )

        MessageRouter.send_to(committed.connection_pid, %CartMountResult{result: :CART_OK})

        {:noreply, committed}

      {:reply, {:error, reason}, unchanged} ->
        Logger.warning("Cart mount: SC_PUSHCART apply failed for #{char_id}: #{inspect(reason)}")
        {:noreply, unchanged}
    end
  end

  @spec do_unmount(map()) :: {:noreply, map()}
  defp do_unmount(%{game_state: game_state} = state) do
    char_id = game_state.character_id

    {:reply, :ok, removed} = StatusManager.handle_remove_status(@status_id, state)
    persist_cart_type(char_id, 0)

    committed = StatsManager.update_game_state(removed, %{removed.game_state | cart_type: 0})
    StatusDisplay.broadcast_state(:player, char_id)

    {:noreply, committed}
  end

  @spec do_load_on_spawn(pos_integer(), map()) :: map()
  defp do_load_on_spawn(tier, %{game_state: game_state} = state) do
    cart = load_cart_map(game_state.character_id)
    loaded = %{state | game_state: %{game_state | cart: cart, cart_type: tier}}
    params = [val1: pushcart_level(game_state), val2: tier]

    case StatusManager.handle_apply_status(@status_id, params, loaded) do
      {:reply, :ok, applied} ->
        StatsManager.update_game_state(applied, applied.game_state)

      {:reply, {:error, reason}, _unchanged} ->
        Logger.warning(
          "Cart load: SC_PUSHCART apply failed for #{game_state.character_id}: #{inspect(reason)}"
        )

        loaded
    end
  end

  @spec reject_mount(map(), :CART_SKILL_NOT_LEARNED | :CART_ALREADY_MOUNTED) :: {:noreply, map()}
  defp reject_mount(%{connection_pid: connection_pid} = state, code) do
    MessageRouter.send_to(connection_pid, %CartMountResult{result: code})
    {:noreply, state}
  end

  @spec ensure_mounted(map()) :: :ok | {:error, :no_cart}
  defp ensure_mounted(%{cart_type: 0}), do: {:error, :no_cart}
  defp ensure_mounted(_game_state), do: :ok

  # rAthena blocks moving an equipped or favorited item into the cart; an
  # equipped move would also implicitly unequip the item with no stat/appearance
  # recalc, desyncing the player. A missing slot is left to `CartOps` to reject.
  @spec ensure_movable_to_cart(%{non_neg_integer() => InventoryItem.t()}, non_neg_integer()) ::
          :ok | {:error, :equipped | :favorite | :rental}
  defp ensure_movable_to_cart(inventory, server_index) do
    case PlayerState.get_by_index(inventory, server_index) do
      %InventoryItem{equip: equip} when equip > 0 -> {:error, :equipped}
      %InventoryItem{favorite: 1} -> {:error, :favorite}
      %InventoryItem{} = item -> if Rental.transferable?(item), do: :ok, else: {:error, :rental}
      _ -> :ok
    end
  end

  @spec pushcart_level(map()) :: non_neg_integer()
  defp pushcart_level(%{stats: %{progression: %{learned_skills: learned}}}) do
    Learned.learned_level(learned, McPushcart.definition().id)
  end

  @spec persist_cart_type(integer(), non_neg_integer()) :: :ok
  defp persist_cart_type(char_id, tier) do
    CharacterPersistence.update_character(char_id, %{cart: tier}, async: true)
    :ok
  end

  @spec load_cart_map(integer()) :: Cart.t()
  defp load_cart_map(char_id) do
    char_id
    |> Cart.load_cart()
    |> Enum.map(&cart_row_to_item/1)
    |> PlayerState.from_list()
  end

  # The in-memory cart holds `%InventoryItem{}` (so the pure Inventory core and
  # `CartOps` apply verbatim), while the rows persist as `%CartItem{}`. Convert at
  # the load boundary, preserving each row id so subsequent moves target it.
  @spec cart_row_to_item(CartItem.t()) :: InventoryItem.t()
  defp cart_row_to_item(%CartItem{} = row) do
    %InventoryItem{
      id: row.id,
      char_id: row.char_id,
      nameid: row.nameid,
      amount: row.amount,
      equip: row.equip,
      identify: row.identify,
      refine: row.refine,
      attribute: row.attribute,
      card0: row.card0,
      card1: row.card1,
      card2: row.card2,
      card3: row.card3,
      craft: row.craft,
      random_options: row.random_options,
      expire_time: row.expire_time,
      favorite: row.favorite,
      bound: row.bound,
      unique_id: row.unique_id,
      equip_switch: row.equip_switch,
      enchant_grade: row.enchant_grade
    }
  end

  @spec notify_inventory_removed(pid(), CartOps.change(), pos_integer()) :: :ok
  defp notify_inventory_removed(connection_pid, change, amount) do
    MessageRouter.send_to(
      connection_pid,
      InventoryView.item_removed(removal_index(change), amount)
    )
  end

  @spec notify_cart_removed(pid(), CartOps.change(), pos_integer()) :: :ok
  defp notify_cart_removed(connection_pid, change, amount) do
    MessageRouter.send_to(
      connection_pid,
      InventoryView.cart_item_removed(removal_index(change), amount)
    )
  end

  @spec notify_cart_added(pid(), Cart.t(), CartOps.change()) :: :ok
  defp notify_cart_added(connection_pid, cart, change) do
    Enum.each(InventoryManager.affected_indices(change), fn index ->
      item = PlayerState.get_by_index(cart, index)
      MessageRouter.send_to(connection_pid, InventoryView.cart_item_added(item, index))
    end)
  end

  @spec removal_index(CartOps.change()) :: non_neg_integer()
  defp removal_index({:removed, index}), do: index
  defp removal_index({:reduced, index, _left}), do: index
end
