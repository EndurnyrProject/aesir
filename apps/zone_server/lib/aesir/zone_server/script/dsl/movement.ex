defmodule Aesir.ZoneServer.Script.Dsl.Movement do
  @moduledoc """
  Player-relocation buildins for the script DSL: single-player warps (explicit
  cell, random cell, save point), rectangle and whole-map warps, and
  by-character-id warps.

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Internal
  alias Aesir.ZoneServer.Unit.Player.Handlers.WarpHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Relocates the player.

  - `{map, x, y}` — to an explicit cell. Halts on `:map_not_found`.
  - `:random` — to a random walkable cell on the current map (fly wing).
  - `:save_point` — to the player's save point (butterfly wing).

  Halts on a resolution or warp error. Halts `:no_player` on a detached ctx
  (there is no player to relocate).
  """
  @spec warp(Ctx.t(), {String.t(), non_neg_integer(), non_neg_integer()} | :random | :save_point) ::
          Ctx.t()
  def warp(%Ctx{} = ctx, {map, x, y}), do: warp(ctx, map, x, y)

  def warp(%Ctx{status: {:error, _}} = ctx, :random), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, :random), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{game_state: game_state} = ctx, :random) do
    case Cell.random_traversable(game_state.map_name) do
      {:ok, {x, y}} -> warp(ctx, game_state.map_name, x, y)
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  def warp(%Ctx{status: {:error, _}} = ctx, :save_point), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, :save_point), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{game_state: game_state} = ctx, :save_point) do
    warp(ctx, game_state.save_map, game_state.save_x, game_state.save_y)
  end

  @doc """
  Relocates the player to `{map, x, y}`.

  The map name is often a runtime value in transpiled scripts (`.@map$`,
  `strnpcinfo(4)`, a concat), so the rAthena special targets are resolved here
  too: `"Random"` warps to a random walkable cell and `"SavePoint"`/`"Save"`
  to the save point, both ignoring the coordinates (matching `buildin_warp`).
  """
  @spec warp(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def warp(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, _map, _x, _y), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{} = ctx, "Random", _x, _y), do: warp(ctx, :random)

  def warp(%Ctx{} = ctx, save, _x, _y) when save in ["SavePoint", "Save"],
    do: warp(ctx, :save_point)

  # An NPC interaction runs in its own process and only holds a read snapshot of
  # the player state, so the warp is routed to the session (the single writer of
  # map/coordinates); relocating the snapshot would leave the session standing on
  # the origin cell and snap the player back on its next step. An item script
  # (`session_pid: nil`) already runs inline on the session, where the ctx state
  # it returns *is* the state that gets committed, so it warps directly.
  def warp(%Ctx{session_pid: nil} = ctx, map, x, y) do
    session = %{game_state: ctx.game_state, connection_pid: ctx.connection_pid}

    case WarpHandler.warp(session, map, x, y) do
      {:ok, %{game_state: new_game_state}} -> %{ctx | game_state: new_game_state}
      {:error, reason} -> Ctx.halt(ctx, reason)
    end
  end

  def warp(%Ctx{} = ctx, map, x, y), do: Internal.apply_op(ctx, {:warp, map, x, y})

  @doc """
  Warps players from one map to another (`mapwarp`). With no filter, every
  player on `from_map` is relocated. Filter type `1` selects a guild and type
  `2` a party by `id`; any other type selects everyone.

  A destination of `"Random"` shuffles players on `from_map`. Coordinates
  `{0, 0}` select an independent random traversable destination for each player.
  The world effect works from a detached context and skips offline players.
  """
  @spec mapwarp(Ctx.t(), String.t(), String.t(), integer(), integer()) :: Ctx.t()
  def mapwarp(%Ctx{} = ctx, from_map, to_map, x, y),
    do: mapwarp(ctx, from_map, to_map, x, y, 0, 0)

  @spec mapwarp(Ctx.t(), String.t(), String.t(), integer(), integer(), integer()) :: Ctx.t()
  def mapwarp(%Ctx{} = ctx, from_map, to_map, x, y, _type),
    do: mapwarp(ctx, from_map, to_map, x, y, 0, 0)

  @spec mapwarp(
          Ctx.t(),
          String.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: Ctx.t()
  def mapwarp(%Ctx{status: {:error, _}} = ctx, _from, _to, _x, _y, _type, _id), do: ctx

  def mapwarp(%Ctx{} = ctx, from_map, to_map, x, y, type, id) do
    from_map
    |> SpatialIndex.get_players_on_map()
    |> Enum.each(&warp_map_player(&1, from_map, to_map, x, y, type, id))

    ctx
  end

  @doc """
  Warps every player inside the rectangle `{x1,y1}`–`{x2,y2}` on `from_map` to
  `to_map` at `{x3,y3}` (rAthena `areawarp`). The area-destination form
  (adding `x4,y4`) relocates each player to a random cell inside that
  rectangle instead of a fixed point.

  A world effect that does not touch the attached player's state: the context
  is returned unchanged and it runs even on a detached ctx. An offline or
  unknown target is skipped, matching rAthena's success-on-absence.
  """
  @spec areawarp(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(%Ctx{status: {:error, _}} = ctx, _from, _x1, _y1, _x2, _y2, _to, _x3, _y3),
    do: ctx

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(%Ctx{} = ctx, from_map, x1, y1, x2, y2, to_map, x3, y3) do
    warp_players_in_area(from_map, x1, y1, x2, y2, fn _ -> {to_map, x3, y3} end)
    ctx
  end

  @spec areawarp(
          Ctx.t(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer(),
          String.t(),
          integer(),
          integer(),
          integer(),
          integer()
        ) :: Ctx.t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(
        %Ctx{status: {:error, _}} = ctx,
        _from,
        _x1,
        _y1,
        _x2,
        _y2,
        _to,
        _x3,
        _y3,
        _x4,
        _y4
      ),
      do: ctx

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def areawarp(%Ctx{} = ctx, from_map, x1, y1, x2, y2, to_map, x3, y3, x4, y4) do
    dx_min = min(x3, x4)
    dx_max = max(x3, x4)
    dy_min = min(y3, y4)
    dy_max = max(y3, y4)

    warp_players_in_area(from_map, x1, y1, x2, y2, fn _ ->
      {to_map, Enum.random(dx_min..dx_max), Enum.random(dy_min..dy_max)}
    end)

    ctx
  end

  @doc """
  Warps a specific player by character id (rAthena `warpchar`). The three-arg
  form targets the attached player (equivalent to `warp/4`); the four-arg form
  targets `char_id`, casting a warp to that player's session when they are
  online and no-oping otherwise (rAthena returns success for an offline
  target). "Random"/"SavePoint" string targets are resolved only by the
  three-arg (attached player) form, through `warp/4`.
  """
  @spec warpchar(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer()) :: Ctx.t()
  def warpchar(%Ctx{status: {:error, _}} = ctx, _map, _x, _y), do: ctx
  def warpchar(%Ctx{} = ctx, map, x, y), do: warp(ctx, map, x, y)

  @spec warpchar(Ctx.t(), String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          Ctx.t()
  def warpchar(%Ctx{status: {:error, _}} = ctx, _map, _x, _y, _char_id), do: ctx

  def warpchar(%Ctx{} = ctx, map, x, y, char_id) do
    if char_id == ctx.char_id do
      warp(ctx, map, x, y)
    else
      case UnitRegistry.get_player_pid(char_id) do
        {:ok, pid} -> PlayerSession.warp(pid, map, x, y)
        {:error, :not_found} -> :ok
      end

      ctx
    end
  end

  defp warp_map_player(char_id, from_map, to_map, x, y, type, id) do
    with {:ok, {_module, game_state, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id),
         true <- mapwarp_selected?(game_state, type, id),
         {:ok, {dest_map, dest_x, dest_y}} <- mapwarp_destination(from_map, to_map, x, y) do
      PlayerSession.warp(pid, dest_map, dest_x, dest_y)
    else
      _ -> :ok
    end
  end

  defp mapwarp_selected?(game_state, 1, id), do: Map.get(game_state, :guild_id) == id
  defp mapwarp_selected?(game_state, 2, id), do: Map.get(game_state, :party_id) == id
  defp mapwarp_selected?(_game_state, _type, _id), do: true

  defp mapwarp_destination(from_map, "Random", _x, _y), do: random_destination(from_map)
  defp mapwarp_destination(_from_map, to_map, 0, 0), do: random_destination(to_map)
  defp mapwarp_destination(_from_map, to_map, x, y), do: {:ok, {to_map, x, y}}

  defp random_destination(map) do
    case Cell.random_traversable(map) do
      {:ok, {x, y}} -> {:ok, {map, x, y}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp warp_players_in_area(from_map, x1, y1, x2, y2, destination) do
    from_map
    |> SpatialIndex.get_players_in_area(x1, y1, x2, y2)
    |> Enum.each(fn char_id ->
      case UnitRegistry.get_player_pid(char_id) do
        {:ok, pid} ->
          {map, x, y} = destination.(char_id)
          PlayerSession.warp(pid, map, x, y)

        {:error, :not_found} ->
          :ok
      end
    end)
  end
end
