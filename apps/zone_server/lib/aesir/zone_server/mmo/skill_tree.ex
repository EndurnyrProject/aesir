defmodule Aesir.ZoneServer.Mmo.SkillTree do
  @moduledoc """
  Skill-tree data: per-job learnable skills, their caps, level minimums and
  prerequisites.

  Authored as aegis-named YAML under `priv/db/skill_tree/*.yml` (mirroring
  rAthena's `db/re/skill_tree.yml`, including `inherit`) and loaded the same way
  as `JobManagement.Jobs` / `StatPoint`: built once and cached in
  `:persistent_term`, with `reload/0` to rebuild after a data change.

  Building the index:

    1. Parse every job's YAML block.
    2. Flatten `inherit` chains (`flatten_inherit/1`) - a parent's tree is merged
       into the child, with the child's own entries overriding by name and
       `exclude: true` removing an inherited entry.
    3. Resolve each entry's aegis name to a numeric skill id via `Skill.Catalog`
       and each `job` name to a job id via `AvailableJobs`.
    4. Filter to skills present in `Catalog` (a tree can never gate on a skill
       with no compiled behaviour); a dropped entry is logged as a warning, and a
       prerequisite naming an unimplemented skill is dropped from `requires`.
    5. Index `job_id => %{skill_id => Entry}`.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry

  @pt_key __MODULE__

  @type tree :: %{non_neg_integer() => Entry.t()}
  @type index :: %{non_neg_integer() => tree()}

  @doc """
  Returns the resolved tree for `job_id` as `%{skill_id => Entry}`, or `%{}` when
  the job has no tree.
  """
  @spec tree_for(non_neg_integer()) :: tree()
  def tree_for(job_id), do: Map.get(index(), job_id, %{})

  @doc """
  Returns a single tree `Entry` for `job_id`/`skill_id`, or `:error`.
  """
  @spec entry(non_neg_integer(), non_neg_integer()) :: {:ok, Entry.t()} | :error
  def entry(job_id, skill_id), do: job_id |> tree_for() |> Map.fetch(skill_id)

  @doc """
  Rebuilds the cached index after editing the data files in a running session.
  """
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, build_index(sources()))
    :ok
  end

  @doc """
  Flattens `inherit` chains over raw, name-keyed job data.

  Input is `%{job_name => job}` where `job` is either a bare list of entry maps
  (no inheritance) or `%{inherit: [parent_name], tree: [entry_map]}`. Returns
  `%{job_name => [entry_map]}` with parent entries merged in: a child entry
  overrides an inherited one with the same `"name"`, and an entry flagged
  `"exclude" => true` removes the inherited entry of that name. Pure - no
  process, no resolution against the skill/job registries.
  """
  @spec flatten_inherit(map()) :: %{String.t() => [map()]}
  def flatten_inherit(jobs) do
    Map.new(jobs, fn {name, _job} -> {name, flatten_job(name, jobs)} end)
  end

  @spec flatten_job(String.t(), map()) :: [map()]
  defp flatten_job(name, jobs) do
    case Map.fetch(jobs, name) do
      {:ok, raw} ->
        job = normalize_job(raw)
        inherited = Enum.flat_map(job.inherit, fn parent -> flatten_job(parent, jobs) end)
        merge_tree(inherited, job.tree)

      :error ->
        Logger.warning("[SkillTree] inherited job #{inspect(name)} has no tree, skipping")
        []
    end
  end

  @spec normalize_job(term()) :: %{inherit: [String.t()], tree: [map()]}
  defp normalize_job(job) when is_list(job), do: %{inherit: [], tree: job}

  defp normalize_job(%{tree: tree} = job),
    do: %{inherit: Map.get(job, :inherit, []), tree: tree}

  defp normalize_job(job) when is_map(job) do
    %{inherit: Map.get(job, "inherit", []), tree: Map.get(job, "tree", [])}
  end

  @spec merge_tree([map()], [map()]) :: [map()]
  defp merge_tree(inherited, own) do
    {excluded, kept} = Enum.split_with(own, &(&1["exclude"] == true))
    excluded_names = MapSet.new(excluded, & &1["name"])
    own_names = MapSet.new(kept, & &1["name"])

    surviving =
      Enum.reject(inherited, fn entry ->
        MapSet.member?(excluded_names, entry["name"]) or
          MapSet.member?(own_names, entry["name"])
      end)

    surviving ++ kept
  end

  @spec index() :: index()
  defp index do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = build_index(sources())
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  @spec sources() :: [Path.t()]
  defp sources do
    case data_dir() |> Path.join("*.yml") |> Path.wildcard() do
      [] -> raise "no skill tree data files in #{data_dir()}"
      files -> files
    end
  end

  @spec build_index([Path.t()]) :: index()
  defp build_index(sources) do
    sources
    |> raw_jobs()
    |> flatten_inherit()
    |> Map.new(fn {job_name, entries} -> {job_name, resolve_tree(job_name, entries)} end)
    |> Enum.reduce(%{}, &index_job/2)
  end

  @spec raw_jobs([Path.t()]) :: %{String.t() => map()}
  defp raw_jobs(sources) do
    sources
    |> Enum.flat_map(&DataLoader.parse_file/1)
    |> Map.new(fn job -> {job["job"], job} end)
  end

  @spec index_job({String.t(), tree()}, index()) :: index()
  defp index_job({job_name, tree}, acc) do
    case AvailableJobs.job_name_to_id(String.to_atom(job_name)) do
      {:ok, job_id} ->
        Map.put(acc, job_id, tree)

      {:error, :unknown_job} ->
        Logger.warning("[SkillTree] unknown job #{inspect(job_name)}, skipping its tree")
        acc
    end
  end

  @spec resolve_tree(String.t(), [map()]) :: tree()
  defp resolve_tree(job_name, entries) do
    entries
    |> Enum.flat_map(&resolve_entry(job_name, &1))
    |> Map.new(&{&1.skill_id, &1})
  end

  @spec resolve_entry(String.t(), map()) :: [Entry.t()]
  defp resolve_entry(job_name, entry) do
    case resolve_skill_id(entry["name"]) do
      {:ok, skill_id} ->
        [
          %Entry{
            skill_id: skill_id,
            max_level: entry["max_level"],
            base_level: Map.get(entry, "base_level", 0),
            job_level: Map.get(entry, "job_level", 0),
            requires: resolve_requires(Map.get(entry, "requires", []))
          }
        ]

      :error ->
        Logger.warning(
          "[SkillTree] #{job_name} tree references unimplemented skill " <>
            "#{inspect(entry["name"])}, dropping it"
        )

        []
    end
  end

  @spec resolve_requires([map()]) :: [{non_neg_integer(), pos_integer()}]
  defp resolve_requires(requires) do
    Enum.flat_map(requires, fn req ->
      case resolve_skill_id(req["name"]) do
        {:ok, skill_id} ->
          [{skill_id, req["level"]}]

        :error ->
          Logger.debug(
            "[SkillTree] dropping prerequisite on unimplemented skill #{inspect(req["name"])}"
          )

          []
      end
    end)
  end

  @spec resolve_skill_id(String.t()) :: {:ok, non_neg_integer()} | :error
  defp resolve_skill_id(name), do: Map.fetch(name_to_id(), String.upcase(name))

  @spec name_to_id() :: %{String.t() => non_neg_integer()}
  defp name_to_id do
    Map.new(Catalog.all(), fn definition ->
      {definition.name |> Atom.to_string() |> String.upcase(), definition.id}
    end)
  end

  @spec data_dir() :: Path.t()
  defp data_dir, do: Application.app_dir(:zone_server, "priv/db/skill_tree")
end
