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
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @pt_key __MODULE__

  @type tree :: %{non_neg_integer() => Entry.t()}
  @type index :: %{non_neg_integer() => tree()}

  @typedoc """
  A single tree entry annotated for the client view (see `available_for/1`).

  A plain map (no struct) so the network layer can consume it directly:

    * `:skill_id`       - numeric skill id
    * `:owner_job_id`   - job that originally owns the skill (mage for an
      inherited `MG_FROSTDIVER`, not the viewing job)
    * `:level`          - current learned level (`0` = available, not learned)
    * `:max_level`      - job-specific cap for this skill
    * `:requires`       - prerequisite `[{req_skill_id, req_level}]`
    * `:base_level`     - minimum base level to learn
    * `:job_level`      - minimum job level to learn
    * `:upgradable`     - `true` when `can_learn/2` for this skill returns `:ok`
  """
  @type view_entry :: %{
          skill_id: non_neg_integer(),
          owner_job_id: non_neg_integer(),
          level: non_neg_integer(),
          max_level: pos_integer(),
          requires: [{non_neg_integer(), pos_integer()}],
          base_level: non_neg_integer(),
          job_level: non_neg_integer(),
          upgradable: boolean()
        }

  @type reason ::
          :not_in_tree
          | :no_skill_points
          | :max_level
          | :missing_prerequisite
          | :level_too_low

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
  Authoritative gate for learning/raising a skill by one level.

  Reads the player's job tree from `tree_for/1` and checks, in this order:

    1. the skill is in the job's tree (else `{:error, :not_in_tree}`);
    2. the player has a skill point to spend (else `{:error, :no_skill_points}`);
    3. the current level is below the entry's `max_level` (else `{:error, :max_level}`);
    4. every prerequisite `{req_id, req_lv}` is satisfied (else
       `{:error, :missing_prerequisite}`);
    5. the player meets the base/job level minimums (else `{:error, :level_too_low}`).
  """
  @spec can_learn(PlayerProgression.t(), non_neg_integer()) :: :ok | {:error, reason()}
  def can_learn(%PlayerProgression{job_id: job_id} = progression, skill_id) do
    case entry(job_id, skill_id) do
      {:ok, entry} -> can_learn_entry(progression, entry)
      :error -> {:error, :not_in_tree}
    end
  end

  @doc """
  Same gate as `can_learn/2` but against an already-resolved `Entry`, skipping
  the tree lookup. The skill is assumed to be in the player's tree.
  """
  @spec can_learn_entry(PlayerProgression.t(), Entry.t()) :: :ok | {:error, reason()}
  def can_learn_entry(%PlayerProgression{} = progression, %Entry{} = entry) do
    cond do
      progression.skill_point <= 0 ->
        {:error, :no_skill_points}

      Learned.learned_level(progression.learned_skills, entry.skill_id) >= entry.max_level ->
        {:error, :max_level}

      not requirements_met?(progression.learned_skills, entry.requires) ->
        {:error, :missing_prerequisite}

      progression.base_level < entry.base_level or progression.job_level < entry.job_level ->
        {:error, :level_too_low}

      true ->
        :ok
    end
  end

  @doc """
  Spends one skill point to learn or raise `skill_id` by one level.

  Runs `can_learn/2`; on `:ok` returns the progression with the skill's level
  bumped `+1` and `skill_point` decremented; otherwise returns the
  `{:error, reason}` and leaves the progression untouched.
  """
  @spec learn(PlayerProgression.t(), non_neg_integer()) ::
          {:ok, PlayerProgression.t()} | {:error, reason()}
  def learn(%PlayerProgression{} = progression, skill_id) do
    with :ok <- can_learn(progression, skill_id) do
      level = Learned.learned_level(progression.learned_skills, skill_id)
      learned = Map.put(progression.learned_skills, skill_id, level + 1)
      {:ok, %{progression | learned_skills: learned, skill_point: progression.skill_point - 1}}
    end
  end

  @doc """
  The player's full job tree as a list of `view_entry` maps, each annotated with
  the current level and an `upgradable` flag (`true` iff `can_learn/2` for that
  skill returns `:ok`). Drives the client skill list.
  """
  @spec available_for(PlayerProgression.t()) :: [view_entry()]
  def available_for(%PlayerProgression{job_id: job_id} = progression) do
    job_id
    |> tree_for()
    |> Map.values()
    |> Enum.map(fn entry ->
      %{
        skill_id: entry.skill_id,
        owner_job_id: entry.owner_job_id,
        level: Learned.learned_level(progression.learned_skills, entry.skill_id),
        max_level: entry.max_level,
        requires: entry.requires,
        base_level: entry.base_level,
        job_level: entry.job_level,
        upgradable: can_learn_entry(progression, entry) == :ok
      }
    end)
  end

  @doc """
  Refunds a player's learned skills into `skill_point` (rAthena `resetskill`).

  Sums the levels of every non-exempt learned skill back into `skill_point` and
  reduces `learned_skills` to the exempt set. `NV_BASIC` is exempt (kept, not
  refunded) unless the player is a Novice, in which case it is refunded like any
  other skill. The job id is unchanged.
  """
  @spec reset_skills(PlayerProgression.t()) :: PlayerProgression.t()
  def reset_skills(%PlayerProgression{} = progression) do
    {kept, refundable} = Map.split(progression.learned_skills, exempt_skills(progression))
    refund = refundable |> Map.values() |> Enum.sum()

    %{progression | learned_skills: kept, skill_point: progression.skill_point + refund}
  end

  @spec exempt_skills(PlayerProgression.t()) :: [non_neg_integer()]
  defp exempt_skills(%PlayerProgression{job_id: job_id}) do
    if novice?(job_id) do
      []
    else
      case Catalog.by_name(:nv_basic) do
        {:ok, %{id: id}} -> [id]
        :error -> []
      end
    end
  end

  @spec novice?(non_neg_integer()) :: boolean()
  defp novice?(job_id), do: match?({:ok, :novice}, AvailableJobs.job_id_to_name(job_id))

  @spec requirements_met?(Learned.t(), [{non_neg_integer(), pos_integer()}]) :: boolean()
  defp requirements_met?(learned, requires) do
    Enum.all?(requires, fn {req_id, req_lv} ->
      Learned.learned_level(learned, req_id) >= req_lv
    end)
  end

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
  `"exclude" => true` removes the inherited entry of that name. Each surviving
  entry carries an `"owner_job"` key naming the job it originated from (the parent
  for inherited entries, the job itself for its own). Pure - no process, no
  resolution against the skill/job registries.
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
        own = Enum.map(job.tree, &Map.put(&1, "owner_job", name))
        merge_tree(inherited, own)

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
            owner_job_id: resolve_owner_job_id(job_name, entry),
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

  @spec resolve_owner_job_id(String.t(), map()) :: non_neg_integer()
  defp resolve_owner_job_id(job_name, entry) do
    owner = Map.get(entry, "owner_job", job_name)

    case AvailableJobs.job_name_to_id(String.to_atom(owner)) do
      {:ok, job_id} ->
        job_id

      {:error, :unknown_job} ->
        Logger.warning(
          "[SkillTree] skill #{inspect(entry["name"])} owned by unknown job " <>
            "#{inspect(owner)}, owner_job_id left unresolved as 0"
        )

        0
    end
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
