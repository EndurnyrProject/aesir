defmodule Aesir.ZoneServer.Mmo.Skill.WarpPortalMemo do
  @moduledoc "Records a player's three durable Warp Portal memo points."

  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc "Checks memo eligibility and promotes the current map to the newest slot."
  @spec remember(PlayerState.t(), MapData.t(), map()) ::
          {:ok, PlayerState.t()} | {:error, atom(), PlayerState.t()}
  def remember(%PlayerState{} = player, %MapData{} = map, access) do
    level = Player.skill_level(player, 27)

    cond do
      player.action_state == :dead ->
        {:error, :dead, player}

      (Map.get(access, :nomemo, false) or Map.get(access, :nowarpto, false)) and
          not Map.get(access, :any_warp, false) ->
        {:error, :memo_forbidden, player}

      level < 1 ->
        {:error, :skill_not_learned, player}

      level < 2 ->
        {:error, :insufficient_level, player}

      true ->
        record(player, map)
    end
  end

  defp record(player, map) do
    points = Enum.take(player.memo_points ++ [nil, nil, nil], 3)
    index = Enum.find_index(points, &(&1 != nil and &1["map"] == player.map_name)) || 3
    shifted_count = min(index, 2)

    shifted =
      [hd(points) | Enum.take(points, shifted_count)] ++ Enum.drop(points, shifted_count + 1)

    moved = %{player | memo_points: Enum.reject(shifted, &is_nil/1)}

    if map.instance_id in [nil, 0] do
      point = %{"map" => player.map_name, "x" => player.x, "y" => player.y}
      {:ok, %{player | memo_points: Enum.reject([point | tl(shifted)], &is_nil/1)}}
    else
      {:error, :instance_map, moved}
    end
  end
end
