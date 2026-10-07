defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBowlingbash.Chain do
  @moduledoc """
  Pre-renewal Bowling Bash: the target rolls like a bowling ball and knocks
  over the enemies it reaches.

  The hit itself carries no knockback. Instead the target rolls one cell at a
  time, up to `(level - depth + 1) div 2` cells, along the caster's facing
  (the primary target, depth 0) or in a random direction (a chained enemy). A
  wall stops it. After each cell it looks for enemies in the 3x3 area around
  that cell, clipped to the lane: the 40x40 square of the map grid holding the
  caster's cell less the roll length (the gutter lines). If it finds any (it
  counts itself), each of them is bowled in turn one depth deeper, the target
  takes a collision hit when it is still inside the lane, and it stops
  rolling. Finally it takes its own hit. Every enemy is bowled at most once per
  cast, and a chained enemy outside the lane is not bowled at all.

  Each hit is an ordinary physical skill attack with its own hit roll. The
  primary target's hits are never re-checked at delivery; every other hit is
  a splash hit.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @lane_size 40
  @directions 8
  # A unit rolls at most five cells, so a radius this wide still finds every
  # unit whose spatial index entry lags behind a push requested this cast.
  @candidate_radius 6

  @typedoc "A zero-based uniform draw below the given bound."
  @type rng :: (pos_integer() -> non_neg_integer())

  @doc """
  Bowls `primary` for `caster` at `level` and returns `:ok`.

  `attack` strikes one unit (`fn ref -> ... end`); `rng` draws a chained enemy's
  direction.
  """
  @spec run(struct(), Ref.t(), pos_integer(), (Ref.t() -> term()), rng()) :: :ok
  def run(caster, primary, level, attack, rng \\ &default_rng/1) do
    combatant = caster.__struct__.to_combatant(caster)

    with {:ok, map_data} <- MapCache.get(combatant.map_name) do
      ctx = %{
        caster: combatant,
        facing: Geometry.facing_delta(caster.dir),
        origin: combatant.position,
        map: map_data,
        level: level,
        attack: attack,
        rng: rng
      }

      _ = bowl(ctx, primary, 0, %{visited: MapSet.new(), moved: %{}})
    end

    :ok
  end

  defp bowl(ctx, ref, depth, state) do
    rolls = div(ctx.level - depth + 1, 2)
    lane = lane(ctx.origin, rolls)

    case position(ref, state) do
      {:ok, cell} ->
        if depth > 0 and (not inside?(lane, cell) or MapSet.member?(state.visited, ref)) do
          state
        else
          state = %{state | visited: MapSet.put(state.visited, ref)}
          state = roll(ctx, ref, cell, direction(ctx, depth), {rolls, lane, depth}, state)
          ctx.attack.(ref)
          state
        end

      :error ->
        state
    end
  end

  defp direction(ctx, 0), do: ctx.facing
  defp direction(ctx, _depth), do: Geometry.facing_delta(ctx.rng.(@directions))

  defp roll(_ctx, _ref, _cell, _delta, {0, _lane, _depth}, state), do: state

  defp roll(ctx, ref, start, delta, {rolls, lane, depth}, state) do
    1..rolls
    |> Enum.reduce_while({start, state}, fn _step, {cell, state} ->
      roll_step(ctx, ref, step(cell, delta), delta, {lane, depth}, state)
    end)
    |> elem(1)
  end

  # The next cell moves on even when the push itself fails; a wall stops it.
  defp roll_step(ctx, ref, next, delta, lane_depth, state) do
    if wall?(ctx.map, next) do
      {:halt, {next, state}}
    else
      state = push(ctx, ref, delta, state)

      case collide(ctx, ref, next, lane_depth, state) do
        {:stop, state} -> {:halt, {next, state}}
        :continue -> {:cont, {next, state}}
      end
    end
  end

  defp step({x, y}, {dx, dy}), do: {x + dx, y + dy}

  defp collide(ctx, ref, {tx, ty}, {lane, depth}, state) do
    with {:ok, area} <- clip(lane, {tx - 1, ty - 1, tx + 1, ty + 1}),
         [_ | _] = enemies <- enemies_in(ctx, area, {tx, ty}, state) do
      state = Enum.reduce(enemies, state, &bowl(ctx, &1, depth + 1, &2))

      with {:ok, cell} <- position(ref, state),
           true <- inside?(lane, cell),
           do: ctx.attack.(ref)

      {:stop, state}
    else
      _no_collision -> :continue
    end
  end

  # A boss caster's push moves even a Basilica caster.
  defp push(ctx, {unit_type, unit_id} = ref, {dx, dy}, state) do
    with {:ok, {x, y}} <- position(ref, state),
         opts = [position: {x, y}, source_boss?: ctx.caster.class == :boss],
         {:ok, landing} <- Knockback.knockback(unit_type, unit_id, x - dx, y - dy, 1, opts) do
      %{state | moved: Map.put(state.moved, ref, landing)}
    else
      _unmoved -> state
    end
  end

  defp enemies_in(ctx, area, center, state) do
    ctx.caster.map_name
    |> Combat.splash_targets(center, @candidate_radius, ctx.caster)
    |> Enum.flat_map(&in_area(&1, area, state))
    |> Enum.sort()
    |> Enum.map(&elem(&1, 1))
  end

  defp in_area(ref, area, state) do
    with {:ok, {x, y} = cell} <- position(ref, state),
         true <- inside?(area, cell) do
      [{{y, x}, ref}]
    else
      _outside -> []
    end
  end

  defp position(ref, %{moved: moved}) do
    case Map.fetch(moved, ref) do
      {:ok, cell} ->
        {:ok, cell}

      :error ->
        case SpatialIndex.get_unit_position(elem(ref, 0), elem(ref, 1)) do
          {:ok, {x, y, _map}} -> {:ok, {x, y}}
          _missing -> :error
        end
    end
  end

  # The lane is the 40x40 grid square holding the caster's cell shifted back
  # by the roll length, as the source computes it with C remainders.
  defp lane({x, y}, rolls) do
    min_x = lane_start(x - rolls)
    min_y = lane_start(y - rolls)
    {min_x, min_y, min_x + @lane_size - 1, min_y + @lane_size - 1}
  end

  defp lane_start(value), do: max(value - rem(value, @lane_size), 0)

  defp clip({min_x, min_y, max_x, max_y}, {x0, y0, x1, y1}) do
    area = {max(min_x, x0), max(min_y, y0), min(max_x, x1), min(max_y, y1)}

    if elem(area, 0) <= elem(area, 2) and elem(area, 1) <= elem(area, 3),
      do: {:ok, area},
      else: :error
  end

  defp inside?({min_x, min_y, max_x, max_y}, {x, y}),
    do: x >= min_x and x <= max_x and y >= min_y and y <= max_y

  defp wall?(map_data, {x, y}), do: MapData.check_cell(map_data, x, y, :chk_wall)

  defp default_rng(bound), do: :rand.uniform(bound) - 1
end
