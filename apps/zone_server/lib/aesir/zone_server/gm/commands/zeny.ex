defmodule Aesir.ZoneServer.Gm.Commands.Zeny do
  @moduledoc """
  `@zeny <amount> [character name]` credits an online character's Zeny, or the
  calling GM's when no name is given. The recipient's session owns the grant.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @usage "Usage: @zeny <amount> [character name]"

  @impl true
  def name, do: "zeny"

  @impl true
  def required_level, do: 60

  @impl true
  def execute([amount_str | name_parts], ctx) do
    with {amount, ""} when amount > 0 <- Integer.parse(amount_str),
         {:ok, pid, name} <- resolve_target(name_parts, ctx) do
      PlayerSession.grant_zeny(pid, amount)
      {:ok, "Gave #{amount} Zeny to #{name}"}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, @usage}
    end
  end

  def execute(_, _ctx), do: {:error, @usage}

  defp resolve_target([], ctx), do: {:ok, self(), ctx.game_state.character_name}

  defp resolve_target(name_parts, _ctx) do
    name = name_parts |> Enum.join(" ") |> String.downcase()

    char_id =
      Enum.find(UnitRegistry.list_players(), fn id ->
        case UnitRegistry.get_player_name(id) do
          {:ok, player_name} -> String.downcase(player_name) == name
          _ -> false
        end
      end)

    with id when not is_nil(id) <- char_id,
         {:ok, pid} <- UnitRegistry.get_player_pid(id),
         {:ok, player_name} <- UnitRegistry.get_player_name(id) do
      {:ok, pid, player_name}
    else
      _ -> {:error, "Player not online"}
    end
  end
end
