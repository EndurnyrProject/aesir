defmodule Aesir.ZoneServer.Mmo.Skill.Learned do
  @moduledoc """
  Conversion + seeding for the character's learned-skills map.

  In-memory shape is `%{skill_id_integer => level}`; the DB jsonb column stores
  string-keyed JSON, so `from_character/1` and `dump/1` translate at the boundary.
  """

  @type t :: %{integer() => non_neg_integer()}

  @spec from_character(map() | nil) :: t()
  def from_character(nil), do: seed_defaults()
  def from_character(map) when map == %{}, do: seed_defaults()

  def from_character(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_int(k), v} end)
  end

  @spec dump(t()) :: %{String.t() => non_neg_integer()}
  def dump(map), do: Map.new(map, fn {k, v} -> {Integer.to_string(k), v} end)

  @spec learned_level(t(), integer()) :: non_neg_integer()
  def learned_level(map, skill_id), do: Map.get(map, skill_id, 0)

  # ponytail: temporary seed so casting can be tested before the learn/upgrade
  # flow exists; remove when CZ_UPGRADE_SKILLLEVEL lands.
  @spec seed_defaults() :: t()
  defp seed_defaults, do: %{29 => 1}

  defp to_int(k) when is_integer(k), do: k
  defp to_int(k) when is_binary(k), do: String.to_integer(k)
end
