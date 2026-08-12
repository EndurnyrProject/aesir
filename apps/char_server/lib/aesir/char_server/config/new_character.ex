defmodule Aesir.CharServer.Config.NewCharacter do
  @moduledoc """
  Accessors for the new-character starting state (`config :char_server,
  :new_character`): the spawn map/coordinates and starting zeny applied when a
  character record is first created (rAthena `start_point` / `start_zeny`).
  """

  @doc "Starting map name; seeds both the last position and the save point."
  @spec start_map() :: String.t()
  def start_map, do: Keyword.fetch!(application_env(), :start_map)

  @doc "Starting X cell on `start_map/0`."
  @spec start_x() :: non_neg_integer()
  def start_x, do: Keyword.fetch!(application_env(), :start_x)

  @doc "Starting Y cell on `start_map/0`."
  @spec start_y() :: non_neg_integer()
  def start_y, do: Keyword.fetch!(application_env(), :start_y)

  @doc "Zeny a freshly created character starts with."
  @spec start_zeny() :: non_neg_integer()
  def start_zeny, do: Keyword.fetch!(application_env(), :start_zeny)

  defp application_env, do: Application.fetch_env!(:char_server, :new_character)
end
