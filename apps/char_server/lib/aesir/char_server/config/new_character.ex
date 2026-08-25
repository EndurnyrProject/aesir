defmodule Aesir.CharServer.Config.NewCharacter do
  @moduledoc """
  Accessors for the new-character starting state (`config :char_server,
  :new_character`). Each location value uses the resolved configuration when
  present, otherwise the active game mode's default location.
  """

  alias Aesir.Commons.GameMode

  @start_locations %{
    renewal: {"iz_int", 18, 26},
    pre_renewal: {"new_1-1", 53, 111}
  }

  @doc "Configured starting map name, or the active mode's default map."
  @spec start_map() :: String.t()
  def start_map, do: configured_or_default(:start_map, 0)

  @doc "Configured starting X cell, or the active mode's default X cell."
  @spec start_x() :: non_neg_integer()
  def start_x, do: configured_or_default(:start_x, 1)

  @doc "Configured starting Y cell, or the active mode's default Y cell."
  @spec start_y() :: non_neg_integer()
  def start_y, do: configured_or_default(:start_y, 2)

  @doc "Zeny a freshly created character starts with."
  @spec start_zeny() :: non_neg_integer()
  def start_zeny, do: Keyword.fetch!(application_env(), :start_zeny)

  defp configured_or_default(key, position) do
    case Keyword.get(application_env(), key) do
      nil -> elem(default_start_location(), position)
      value -> value
    end
  end

  defp default_start_location, do: Map.fetch!(@start_locations, GameMode.mode())
  defp application_env, do: Application.fetch_env!(:char_server, :new_character)
end
