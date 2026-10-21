defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Caster do
  @moduledoc """
  Reads the performer values the classic song and dance formulas scale with:
  a fully modified primary stat and the performer's lesson level.

  Bare player fixtures carry plain maps instead of the stats structs; those
  fall back to the allocated points and a lesson level of zero.
  """

  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  @doc "The performer's fully modified primary stat."
  @spec stat(map(), atom()) :: integer()
  def stat(%{stats: %Stats{modifiers: %Modifiers{}} = stats}, stat_name),
    do: Stats.get_effective_stat(stats, stat_name)

  def stat(%{stats: %{base_stats: base_stats}}, stat_name) when is_map(base_stats),
    do: Map.get(base_stats, stat_name, 0)

  def stat(_caster, _stat_name), do: 0

  @doc "The performer's level (learned or granted) of the given lesson skill."
  @spec lesson_level(map(), integer()) :: non_neg_integer()
  def lesson_level(%{stats: stats}, skill_id) when is_map(stats),
    do: Stats.skill_level(stats, skill_id)

  def lesson_level(_caster, _skill_id), do: 0
end
