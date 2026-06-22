defmodule Aesir.ZoneServer.Gm.Command do
  @moduledoc """
  Behaviour for GM (`@`-prefixed) chat commands.

  Each command is an isolated module implementing this behaviour and registered
  in the `Dispatcher` registry. The dispatcher handles parsing, permission
  gating and feedback; a command only validates its args and performs its effect.
  """

  @type ctx :: %{
          game_state: Aesir.ZoneServer.Unit.Player.PlayerState.t(),
          connection_pid: pid()
        }

  @callback name() :: String.t()
  @callback required_level() :: non_neg_integer()
  @callback execute(args :: [String.t()], ctx()) :: {:ok, String.t()} | {:error, String.t()}
end
