defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingShopHandler do
  @moduledoc "Owns paid vending preparation and the seller's shop lifecycle."

  import Bitwise, only: [band: 2]

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.Net.VendingCloseRequest
  alias Aesir.Net.VendingCloseResult
  alias Aesir.Net.VendingList
  alias Aesir.Net.VendingListRequest
  alias Aesir.Net.VendingOpenRequest
  alias Aesir.Net.VendingOpenResult
  alias Aesir.Net.VendingSetupReady
  alias Aesir.Net.VendingShopItem
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ClientItemType
  alias Aesir.ZoneServer.Mmo.ItemManagement.CreatorNames
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Mmo.Skill.UseRestrictions
  alias Aesir.ZoneServer.Mmo.Skills.Merchant.McVending
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.InventoryView
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.Permissions
  alias Aesir.ZoneServer.Unit.Vending.Registry

  @open_codes %{
    invalid_request: :VEND_INVALID_REQUEST,
    setup_expired: :VEND_SETUP_EXPIRED,
    no_cart: :VEND_NO_CART,
    skill_not_learned: :VEND_SKILL_NOT_LEARNED,
    invalid_title: :VEND_INVALID_TITLE,
    no_items: :VEND_NO_ITEMS,
    too_many_slots: :VEND_TOO_MANY_SLOTS,
    duplicate_slot: :VEND_DUPLICATE_SLOT,
    invalid_amount: :VEND_INVALID_AMOUNT,
    invalid_price: :VEND_INVALID_PRICE,
    item_not_in_cart: :VEND_ITEM_NOT_IN_CART,
    insufficient_stock: :VEND_INSUFFICIENT_STOCK,
    item_unidentified: :VEND_ITEM_UNIDENTIFIED,
    item_broken: :VEND_ITEM_BROKEN,
    item_rental: :VEND_ITEM_RENTAL,
    item_bound: :VEND_ITEM_BOUND,
    item_untradeable: :VEND_ITEM_UNTRADEABLE,
    zeny_limit: :VEND_ZENY_LIMIT,
    forbidden: :VEND_FORBIDDEN,
    invalid_transition: :VEND_INVALID_STATE,
    map_restricted: :VEND_MAP_RESTRICTED,
    cell_restricted: :VEND_CELL_RESTRICTED,
    room_restricted: :VEND_FORBIDDEN
  }

  @doc "Publishes an already-paid preparation offer without consuming resources again."
  @spec prepare_setup(SessionState.t(), %{level: pos_integer(), sp_spent: non_neg_integer()}) ::
          {:ok, SessionState.t()} | {:error, atom()}
  def prepare_setup(%SessionState{game_state: game_state} = state, %{
        level: level,
        sp_spent: spent
      }) do
    with true <- is_nil(state.vending_setup),
         true <- game_state.cart_type > 0,
         access = PortalAccess.trade_permissions(game_state),
         true <- Permissions.can_trade?(access) do
      eligible =
        game_state.cart
        |> Permissions.eligibility(access)
        |> Enum.flat_map(fn
          {index, :ok} -> [index]
          _refused -> []
        end)
        |> Enum.sort()

      setup_id = new_token()
      grant = %{setup_id: setup_id, level: level, sp_spent: spent}
      rules = Config.vending_rules()

      MessageRouter.send_to(state.connection_pid, %VendingSetupReady{
        setup_id: setup_id,
        max_slots: McVending.max_slots(level),
        min_unit_price: 0,
        max_unit_price: rules.max_price,
        max_title_bytes: 79,
        sellable_cart_indices: eligible,
        sp_spent: spent
      })

      {:ok, %{state | vending_setup: grant, work_in_progress: true}}
    else
      false -> {:error, :failed}
    end
  end

  @doc "Submits listings against the exact paid grant and reports the accepted snapshot."
  @spec handle_open(SessionState.t(), VendingOpenRequest.t()) :: {:noreply, SessionState.t()}
  def handle_open(state, %VendingOpenRequest{} = request) do
    result =
      with :ok <- check_open_identity(state, request) do
        entries = Enum.map(request.entries, &{&1.cart_index, &1.amount, &1.price})
        open_shop(state, request.title, entries)
      end

    case result do
      {:ok, opened} ->
        shop = opened.game_state.state_context

        packet = %VendingOpenResult{
          request_id: request.request_id,
          setup_id: request.setup_id,
          result: :VEND_OK,
          vendor_unit_id: opened.game_state.character_id,
          shop_id: shop.shop_id,
          title: shop.title,
          items: shop_items(opened.game_state.cart, shop.items)
        }

        MessageRouter.send_to(state.connection_pid, packet)
        {:noreply, opened}

      {:error, reason} ->
        retained = [
          :invalid_request,
          :setup_expired,
          :invalid_title,
          :invalid_transition,
          :map_restricted,
          :cell_restricted,
          :room_restricted
        ]

        state =
          if same_setup?(state, request.setup_id) and reason not in retained,
            do: cancel_setup(state, :open_failed),
            else: state

        MessageRouter.send_to(state.connection_pid, %VendingOpenResult{
          request_id: request.request_id,
          setup_id: request.setup_id,
          result: Map.fetch!(@open_codes, reason),
          setup_active: same_setup?(state, request.setup_id)
        })

        {:noreply, state}
    end
  end

  @doc "Opens a shop from a server-held paid grant, without charging or moving items."
  @spec open_shop(SessionState.t(), String.t(), [Vending.entry()]) ::
          {:ok, SessionState.t()} | {:error, atom()}
  def open_shop(%SessionState{game_state: game_state} = state, title, entries) do
    with true <- state.vending_setup != nil,
         :ok <- check_room_permission(game_state),
         :ok <- UseRestrictions.vending_location(game_state),
         :ok <- check_cart(game_state),
         {:ok, level} <- learned_level(game_state),
         {:ok, title} <- Vending.normalize_title(title),
         access = PortalAccess.trade_permissions(game_state),
         true <- Permissions.can_trade?(access),
         context = %{
           rules: Config.vending_rules(),
           seller_zeny: game_state.zeny,
           eligibility: Permissions.eligibility(game_state.cart, access)
         },
         {:ok, items} <-
           Vending.validate_open(game_state.cart, entries, McVending.max_slots(level), context),
         shop = %{
           shop_id: new_token(),
           title: title,
           owner_char_id: game_state.character_id,
           items: items,
           total_earned: 0,
           sale_sequence: 0
         },
         {:ok, opened} <- PlayerState.transition_to(game_state, :vending, shop) do
      state = cancel_setup(state, :opened)
      state = StateCommit.commit(state, opened)
      Registry.put(opened.character_id, self(), shop)

      Broadcast.to_in_range(
        opened.map_name,
        opened.x,
        opened.y,
        Config.view_range(),
        %VendingBoardShown{unit_id: opened.character_id, title: title, shop_id: shop.shop_id},
        []
      )

      {:ok, state}
    else
      false -> {:error, if(state.vending_setup == nil, do: :setup_expired, else: :forbidden)}
      error -> error
    end
  end

  defp check_open_identity(state, request) do
    cond do
      request.request_id == 0 or request.setup_id == "" -> {:error, :invalid_request}
      not same_setup?(state, request.setup_id) -> {:error, :setup_expired}
      true -> :ok
    end
  end

  defp same_setup?(%{vending_setup: %{setup_id: token}}, token), do: true
  defp same_setup?(_state, _token), do: false

  defp check_room_permission(%{character_id: id}) do
    case StatusStorage.get_status(:player, id, :sc_nochat) do
      %{val1: flags} when band(flags, 0x10) != 0 -> {:error, :room_restricted}
      _allowed -> :ok
    end
  end

  defp check_cart(%{cart_type: type}) when type > 0, do: :ok
  defp check_cart(_game_state), do: {:error, :no_cart}

  defp learned_level(%{stats: stats}) do
    case Stats.skill_level(stats, 41) do
      level when level > 0 -> {:ok, level}
      _missing -> {:error, :skill_not_learned}
    end
  end

  defp new_token, do: :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)

  defp shop_items(cart, items) do
    rows = Vending.build_snapshot(cart, items)
    names = rows |> Enum.map(&%InventoryItem{craft: &1.craft}) |> CreatorNames.names_for()
    Enum.map(rows, &shop_item(&1, names))
  end

  defp shop_item(row, names) do
    {kind, creator, signer} =
      case ItemCraft.from_map(row.craft) do
        {:ok, %ItemCraft{kind: :signed, creator_char_id: id}} ->
          {:CREATOR_SIGNED, id, Map.get(names, id, "")}

        {:ok, %ItemCraft{kind: :forged, creator_char_id: id}} ->
          {:CREATOR_FORGED, id, Map.get(names, id, "")}

        :error ->
          {:CREATOR_NONE, 0, ""}
      end

    {:ok, definition} = ItemManagement.get_item_by_id(row.nameid)

    %VendingShopItem{
      index: row.index,
      nameid: row.nameid,
      type: ClientItemType.to_client_type(definition.type),
      amount: row.amount,
      identified: row.identify == 1,
      attribute: row.attribute,
      refine: row.refine,
      cards: row.cards,
      price: row.price,
      signer_name: signer,
      creator_id: creator,
      creator_kind: kind,
      options: InventoryView.item_options(row.random_options),
      enchant_grade: row.enchant_grade
    }
  end

  @doc "Reads the live shop snapshot without calling its owning session."
  @spec build_list(non_neg_integer()) :: {:ok, VendingList.t()} | :error
  def build_list(vendor_id) do
    with {:ok,
          {_module,
           %{action_state: :vending, cart: cart, state_context: %{shop_id: shop_id} = shop}, _pid}} <-
           UnitRegistry.get_unit(:player, vendor_id),
         {:ok, %{shop_id: ^shop_id}} <- Registry.get(vendor_id) do
      {:ok, snapshot(cart, shop, vendor_id)}
    else
      _missing -> :error
    end
  end

  @doc "Replies to a browse request, including missing or replaced shops."
  @spec handle_list(SessionState.t(), VendingListRequest.t()) :: {:noreply, SessionState.t()}
  def handle_list(state, %VendingListRequest{} = request) do
    packet =
      with :ok <- check_list_identity(state, request),
           {:ok, snapshot} <- build_list(request.vendor_unit_id),
           :ok <- check_expected_shop(request.expected_shop_id, snapshot.shop_id),
           :ok <- check_browse_access(state, request.vendor_unit_id) do
        earned =
          if request.vendor_unit_id == state.game_state.character_id,
            do: snapshot.total_earned,
            else: 0

        %{snapshot | request_id: request.request_id, total_earned: earned}
      else
        :error -> list_refusal(request, :VEND_LIST_NOT_OPEN)
        {:error, :invalid_request} -> list_refusal(request, :VEND_LIST_INVALID_REQUEST)
        {:error, :shop_changed} -> list_refusal(request, :VEND_LIST_SHOP_CHANGED)
        {:error, :forbidden} -> list_refusal(request, :VEND_LIST_FORBIDDEN)
      end

    MessageRouter.send_to(state.connection_pid, packet)
    {:noreply, state}
  end

  @doc "Publishes authoritative owner state after loading or lifecycle invalidation."
  @spec publish_owner_snapshot(SessionState.t()) :: SessionState.t()
  def publish_owner_snapshot(%{game_state: %{action_state: :vending} = gs} = state) do
    MessageRouter.send_to(
      state.connection_pid,
      snapshot(gs.cart, gs.state_context, gs.character_id)
    )

    state
  end

  def publish_owner_snapshot(state) do
    MessageRouter.send_to(state.connection_pid, %VendingList{
      vendor_unit_id: state.game_state.character_id,
      result: :VEND_LIST_NOT_OPEN
    })

    state
  end

  defp snapshot(cart, shop, vendor_id) do
    %VendingList{
      vendor_unit_id: vendor_id,
      shop_id: shop.shop_id,
      title: shop.title,
      items: shop_items(cart, shop.items),
      total_earned: shop.total_earned,
      result: :VEND_LIST_OK
    }
  end

  defp check_list_identity(state, request) do
    owner = request.vendor_unit_id == state.game_state.character_id

    if request.request_id > 0 and request.vendor_unit_id > 0 and
         (owner or request.expected_shop_id != ""), do: :ok, else: {:error, :invalid_request}
  end

  defp check_expected_shop("", _current), do: :ok
  defp check_expected_shop(id, id), do: :ok
  defp check_expected_shop(_expected, _current), do: {:error, :shop_changed}

  defp check_browse_access(%{game_state: %{character_id: vendor_id}}, vendor_id), do: :ok

  defp check_browse_access(state, vendor_id) do
    with {:ok, {_module, vendor, _pid}} <- UnitRegistry.get_unit(:player, vendor_id),
         buyer_access = PortalAccess.trade_permissions(state.game_state),
         seller_access = PortalAccess.trade_permissions(vendor),
         true <- Permissions.can_trade?(buyer_access) and Permissions.can_trade?(seller_access) do
      :ok
    else
      _refused -> {:error, :forbidden}
    end
  end

  defp list_refusal(request, result),
    do: %VendingList{
      request_id: request.request_id,
      vendor_unit_id: request.vendor_unit_id,
      result: result
    }

  @doc "Releases the setup lock without refunding the already-completed skill use."
  @spec cancel_setup(SessionState.t(), atom()) :: SessionState.t()
  def cancel_setup(%{vending_setup: nil} = state, _reason), do: state

  def cancel_setup(%SessionState{} = state, _reason) do
    %{state | vending_setup: nil, work_in_progress: state.progress_bar != nil}
  end

  @doc "Closes the owned shop on user or lifecycle teardown, leaving unsold stock in the cart."
  @spec close_shop(SessionState.t(), atom()) :: {:ok, SessionState.t()}
  def close_shop(%{game_state: %{action_state: :vending} = game_state} = state, reason) do
    shop_id = Map.fetch!(game_state.state_context, :shop_id)
    Registry.remove(game_state.character_id)

    Broadcast.to_in_range(
      game_state.map_name,
      game_state.x,
      game_state.y,
      Config.view_range(),
      %VendingBoardRemoved{
        unit_id: game_state.character_id,
        shop_id: shop_id,
        reason: close_reason(reason)
      },
      []
    )

    {:ok, idle} = PlayerState.transition_to(game_state, :idle)
    {:ok, %{state | game_state: idle}}
  end

  def close_shop(%SessionState{} = state, reason), do: {:ok, cancel_setup(state, reason)}

  defp close_reason(:user_closed), do: :VEND_CLOSURE_USER_CLOSED
  defp close_reason(:manual), do: :VEND_CLOSURE_USER_CLOSED
  defp close_reason(:sold_out), do: :VEND_CLOSURE_SOLD_OUT
  defp close_reason(:disconnected), do: :VEND_CLOSURE_DISCONNECTED
  defp close_reason(:job_change), do: :VEND_CLOSURE_JOB_CHANGED
  defp close_reason(:relocated), do: :VEND_CLOSURE_RELOCATED
  defp close_reason(_invalidated), do: :VEND_CLOSURE_INVALIDATED

  @doc "Acknowledges a close against its exact setup or shop identity."
  @spec handle_close(SessionState.t(), VendingCloseRequest.t()) :: {:noreply, SessionState.t()}
  def handle_close(state, %VendingCloseRequest{request_id: request_id, target: target}) do
    {state, result} =
      if request_id > 0 and valid_target?(target),
        do: close_target(state, target),
        else: {state, :VEND_CLOSE_INVALID_REQUEST}

    MessageRouter.send_to(state.connection_pid, %VendingCloseResult{
      request_id: request_id,
      target: target,
      result: result
    })

    {:noreply, state}
  end

  defp valid_target?({kind, token}) when kind in [:setup_id, :shop_id],
    do: is_binary(token) and byte_size(token) > 0

  defp valid_target?(_target), do: false

  defp close_target(state, target) do
    case {target, state.vending_setup, state.game_state.action_state,
          state.game_state.state_context} do
      {{:setup_id, token}, %{setup_id: token}, _action, _context} ->
        {cancel_setup(state, :user_canceled), :VEND_CLOSE_SETUP_CANCELED}

      {{:shop_id, token}, nil, :vending, %{shop_id: token}} ->
        {:ok, closed} = close_shop(state, :user_closed)
        {StateCommit.commit(closed, closed.game_state), :VEND_CLOSE_SHOP_CLOSED}

      {_target, nil, action, _context} when action != :vending ->
        {state, :VEND_CLOSE_ALREADY_CLOSED}

      _other_instance ->
        {state, :VEND_CLOSE_INVALID_TARGET}
    end
  end
end
