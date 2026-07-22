defmodule Aesir.ZoneServer.Gm.Commands.Item do
  @moduledoc """
  `@item <item_id> <amount> [char_name | char_id]` - gives an item to an online
  player (self by default). Delivery is `PlayerSession.give_item/3` on the
  target's session.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @usage "Usage: @item <item_id> <amount> [target]"

  @impl true
  def name, do: "item"

  @impl true
  def required_level, do: 60

  @impl true
  def execute(args, ctx) do
    with {:ok, item_id, amount, target_arg} <- parse(args),
         {:ok, item_def} <- resolve_item(item_id),
         {:ok, pid, target_name} <- resolve_target(target_arg, ctx) do
      PlayerSession.give_item(pid, item_def, amount)
      {:ok, "Gave #{amount}x #{item_def.name} to #{target_name}"}
    end
  end

  defp parse([id, amount | rest]) do
    with {item_id, ""} <- Integer.parse(id),
         {amount, ""} when amount > 0 <- Integer.parse(amount) do
      {:ok, item_id, amount, List.first(rest)}
    else
      _ -> {:error, @usage}
    end
  end

  defp parse(_), do: {:error, @usage}

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
