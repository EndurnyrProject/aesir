defmodule Aesir.ZoneServer.Gm.Commands.ItemBound do
  @moduledoc """
  `@itembound <item_id> <amount> <bound_type> [char_name | char_id]` - gives a
  bound item to an online player (self by default).
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @usage "Usage: @itembound <item_id> <amount> <bound_type> [target]"

  @impl true
  def name, do: "itembound"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(args, ctx) do
    with {:ok, item_id, amount, bound, target_arg} <- parse(args),
         {:ok, item_def} <- resolve_item(item_id),
         {:ok, pid, target_name} <- resolve_target(target_arg, ctx) do
      PlayerSession.give_item(pid, item_def, amount, bound: bound)
      {:ok, "Gave #{amount}x #{item_def.name} to #{target_name}"}
    end
  end

  defp parse([id, amount, bound | rest]) do
    with {item_id, ""} <- Integer.parse(id),
         {amount, ""} when amount > 0 <- Integer.parse(amount),
         {:ok, bound} <- parse_bound(bound) do
      {:ok, item_id, amount, bound, List.first(rest)}
    else
      _ -> {:error, @usage}
    end
  end

  defp parse(_), do: {:error, @usage}

  defp parse_bound("account"), do: {:ok, 1}
  defp parse_bound("1"), do: {:ok, 1}
  defp parse_bound("char"), do: {:ok, 4}
  defp parse_bound("4"), do: {:ok, 4}
  defp parse_bound(_), do: :error

  defp resolve_item(item_id) do
    with {:error, :item_not_found} <- ItemManagement.get_item_by_id(item_id) do
      {:error, "Item not found"}
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
