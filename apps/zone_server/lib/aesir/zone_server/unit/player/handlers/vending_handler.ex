defmodule Aesir.ZoneServer.Unit.Player.Handlers.VendingHandler do
  @moduledoc """
  Opens and closes a merchant's vending shop (design "Open-shop flow" /
  "Close-shop flow").

  `PlayerSession` is the single writer; both functions take and return the
  session `state` map and run inside a session cast. Opening gates on a mounted
  cart (`SC_PUSHCART` active) and a learned `MC_VENDING`, validates the listing
  through the pure `Vending` core, enters the frozen `:vending` action state with
  the shop carried in `state_context`, mirrors the shop into the `Vending.Registry`
  for out-of-session browse/board reads, and area-broadcasts the title board.
  Closing tears the shop down and returns to `:idle`; unsold stock simply stays
  in the cart (no item move).
  """

  require Logger

  alias Aesir.Net.VendingBoardRemoved
  alias Aesir.Net.VendingBoardShown
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.McVending
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Vending
  alias Aesir.ZoneServer.Unit.Vending.Registry
  alias Aesir.ZoneServer.Unit.Vending.ShopItem

  @push_cart_status :sc_push_cart
  @mc_vending_id McVending.definition().id

  @typedoc "The live shop carried in `:vending` `state_context` and the registry."
  @type shop :: %{title: String.t(), owner_char_id: integer(), items: [ShopItem.t()]}

  @type state :: %{
          required(:connection_pid) => pid(),
          required(:game_state) => PlayerState.t(),
          optional(atom()) => term()
        }

  @doc """
  Opens a vending shop selling `entries` (`{cart_index, amount, price}` lines)
  from the mounted cart under `title`.

  Requires the cart mounted (`SC_PUSHCART` active) and `MC_VENDING` learned; the
  learned level caps the line count via `McVending.max_slots/1`. On success it
  validates through `Vending.validate_open/3`, transitions to `:vending` with the
  shop in `state_context`, registers the shop, broadcasts `VendingBoardShown` to
  in-range players, and returns `{:ok, state}`. On any failure it returns a typed
  error and leaves the session, registry and clients untouched.
  """
  @spec open_shop(state(), String.t(), [Vending.entry()]) ::
          {:ok, state()}
          | {:error,
             :no_cart
             | :skill_not_learned
             | :too_many_slots
             | :invalid_amount
             | :invalid_price
             | :item_not_in_cart
             | :insufficient_stock
             | :invalid_transition}
  def open_shop(%{game_state: gs} = state, title, entries) do
    char_id = gs.character_id

    with :ok <- ensure_cart_mounted(char_id),
         {:ok, level} <- ensure_vending_learned(gs),
         {:ok, shop_items} <- Vending.validate_open(gs.cart, entries, McVending.max_slots(level)),
         shop = %{title: title, owner_char_id: char_id, items: shop_items},
         {:ok, new_gs} <- PlayerState.transition_to(gs, :vending, shop) do
      Registry.put(char_id, self(), shop)
      broadcast_board(new_gs, %VendingBoardShown{unit_id: char_id, title: title})
      {:ok, %{state | game_state: new_gs}}
    end
  end

  @doc """
  Closes the shop for `reason`.

  Removes the registry entry, broadcasts `VendingBoardRemoved` to in-range
  players, and returns to `:idle`. Unsold stock stays in the cart — no item is
  moved. Returns `{:ok, state}`.
  """
  @spec close_shop(state(), atom()) :: {:ok, state()}
  def close_shop(%{game_state: gs} = state, reason) do
    char_id = gs.character_id
    Logger.debug("Closing vending shop for #{char_id}: #{inspect(reason)}")

    Registry.remove(char_id)
    broadcast_board(gs, %VendingBoardRemoved{unit_id: char_id})

    {:ok, new_gs} = PlayerState.transition_to(gs, :idle)
    {:ok, %{state | game_state: new_gs}}
  end

  @spec ensure_cart_mounted(integer()) :: :ok | {:error, :no_cart}
  defp ensure_cart_mounted(char_id) do
    if StatusStorage.has_status?(:player, char_id, @push_cart_status) do
      :ok
    else
      {:error, :no_cart}
    end
  end

  @spec ensure_vending_learned(PlayerState.t()) ::
          {:ok, pos_integer()} | {:error, :skill_not_learned}
  defp ensure_vending_learned(%{stats: %{progression: %{learned_skills: learned}}}) do
    case Learned.learned_level(learned, @mc_vending_id) do
      level when level > 0 -> {:ok, level}
      _ -> {:error, :skill_not_learned}
    end
  end

  @spec broadcast_board(PlayerState.t(), struct()) :: :ok
  defp broadcast_board(%{map_name: map_name, x: x, y: y}, packet) do
    Broadcast.to_in_range(map_name, x, y, Config.view_range(), packet, [])
  end
end
