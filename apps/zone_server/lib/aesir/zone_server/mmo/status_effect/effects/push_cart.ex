defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PushCart do
  @moduledoc """
  Pushcart (SC_PUSHCART).

  Permanent status attached to a Merchant while a cart is mounted. It carries
  both the cart's walk-speed penalty and the visible cart sprite tier.

  ## Instance convention

    - `val1` — the learned Pushcart skill level (0..10). Drives the speed
      penalty, which shrinks to 0 at max level.
    - `val2` — the cart sprite tier (`1`/`2`/`3`). Drives the `:cart1`/`:cart2`/`:cart3`
      sprite bit. An unset tier (`0`/`nil`) falls back to `:cart1`.

  The speed penalty mirrors rAthena `status_calc_speed` (`status.cpp`):

      if (sd && pc_iscarton(sd))
          speed += speed * (50 - 5 * pc_checkskill(sd, MC_PUSHCART)) / 100;

  expressed as a `:movement_speed` percentage modifier (positive = slower) folded
  into `walk_speed` by the status `:speed` recalc bridge.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_push_cart,
    properties: [:buff],
    calc_flags: [:speed],
    permanent: true

  alias Aesir.ZoneServer.Mmo.StatusEntry

  @impl true
  def modifiers(%StatusEntry{val1: level}, _context) do
    %{movement_speed: 50 - 5 * level}
  end

  @impl true
  def dynamic_option(%StatusEntry{val2: 2}), do: :cart2
  def dynamic_option(%StatusEntry{val2: 3}), do: :cart3
  def dynamic_option(%StatusEntry{}), do: :cart1
end
