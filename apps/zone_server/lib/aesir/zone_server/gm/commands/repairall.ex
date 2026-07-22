defmodule Aesir.ZoneServer.Gm.Commands.RepairAll do
  @moduledoc """
  `@repairall [char_name | char_id]` - repairs every broken item for an online
  player (self by default) at no cost. Delivery is `PlayerSession.repair_all/1`
  on the target's session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def name, do: "repairall"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(args, ctx) do
    with {:ok, pid, target_name} <- resolve_target(List.first(args), ctx) do
      PlayerSession.repair_all(pid)
      {:ok, "Repaired all broken items for #{target_name}"}
    end
  end

  defp resolve_target(nil, ctx), do: {:ok, self(), ctx.game_state.character_name}

  defp resolve_target(target_arg, _ctx) do
    case Integer.parse(target_arg) do
      {char_id, ""} -> resolve_by_id(char_id)
      _ -> resolve_by_name(target_arg)
    end
  end

  defp resolve_by_id(char_id) do
    with {:ok, pid} <- UnitRegistry.get_player_pid(char_id),
         {:ok, name} <- UnitRegistry.get_player_name(char_id) do
      {:ok, pid, name}
    else
      _ -> {:error, "Player not online"}
    end
  end

  defp resolve_by_name(name) do
    target = String.downcase(name)

    UnitRegistry.list_players()
    |> Enum.find(&name_matches?(&1, target))
    |> case do
      nil -> {:error, "Player not online"}
      char_id -> resolve_by_id(char_id)
    end
  end

  defp name_matches?(char_id, target) do
    case UnitRegistry.get_player_name(char_id) do
      {:ok, name} -> String.downcase(name) == target
      _ -> false
    end
  end
end
