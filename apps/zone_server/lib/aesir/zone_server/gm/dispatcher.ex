defmodule Aesir.ZoneServer.Gm.Dispatcher do
  @moduledoc """
  Parses a GM command line (a leading `@` is optional), looks up the command
  module, gates on the caller's account `gm_level`, executes it, and sends the
  result back to the GM as a private `ChatNotice`: `INFO` when the command
  succeeded, `ERROR` when it failed, is unknown or is not permitted.
  """

  alias Aesir.Commons.Auth
  alias Aesir.Net.ChatNotice
  alias Aesir.ZoneServer.Network.MessageRouter

  # Registered commands keyed by their lowercase token.
  @commands %{
    "agitend" => Aesir.ZoneServer.Gm.Commands.AgitEnd,
    "agitstart" => Aesir.ZoneServer.Gm.Commands.AgitStart,
    "item" => Aesir.ZoneServer.Gm.Commands.Item,
    "zeny" => Aesir.ZoneServer.Gm.Commands.Zeny,
    "itembound" => Aesir.ZoneServer.Gm.Commands.ItemBound,
    "rentitem" => Aesir.ZoneServer.Gm.Commands.Rentitem,
    "warp" => Aesir.ZoneServer.Gm.Commands.Warp,
    "job" => Aesir.ZoneServer.Gm.Commands.Job,
    "baselevelup" => Aesir.ZoneServer.Gm.Commands.BaseLevel,
    "joblevelup" => Aesir.ZoneServer.Gm.Commands.JobLevel,
    "resetskill" => Aesir.ZoneServer.Gm.Commands.ResetSkill,
    "giveallskills" => Aesir.ZoneServer.Gm.Commands.GiveAllSkills,
    "resetstat" => Aesir.ZoneServer.Gm.Commands.ResetStat,
    "broadcast" => Aesir.ZoneServer.Gm.Commands.Broadcast,
    "repairall" => Aesir.ZoneServer.Gm.Commands.RepairAll,
    "mount" => Aesir.ZoneServer.Gm.Commands.Mount,
    "pvpon" => Aesir.ZoneServer.Gm.Commands.PvpOn,
    "pvpoff" => Aesir.ZoneServer.Gm.Commands.PvpOff,
    "showdelay" => Aesir.ZoneServer.Gm.Commands.ShowDelay
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
      reply(ctx, module.execute(args, ctx))
    else
      {:error, _reason} = error -> reply(ctx, error)
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

  defp reply(ctx, {:ok, text}),
    do: MessageRouter.send_to(ctx.connection_pid, %ChatNotice{kind: :INFO, text: text})

  defp reply(ctx, {:error, text}),
    do: MessageRouter.send_to(ctx.connection_pid, %ChatNotice{kind: :ERROR, text: text})
end
