defmodule Aesir.ZoneServer.Gm.Dispatcher do
  @moduledoc """
  Parses a `@`-prefixed GM command, looks up the command module, gates on the
  caller's account `gm_level`, executes it, and sends the result back to the GM
  as a private `ChatMessage`.
  """

  alias Aesir.Commons.Auth
  alias Aesir.Net.ChatMessage
  alias Aesir.ZoneServer.Network.MessageRouter

  # Registered commands keyed by their lowercase token.
  @commands %{
    "item" => Aesir.ZoneServer.Gm.Commands.Item,
    "warp" => Aesir.ZoneServer.Gm.Commands.Warp,
    "job" => Aesir.ZoneServer.Gm.Commands.Job,
    "baselevelup" => Aesir.ZoneServer.Gm.Commands.BaseLevel,
    "joblevelup" => Aesir.ZoneServer.Gm.Commands.JobLevel,
    "resetskill" => Aesir.ZoneServer.Gm.Commands.ResetSkill,
    "broadcast" => Aesir.ZoneServer.Gm.Commands.Broadcast
  }

  @spec dispatch(String.t(), Aesir.ZoneServer.Gm.Command.ctx()) :: :ok
  def dispatch(rest, ctx, commands \\ @commands) do
    {token, args} =
      rest
      |> String.trim_leading("@")
      |> String.split()
      |> case do
        [token | args] -> {String.downcase(token), args}
        [] -> {"", []}
      end

    with {:ok, module} <- lookup(commands, token),
         :ok <- authorize(module, ctx) do
      reply(ctx, run(module, args, ctx))
    else
      {:error, reason} -> reply(ctx, reason)
    end
  end

  defp lookup(commands, token) do
    case Map.fetch(commands, token) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, "Unknown command"}
    end
  end

  defp authorize(module, ctx) do
    account = Auth.get_account!(ctx.game_state.account_id)

    if account.gm_level >= module.required_level() do
      :ok
    else
      {:error, "Insufficient permission"}
    end
  end

  defp run(module, args, ctx) do
    case module.execute(args, ctx) do
      {:ok, msg} -> msg
      {:error, msg} -> msg
    end
  end

  defp reply(ctx, message) do
    packet = %ChatMessage{gid: ctx.game_state.character_id, message: message}
    MessageRouter.send_to(ctx.connection_pid, packet)
  end
end
