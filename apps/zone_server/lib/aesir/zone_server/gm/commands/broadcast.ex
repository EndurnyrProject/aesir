defmodule Aesir.ZoneServer.Gm.Commands.Broadcast do
  @moduledoc """
  `@broadcast [<scope>] [<color>] <message text...>` - sends a styled
  announcement to the client(s) selected by `<scope>` (default `all`), in the
  given `<color>` (default `yellow`), attributed to the configured server name.

  `<scope>` is one of `all` (global), `map` (the caller's current map), or
  `self` (only the caller). `<color>` is one of `yellow`, `blue`, or `woe`.
  Both flags are optional and, when present, must lead the argument list in
  that order; everything else is joined back into the message text.
  """
  @behaviour Aesir.ZoneServer.Gm.Command

  import Bitwise

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags

  @usage "Usage: @broadcast [all|map|self] [yellow|blue|woe] <message>"

  @scope_flags %{"all" => "bc_all", "map" => "bc_map", "self" => "bc_self"}
  @color_flags %{"yellow" => "bc_yellow", "blue" => "bc_blue", "woe" => "bc_woe"}

  @impl true
  @spec name() :: String.t()
  def name, do: "broadcast"

  @impl true
  @spec required_level() :: non_neg_integer()
  def required_level, do: Application.get_env(:zone_server, :broadcast_gm_level, 60)

  @impl true
  @spec execute([String.t()], Aesir.ZoneServer.Gm.Command.ctx()) ::
          {:ok, String.t()} | {:error, String.t()}
  def execute(args, ctx) do
    with {:ok, scope, color, message} <- parse(args) do
      deliver(scope, color, message, ctx)
      {:ok, "Broadcast sent."}
    end
  end

  defp parse(args) do
    {scope, rest} = take_flag(args, @scope_flags, "all")
    {color, rest} = take_flag(rest, @color_flags, "yellow")
    message = Enum.join(rest, " ")

    if message == "" do
      {:error, @usage}
    else
      {:ok, scope, color, message}
    end
  end

  defp take_flag([token | rest] = args, flags, default) do
    case Map.fetch(flags, String.downcase(token)) do
      {:ok, _bc_name} -> {String.downcase(token), rest}
      :error -> {default, args}
    end
  end

  defp take_flag([], _flags, default), do: {default, []}

  defp deliver(scope, color, message, ctx) do
    {:ok, scope_flag} = Map.fetch(@scope_flags, scope)
    {:ok, scope_val} = Flags.value(scope_flag)
    {:ok, color_flag} = Map.fetch(@color_flags, color)
    {:ok, color_val} = Flags.value(color_flag)

    decoded = Flags.decode(scope_val ||| color_val, 0)

    opts = %{
      text: message,
      color: decoded.color,
      style: Flags.style_for(decoded.scope),
      source_name: source_name()
    }

    dispatch(decoded.scope, opts, ctx)
  end

  defp dispatch(:all, opts, _ctx), do: Announcement.to_all(opts)
  defp dispatch(:map, opts, ctx), do: Announcement.to_map(ctx.game_state.map_name, opts)
  defp dispatch(:self, opts, ctx), do: Announcement.to_self(ctx.game_state.character_id, opts)

  defp source_name, do: Application.get_env(:zone_server, :broadcast_source_name, "Server")
end
