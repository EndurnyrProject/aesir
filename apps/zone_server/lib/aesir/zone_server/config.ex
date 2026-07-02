defmodule Aesir.ZoneServer.Config do
  @moduledoc """
  Accessors for zone-server runtime configuration (`config :zone_server, ...`).

  Centralizes tunables that were previously duplicated as per-module constants so
  there is a single source of truth in `config/zone_server/main.exs`.
  """

  @default_view_range 20
  @default_max_party 12
  @default_party_share_level 15
  @default_party_even_share_bonus 0

  @doc """
  Player view range (rAthena `AREA_SIZE`): the cell radius a client is told about.

  Used for entity visibility, combat/skill/effect broadcasts, and the radius
  within which a client may acquire an attack or skill target.
  """
  @spec view_range() :: pos_integer()
  def view_range, do: Application.get_env(:zone_server, :view_range, @default_view_range)

  @doc """
  Maximum number of characters in a party (rAthena `MAX_PARTY`).
  """
  @spec max_party() :: pos_integer()
  def max_party, do: Application.get_env(:zone_server, :max_party, @default_max_party)

  @doc """
  Maximum online-member base-level spread allowed while even-share EXP is
  enabled (rAthena `inter_athena.conf party_share_level`).
  """
  @spec party_share_level() :: pos_integer()
  def party_share_level,
    do: Application.get_env(:zone_server, :party_share_level, @default_party_share_level)

  @doc """
  Percentage bonus applied to pooled EXP per extra party member beyond the
  first when even-share is enabled (rAthena `party.conf party_even_share_bonus`).
  """
  @spec party_even_share_bonus() :: non_neg_integer()
  def party_even_share_bonus,
    do:
      Application.get_env(:zone_server, :party_even_share_bonus, @default_party_even_share_bonus)
end
