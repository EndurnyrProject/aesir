defmodule Aesir.ZoneServer.Gm.Commands.Rentitem do
  @moduledoc """
  `@rentitem <item_id> <seconds> [char_name | char_id]` - gives a time-limited
  rental item to an online player (self by default).
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @usage "Usage: @rentitem <item_id> <seconds> [target]"

  @impl true
  @spec name() :: String.t()
  def name, do: "rentitem"

  @impl true
  @spec required_level() :: non_neg_integer()
  def required_level, do: 60

  @impl true
  @spec execute([String.t()], Aesir.ZoneServer.Gm.Command.ctx()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute(args, ctx) do
    with {:ok, item_id, seconds, target_arg} <- parse(args),
         {:ok, item_def} <- resolve_item(item_id),
         {:ok, pid, target_name} <- resolve_target(target_arg, ctx) do
      case PlayerSession.script_apply(pid, {:give_item_rental, item_id, seconds, []}) do
        {:ok, _game_state} -> {:ok, "Rented #{seconds}s #{item_def.name} to #{target_name}"}
        {:error, reason} -> {:error, error_message(reason)}
      end
    end
  end

  defp parse([id, seconds | rest]) do
    with {item_id, ""} <- Integer.parse(id),
         {seconds, ""} when seconds > 0 <- Integer.parse(seconds) do
      {:ok, item_id, seconds, List.first(rest)}
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

  defp error_message(:not_rentable), do: "Item is not rentable"
  defp error_message(:inventory_full), do: "Inventory full"
  defp error_message(:bad_duration), do: "Invalid duration"
end
