defmodule Aesir.ZoneServer.Mmo.Skill.Grant do
  @moduledoc """
  Permanent skill grants for NPC scripts (rAthena's "platinum skill" style
  `skill <id>,<level>,SKILL_PERM` - a permanent grant outside the normal skill
  tree, never spending or refunding a skill point).

  Resolves a catalog skill, validates its level and quest-grant metadata, and
  computes the idempotent learned-level increase - `max(existing, requested)`,
  never a decrease. Level `0` is the one exception: it removes the skill, the
  way a script strips a platinum skill before a job change. Pure over the
  learned map; the session-owned persistence and client sync live in
  `Aesir.ZoneServer.Unit.Player.Handlers.SkillLearningHandler.grant_skill/3`.

  Only skills flagged `quest_skill: true` (with a resolvable `quest_owner_job`,
  enforced by `Definition.build!/2`) are grantable, so this seam cannot be used
  to bypass `SkillTree.learn/2` for an ordinary tree skill.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Learned

  @type reason :: :unknown_skill | :invalid_level | :not_grantable

  @doc """
  Resolves `skill_id_or_name`, validates `level` against it, and returns
  `learned_skills` with `max(existing, level)` stored at the resolved skill id.
  A `level` of `0` removes the skill instead (a no-op when it is not learned).

  Returns `{:error, reason}` without touching `learned_skills` when:

    * the skill does not resolve in `Catalog` (`:unknown_skill`);
    * `level` falls outside `0..max_level` (`:invalid_level`);
    * the definition is not quest-grantable - `quest_skill: false`, or
      (defensively) a quest skill somehow built without `quest_owner_job`
      (`:not_grantable`).
  """
  @spec grant(Learned.t(), integer() | atom(), integer()) ::
          {:ok, Learned.t()} | {:error, reason()}
  def grant(learned_skills, skill_id_or_name, level) do
    with {:ok, definition} <- resolve(skill_id_or_name),
         :ok <- validate(definition, level) do
      {:ok, apply_level(learned_skills, definition.id, level)}
    end
  end

  defp apply_level(learned_skills, skill_id, 0), do: Map.delete(learned_skills, skill_id)

  defp apply_level(learned_skills, skill_id, level),
    do: Map.update(learned_skills, skill_id, level, &max(&1, level))

  @spec resolve(integer() | atom()) :: {:ok, Definition.t()} | {:error, :unknown_skill}
  defp resolve(skill_id) when is_integer(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp resolve(name) when is_atom(name) do
    case Catalog.by_name(name) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  @spec validate(Definition.t(), integer()) :: :ok | {:error, reason()}
  defp validate(%Definition{quest_skill: false}, _level), do: {:error, :not_grantable}
  defp validate(%Definition{quest_owner_job: nil}, _level), do: {:error, :not_grantable}

  defp validate(%Definition{max_level: max_level}, level) when level < 0 or level > max_level,
    do: {:error, :invalid_level}

  defp validate(%Definition{}, _level), do: :ok
end
