defmodule Aesir.ZoneServer.Mmo.WalkSpeed do
  @moduledoc """
  A unit's walk speed (milliseconds per straight cell) from its base speed and
  its statuses. One recipe serves players, monsters and homunculi in both modes;
  the terms only a player has arrive through `t:player_inputs/0`.

  The recipe works on a speed rate that starts at 100:

    1. A cast speed rate (Free Cast while a player casts with it learned)
       replaces the rate, and steps 2 to 5 are skipped.
    2. The mount haste (`:move_haste2`, the strongest one) is subtracted.
    3. The slow is added. For a player hiding with Tunnel Drive it is Tunnel
       Drive's own slow, ignoring every other slow. Otherwise it is the
       strongest status slow (`:movement_speed`) or item slow.
    4. The haste is subtracted: the strongest status haste (`:haste_rate`),
       the Assassin family's Improve Dodge haste, or item haste.
    5. The rate is floored at 40.

  The speed is then the base plus its `:walk_delay_rate` percent (Pushcart),
  times the rate when it is not 100. A `:walk_speed_override` (Steel Body)
  replaces it and a `:walk_speed_floor` (Defender) raises it. The result is
  clamped to 20..1000, and a player's speed is never below 50.

  Item speed is the sum of the bonus speed rate and the additive speed rate,
  positive meaning faster. A positive sum is a haste and a negative one a slow,
  each competing with the statuses for the strongest.
  """

  @min_walk_speed 20
  @max_walk_speed 1_000
  @min_player_walk_speed 50
  @min_speed_rate 40

  @typedoc """
  The terms of the recipe only a player has.

    - `:tunnel_drive_slow`: Tunnel Drive's slow while hidden (`120 - 6 * level`),
      0 when not hidden or without Tunnel Drive.
    - `:item_speed`: bonus speed rate plus additive speed rate, positive = faster.
    - `:improve_dodge_haste`: the Improve Dodge level for the Assassin family, else 0.
    - `:cast_speed_rate`: Free Cast's speed rate while a cast is in flight, else 0.
  """
  @type player_inputs :: %{
          optional(:tunnel_drive_slow) => non_neg_integer(),
          optional(:item_speed) => integer(),
          optional(:improve_dodge_haste) => non_neg_integer(),
          optional(:cast_speed_rate) => non_neg_integer()
        }

  @doc """
  The walk speed for `base_speed` under the merged status `modifiers`.

  Pass `player` for a player (its inputs, possibly empty) and `nil` for any
  other unit.
  """
  @spec calculate(pos_integer(), map(), player_inputs() | nil) :: pos_integer()
  def calculate(base_speed, modifiers, player \\ nil) do
    rate = speed_rate(modifiers, player)
    walk_delay_rate = Map.get(modifiers, :walk_delay_rate, 0)
    speed = base_speed + div(base_speed * walk_delay_rate, 100)
    speed = if rate == 100, do: speed, else: div(speed * rate, 100)

    speed
    |> override(modifiers)
    |> max(Map.get(modifiers, :walk_speed_floor, 0))
    |> min(@max_walk_speed)
    |> max(@min_walk_speed)
    |> player_floor(player)
  end

  defp speed_rate(modifiers, player) do
    case input(player, :cast_speed_rate) do
      0 ->
        rate = 100 - Map.get(modifiers, :move_haste2, 0) + slow(modifiers, player)
        max(rate - haste(modifiers, player), @min_speed_rate)

      cast_speed_rate ->
        cast_speed_rate
    end
  end

  defp slow(modifiers, player) do
    case input(player, :tunnel_drive_slow) do
      0 -> max(Map.get(modifiers, :movement_speed, 0), max(-input(player, :item_speed), 0))
      tunnel_drive_slow -> tunnel_drive_slow
    end
  end

  defp haste(modifiers, player) do
    modifiers
    |> Map.get(:haste_rate, 0)
    |> max(input(player, :improve_dodge_haste))
    |> max(input(player, :item_speed))
  end

  defp override(_speed, %{walk_speed_override: override}), do: override
  defp override(speed, _modifiers), do: speed

  defp player_floor(speed, nil), do: speed
  defp player_floor(speed, _player), do: max(speed, @min_player_walk_speed)

  defp input(nil, _key), do: 0
  defp input(player, key), do: Map.get(player, key, 0)
end
