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
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @doc """
  Builds the `SkillList` for `progression`'s job tree.

  Entries whose skill is absent from `Catalog` are skipped (the tree loader
  already filters these, so this is belt-and-suspenders).
  """
  @spec build(PlayerProgression.t() | PlayerState.t()) :: SkillList.t()
  def build(%PlayerState{stats: %{progression: progression} = stats, plagiarized: plagiarized}) do
    %SkillList{skills: tree_skills} = build(progression)
    job_id = progression.job_id
    granted = granted_skills(stats)

    tree_skills = Enum.map(tree_skills, &bump_granted(&1, granted, job_id))

    appended =
      granted
      |> Enum.reject(fn {id, _level} -> Enum.any?(tree_skills, &(&1.skill_id == id)) end)
      |> Enum.flat_map(fn {id, level} -> standalone_skill_info(id, level, job_id) end)

    %SkillList{skills: tree_skills ++ appended ++ plagiarized_skill(plagiarized, job_id)}
  end

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

  # Reads the equipment-granted skills off the stats, tolerating the bare-map
  # `stats` shape used by fixtures (which lack the field) as no grants.
  defp granted_skills(stats), do: Map.get(stats, :granted_skills) || %{}

  # Overrides a tree entry with the equipment-granted level when the grant is
  # higher than what the player has learned, so the list matches the level the
  # cast authority (`Caster.Player.knows?`) will allow.
  defp bump_granted(%SkillInfo{skill_id: id, level: level} = info, granted, job_id) do
    case Map.get(granted, id, 0) do
      granted_level when granted_level > level ->
        case standalone_skill_info(id, granted_level, job_id) do
          [bumped] -> bumped
          [] -> info
        end

      _ ->
        info
    end
  end

  defp plagiarized_skill(nil, _job_id), do: []

  defp plagiarized_skill(%{skill_id: skill_id, level: level}, job_id),
    do: standalone_skill_info(skill_id, level, job_id)

  # A skill list entry for a skill not sourced from the job tree (a copied or
  # equipment-granted skill): no prerequisites or level minimums, not upgradable.
  @spec standalone_skill_info(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          [SkillInfo.t()]
  defp standalone_skill_info(skill_id, level, job_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} ->
        [
          to_skill_info(
            %{
              skill_id: skill_id,
              owner_job_id: job_id,
              level: level,
              max_level: definition.max_level,
              requires: [],
              base_level: 0,
              job_level: 0,
              upgradable: false
            },
            definition
          )
        ]

      :error ->
        []
    end
  end

  @spec to_skill_info(SkillTree.view_entry(), Definition.t()) :: SkillInfo.t()
  defp to_skill_info(view_entry, %Definition{} = definition) do
    %SkillInfo{
      skill_id: view_entry.skill_id,
      job_id: view_entry.owner_job_id,
      type: inf_for(definition.target_type),
      level: view_entry.level,
      sp: sp_for(definition.sp_cost, view_entry.level),
      range: Definition.range_at_level(definition, view_entry.level),
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
