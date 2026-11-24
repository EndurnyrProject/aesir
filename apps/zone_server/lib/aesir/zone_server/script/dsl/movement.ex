defmodule Aesir.ZoneServer.Script.Dsl.Movement do
  @moduledoc """
  Player-relocation buildins for the script DSL: single-player warps (explicit
  cell, random cell, save point), rectangle and whole-map warps, and
  by-character-id warps, and the unit warp (`unitwarp`).

  Imported into scripts via the `Aesir.ZoneServer.Script.Dsl` facade.
  """

  alias Aesir.ZoneServer.Constants.DespawnReason
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl.Internal
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Relocates the player.

  - `{map, x, y}` — to an explicit cell.
  - `:random` — to a random walkable cell on the current map (fly wing).
  - `:save_point` — to the player's save point (butterfly wing).

  A resolution or warp error (unknown map, no walkable cell) fails the command
  and the script goes on. Halts `:no_player` on a detached ctx (there is no
  player to relocate).
  """
  @spec warp(Ctx.t(), {String.t(), non_neg_integer(), non_neg_integer()} | :random | :save_point) ::
          Ctx.t()
  def warp(%Ctx{} = ctx, {map, x, y}), do: warp(ctx, map, x, y)

  def warp(%Ctx{status: {:error, _}} = ctx, :random), do: ctx
  def warp(%Ctx{game_state: nil} = ctx, :random), do: Ctx.halt(ctx, :no_player)

  def warp(%Ctx{game_state: game_state} = ctx, :random) do
    case Cell.random_traversable(game_state.map_name) do
      {:ok, {x, y}} -> warp(ctx, game_state.map_name, x, y)
      {:error, reason} -> Ctx.fail(ctx, :warp, reason)
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
  # already runs inline on the session and warps its `session_state` directly.
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

  @doc """
  Warps a unit to `(x, y)` on `map` (rAthena `unitwarp`) and returns the
  reference's raw `unit_warp` result, where `0` is success.

  `unit_id` `0` is the script's own unit: the monster an `OnTouchNPC` run is
  attached to (`Ctx.attached_unit`), else the attached player. Any other id
  names a monster instance, else an online player by account id. A unit that
  is not found, or a `map` that is not loaded (`"this"` is the unit's own map),
  fails the command and returns `0`, as the reference pushes 0.

  The result is `1` for a dead monster, a monster that is not a slave on a
  `monster_noteleport` map, a player on a `noteleport` map, and a monster warp
  to another map (not supported yet); `2` when no destination cell is found: a
  negative coordinate picks a random cell of the map
  (`Cell.random_traversable_inland/1`), an unwalkable one a cell within 4 of
  it (`Cell.random_traversable_near/3`). An attached player whose warp is
  refused returns `1` (`pc_setpos`); another player's warp is cast to their
  session and returns `0`.
  """
  @spec unitwarp(Ctx.t(), integer(), String.t(), integer(), integer()) :: {Ctx.t(), integer()}
  def unitwarp(%Ctx{status: {:error, _}} = ctx, _unit_id, _map, _x, _y), do: {ctx, 0}

  def unitwarp(%Ctx{} = ctx, unit_id, map, x, y) do
    with {:ok, unit} <- warp_unit(ctx, unit_id),
         {:ok, dest} <- warp_map(unit, map) do
      unit_warp(ctx, unit, dest, x, y)
    else
      {:error, reason} -> {Ctx.fail(ctx, :unitwarp, reason), 0}
    end
  end

  defp warp_unit(%Ctx{attached_unit: {:mob, id}}, 0), do: warp_mob(id)
  defp warp_unit(%Ctx{game_state: %PlayerState{} = gs}, 0), do: {:ok, {:attached, gs}}
  defp warp_unit(%Ctx{}, 0), do: {:error, :unit_not_found}

  defp warp_unit(%Ctx{} = ctx, id) do
    with {:error, :unit_not_found} <- warp_mob(id) do
      warp_player(ctx, id)
    end
  end

  defp warp_mob(id) do
    case UnitRegistry.get_unit(:mob, id) do
      {:ok, {_module, %MobState{} = mob, pid}} when is_pid(pid) -> {:ok, {:mob, mob, pid}}
      _missing -> {:error, :unit_not_found}
    end
  end

  defp warp_player(%Ctx{account_id: account_id, game_state: %PlayerState{} = gs}, account_id),
    do: {:ok, {:attached, gs}}

  defp warp_player(_ctx, account_id) do
    with {:ok, char_id} <- UnitRegistry.get_char_id_by_account(account_id),
         {:ok, {_module, %PlayerState{} = gs, pid}} when is_pid(pid) <-
           UnitRegistry.get_unit(:player, char_id) do
      {:ok, {:player, gs, pid}}
    else
      _missing -> {:error, :unit_not_found}
    end
  end

  defp warp_map(unit, "this"), do: {:ok, unit_state(unit).map_name}

  defp warp_map(_unit, map) do
    map = String.replace_suffix(map, ".gat", "")

    case MapCache.get(map) do
      {:ok, _map_data} -> {:ok, map}
      _missing -> {:error, :unknown_map}
    end
  end

  defp unit_state({:attached, gs}), do: gs
  defp unit_state({_kind, state, _pid}), do: state

  defp unit_warp(ctx, {:mob, mob, pid}, dest, x, y) do
    cond do
      not Unit.living?(mob) ->
        {ctx, 1}

      MapFlags.get(mob.map_name, :monster_noteleport) and mob.master_id in [nil, 0] ->
        {ctx, 1}

      dest != mob.map_name ->
        {Ctx.fail(ctx, :unitwarp, :cross_map_mob_warp_unsupported), 1}

      true ->
        with_cell(ctx, dest, x, y, fn wx, wy ->
          MobSession.warp(pid, dest, wx, wy, DespawnReason.out_of_sight())
          {ctx, 0}
        end)
    end
  end

  defp unit_warp(ctx, unit, dest, x, y) do
    if MapFlags.get(unit_state(unit).map_name, :noteleport),
      do: {ctx, 1},
      else: with_cell(ctx, dest, x, y, &warp_player_unit(ctx, unit, dest, &1, &2))
  end

  defp warp_player_unit(ctx, {:attached, _gs}, dest, x, y) do
    warped = Internal.apply_op(ctx, {:warp, dest, x, y})
    if warped.failures == ctx.failures, do: {warped, 0}, else: {warped, 1}
  end

  defp warp_player_unit(ctx, {:player, _gs, pid}, dest, x, y) do
    PlayerSession.warp(pid, dest, x, y)
    {ctx, 0}
  end

  defp with_cell(ctx, dest, x, y, warp) do
    case warp_cell(dest, x, y) do
      {:ok, {wx, wy}} -> warp.(wx, wy)
      :error -> {ctx, 2}
    end
  end

  defp warp_cell(dest, x, y) when x < 0 or y < 0, do: Cell.random_traversable_inland(dest)

  defp warp_cell(dest, x, y) do
    if Cell.traversable?(dest, x, y), do: {:ok, {x, y}}, else: near_cell(dest, {x, y})
  end

  defp near_cell(dest, center) do
    case Cell.random_traversable_near(dest, center, 4) do
      ^center -> :error
      near -> {:ok, near}
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
