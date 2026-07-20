defmodule Aesir.ZoneServer.Unit.Player.SkillListView do
  @moduledoc """
  Builds the enriched `SkillList` sent to the client: the player's full available
  skill tree (every learnable entry, level-0 included) rather than only learned
  skills.

  `SkillTree.available_for/1` produces the annotated tree (current level, cap,
  prerequisites, level minimums, `upgradable?`); this view resolves each entry's
  castable `Definition` from `Skill.Catalog` for the display fields (`type`,
  `range`, `name`, cast `sp`) and packs the lot into `Aesir.Net.SkillInfo`.
  """

  alias Aesir.Net.SkillInfo
  alias Aesir.Net.SkillList
  alias Aesir.Net.SkillRequirement
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @doc """
  Builds the `SkillList` for `progression`'s job tree.

  Entries whose skill is absent from `Catalog` are skipped (the tree loader
  already filters these, so this is belt-and-suspenders).
  """
  @spec build(PlayerProgression.t()) :: SkillList.t()
  def build(%PlayerProgression{} = progression) do
    skills =
      progression
      |> SkillTree.available_for()
      |> Enum.flat_map(fn view_entry ->
        case Catalog.by_id(view_entry.skill_id) do
          {:ok, definition} -> [to_skill_info(view_entry, definition)]
          :error -> []
        end
      end)

    %SkillList{skills: skills}
  end

  @spec to_skill_info(SkillTree.view_entry(), Definition.t()) :: SkillInfo.t()
  defp to_skill_info(view_entry, %Definition{} = definition) do
    %SkillInfo{
      skill_id: view_entry.skill_id,
      job_id: view_entry.owner_job_id,
      type: inf_for(definition.target_type),
      level: view_entry.level,
      sp: sp_for(definition.sp_cost, view_entry.level),
      range: definition.range,
      name: definition.name |> Atom.to_string() |> String.upcase(),
      upgradable: view_entry.upgradable,
      max_level: view_entry.max_level,
      requires: Enum.map(view_entry.requires, &to_requirement/1),
      req_base_level: view_entry.base_level,
      req_job_level: view_entry.job_level,
      splash_radius: definition.splash_radius
    }
  end

  @spec to_requirement({non_neg_integer(), pos_integer()}) :: SkillRequirement.t()
  defp to_requirement({skill_id, level}) do
    %SkillRequirement{skill_id: skill_id, level: level}
  end

  # An unlearned skill (level 0) has no cast cost; only learned levels index the
  # sp_cost list. Avoids the `Enum.at(list, -1)` wrap that returns the last
  # element for level 0.
  @spec sp_for([non_neg_integer()], non_neg_integer()) :: non_neg_integer()
  defp sp_for(_sp_cost, 0), do: 0
  defp sp_for(sp_cost, level), do: Enum.at(sp_cost, level - 1, 0)

  @spec inf_for(Definition.target_type()) :: non_neg_integer()
  defp inf_for(:passive), do: 0
  defp inf_for(:target_enemy), do: 1
  defp inf_for(:ground), do: 2
  defp inf_for(:self), do: 4
  defp inf_for(:target_ally), do: 16
  defp inf_for(:target_any), do: 16
  defp inf_for(:target_resurrection), do: 16
end
