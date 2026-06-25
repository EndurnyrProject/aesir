defmodule Aesir.ZoneServer.Config do
  @moduledoc """
  Accessors for zone-server runtime configuration (`config :zone_server, ...`).

  Centralizes tunables that were previously duplicated as per-module constants so
  there is a single source of truth in `config/zone_server/main.exs`.
  """

  @default_view_range 14

  @doc """
  Player view range (rAthena `AREA_SIZE`): the cell radius a client is told about.

  Used for entity visibility, combat/skill/effect broadcasts, and the radius
  within which a client may acquire an attack or skill target.
  """
  @spec view_range() :: pos_integer()
  def view_range, do: Application.get_env(:zone_server, :view_range, @default_view_range)
end
