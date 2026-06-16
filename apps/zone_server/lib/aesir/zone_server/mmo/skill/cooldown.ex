defmodule Aesir.ZoneServer.Mmo.Skill.Cooldown do
  @moduledoc """
  Stateless per-skill cooldown logic.

  Cooldowns are kept as a `skill_id => expires_at` map where `expires_at` is a
  `System.monotonic_time(:millisecond)` timestamp. There is no process and no
  time read inside this module - the caller passes `now`, following the engine's
  lazy timestamp-comparison model.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @typedoc "Per-skill cooldown map: `skill_id => expires_at` (monotonic ms)."
  @type cooldowns :: %{integer() => integer()}

  @doc """
  Returns `true` when the skill has no active cooldown - either no entry exists
  or `now` has reached the recorded `expires_at`.
  """
  @spec ready?(cooldowns(), integer(), integer()) :: boolean()
  def ready?(cooldowns, skill_id, now) do
    case Map.fetch(cooldowns, skill_id) do
      :error -> true
      {:ok, expires_at} -> now >= expires_at
    end
  end

  @doc "Records `expires_at` for `skill_id`."
  @spec put(cooldowns(), integer(), integer()) :: cooldowns()
  def put(cooldowns, skill_id, expires_at), do: Map.put(cooldowns, skill_id, expires_at)

  @doc """
  Cooldown duration in ms for the given skill level. Returns `0` when the
  definition's `cooldown` list has no entry for the level (empty or too short),
  meaning the skill has no cooldown.
  """
  @spec duration(Definition.t(), pos_integer()) :: non_neg_integer()
  def duration(%Definition{cooldown: cooldown}, level), do: Enum.at(cooldown, level - 1) || 0
end
