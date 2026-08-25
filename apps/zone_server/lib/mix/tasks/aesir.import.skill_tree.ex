defmodule Mix.Tasks.Aesir.Import.SkillTree do
  @shortdoc "Imports the selected rAthena player skill tree into mode-scoped YAML"
  @moduledoc """
  Imports either mode's player skill tree into the corresponding
  `apps/zone_server/priv/db/<mode>/skill_tree/` directory.

      mix aesir.import.skill_tree [<rathena_root>] [--mode re|pre-re]

  `<rathena_root>` defaults to `../rathena`. Run `mix aesir.import.jobs` for the
  same mode first; the generated job catalog determines which source jobs are
  usable. Unknown or malformed job data fails loudly.

  An explicit invocation owns and replaces the entire selected mode's
  `skill_tree` directory. Generation and validation happen in a same-filesystem
  temporary sibling before the live directory is installed. Existing output is
  moved to a unique same-parent backup first; once installation succeeds, a
  backup-cleanup error is warned about without rolling back the installed data.

  Source `MaxLevel: 0` rows become own-schema `exclude: true` deletion markers.
  Source `Exclude: true` rows become `exclude_inherit: true`: the defining job
  keeps the skill, but descendants do not inherit it.
  """
  use Mix.Task

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Mix.Tasks.Aesir.Import

  @output_file "skill_tree.yml"

  @impl Mix.Task
  def run(args) do
    {rathena, mode} = Import.parse!(args)
    source = Path.join([rathena, "db", "skill_tree.yml"])
    rows = Import.read_mode_filtered!(source, mode)
    ordered_rows = Import.read_mode_filtered_ordered!(source, mode)
    complete_job_ids = complete_job_ids!(mode)

    jobs =
      rows
      |> pair_rows!(ordered_rows, source)
      |> Enum.flat_map(&transform_job(&1, complete_job_ids))

    out_dir = Import.path("skill_tree", mode)
    replace_domain!(out_dir, jobs)
    Mix.shell().info("skill_tree: #{length(jobs)} jobs -> #{Path.join(out_dir, @output_file)}")
  end

  defp pair_rows!(rows, ordered_rows, path) do
    unless length(rows) == length(ordered_rows) do
      Mix.raise("normal and ordered skill-tree row counts differ for #{path}")
    end

    Enum.map(Enum.zip(rows, ordered_rows), fn
      {%{"Job" => source_name} = row, ordered_row} ->
        ordered_source_name = mapping_value!(ordered_row, "Job", path)

        unless source_name == ordered_source_name do
          Mix.raise("normal and ordered skill-tree jobs differ in #{path}")
        end

        {row, inherit_names!(ordered_row, path)}

      {row, _ordered_row} ->
        Mix.raise(
          "expected every skill-tree row in #{path} to contain a Job, got: #{inspect(row)}"
        )
    end)
  end

  defp inherit_names!(ordered_row, path) do
    case List.keyfind(ordered_row, "Inherit", 0) do
      nil ->
        []

      {"Inherit", inherits} when is_list(inherits) ->
        Enum.flat_map(inherits, fn
          {source_name, true} when is_binary(source_name) ->
            [source_name]

          {source_name, false} when is_binary(source_name) ->
            []

          inherit ->
            Mix.raise("expected ordered Inherit entries in #{path}, got: #{inspect(inherit)}")
        end)

      {"Inherit", inherits} ->
        Mix.raise("expected Inherit to be an ordered map in #{path}, got: #{inspect(inherits)}")
    end
  end

  defp transform_job({%{"Job" => source_name} = row, inherit_names}, complete_job_ids) do
    {job_id, job_name} = canonical_job!(source_name)

    if MapSet.member?(complete_job_ids, job_id) do
      job = %{"job" => Atom.to_string(job_name)}
      job = put_optional(job, row, "Inherit", "inherit", &transform_inherit(inherit_names, &1))
      job = put_optional(job, row, "Tree", "tree", &transform_tree/1)
      [job]
    else
      []
    end
  end

  defp transform_inherit(inherit_names, source) when is_map(source) do
    active = source |> Enum.filter(fn {_name, enabled?} -> enabled? == true end) |> Map.new()

    unless MapSet.new(inherit_names) == MapSet.new(Map.keys(active)) do
      Mix.raise("could not preserve skill-tree inheritance order")
    end

    Enum.map(inherit_names, fn source_name ->
      {_job_id, job_name} = canonical_job!(source_name)
      Atom.to_string(job_name)
    end)
  end

  defp transform_inherit(_inherit_names, source) do
    Mix.raise("expected Inherit to be a map, got: #{inspect(source)}")
  end

  defp transform_tree(tree) when is_list(tree), do: Enum.map(tree, &transform_entry/1)
  defp transform_tree(tree), do: Mix.raise("expected Tree to be a list, got: #{inspect(tree)}")

  defp transform_entry(%{"Name" => name, "MaxLevel" => 0}) when is_binary(name) do
    %{"name" => String.upcase(name), "exclude" => true}
  end

  defp transform_entry(%{"Name" => name, "MaxLevel" => max_level} = entry)
       when is_binary(name) and is_integer(max_level) and max_level > 0 do
    %{"name" => String.upcase(name), "max_level" => max_level}
    |> put_optional(entry, "Exclude", "exclude_inherit", & &1)
    |> put_optional(entry, "BaseLevel", "base_level", & &1)
    |> put_optional(entry, "JobLevel", "job_level", & &1)
    |> put_optional(entry, "Requires", "requires", &transform_requires/1)
  end

  defp transform_entry(entry) do
    Mix.raise(
      "expected every skill-tree entry to contain a name and non-negative max level, got: #{inspect(entry)}"
    )
  end

  defp transform_requires(requires) when is_list(requires) do
    Enum.map(requires, fn
      %{"Name" => name, "Level" => level} when is_binary(name) and is_integer(level) ->
        %{"name" => String.upcase(name), "level" => level}

      requirement ->
        Mix.raise(
          "expected every skill prerequisite to contain Name and Level, got: #{inspect(requirement)}"
        )
    end)
  end

  defp transform_requires(requires) do
    Mix.raise("expected Requires to be a list, got: #{inspect(requires)}")
  end

  defp put_optional(target, source, source_key, target_key, transform) do
    case Map.fetch(source, source_key) do
      {:ok, value} -> Map.put(target, target_key, transform.(value))
      :error -> target
    end
  end

  defp canonical_job!(source_name) when is_binary(source_name) do
    case AvailableJobs.canonical_source_job(source_name) do
      {:ok, job} -> job
      {:error, :unknown_source_job} -> Mix.raise("unknown source job #{inspect(source_name)}")
    end
  end

  defp canonical_job!(source_name),
    do: Mix.raise("expected a job name, got: #{inspect(source_name)}")

  defp complete_job_ids!(mode) do
    paths = Path.wildcard(Path.join(Import.path("jobs", mode), "*.yml")) |> Enum.sort()

    if paths == [] do
      Mix.raise(
        "generated #{mode} jobs are missing; run `mix aesir.import.jobs --mode #{mode_arg(mode)}` first"
      )
    end

    paths
    |> Enum.flat_map(&read_jobs!/1)
    |> Enum.reduce(MapSet.new(), &validate_job!/2)
  end

  defp read_jobs!(path) do
    case YamlElixir.read_from_file!(path) do
      jobs when is_list(jobs) ->
        jobs

      malformed ->
        Mix.raise("expected a generated job list in #{path}, got: #{inspect(malformed)}")
    end
  end

  defp validate_job!(%{"id" => id, "name" => name}, ids)
       when is_integer(id) and is_binary(name) do
    case AvailableJobs.job_id_to_name(id) do
      {:ok, canonical_name} ->
        cond do
          Atom.to_string(canonical_name) != name ->
            Mix.raise("malformed generated job #{inspect(%{"id" => id, "name" => name})}")

          MapSet.member?(ids, id) ->
            Mix.raise("duplicate generated job ID #{id}")

          true ->
            MapSet.put(ids, id)
        end

      _unknown ->
        Mix.raise("malformed generated job #{inspect(%{"id" => id, "name" => name})}")
    end
  end

  defp validate_job!(job, _ids), do: Mix.raise("malformed generated job #{inspect(job)}")

  defp mode_arg(:renewal), do: "re"
  defp mode_arg(:pre_renewal), do: "pre-re"

  defp replace_domain!(live_dir, jobs) do
    temp_dir = live_dir <> ".tmp"
    backup_dir = unique_backup_path(live_dir)
    ensure_absent!(temp_dir, "temporary")
    ensure_absent!(backup_dir, "backup")
    File.mkdir_p!(Path.dirname(live_dir))
    File.mkdir!(temp_dir)

    try do
      candidate = Path.join(temp_dir, @output_file)
      File.write!(candidate, Ymlr.Encode.to_s!(jobs) <> "\n")
      validate_candidate!(candidate, jobs)
      install_candidate!(temp_dir, live_dir, backup_dir)
    after
      if path_exists!(temp_dir), do: remove_path!(temp_dir)
    end
  end

  defp validate_candidate!(path, jobs) do
    case YamlElixir.read_from_file(path) do
      {:ok, ^jobs} ->
        :ok

      {:ok, parsed} ->
        Mix.raise("generated skill tree in #{path} did not validate: #{inspect(parsed)}")

      {:error, error} ->
        Mix.raise("failed to validate generated skill tree #{path}: #{Exception.message(error)}")
    end
  end

  defp install_candidate!(temp_dir, live_dir, backup_dir) do
    if path_exists!(live_dir) do
      replace_existing!(temp_dir, live_dir, backup_dir)
    else
      rename!(temp_dir, live_dir, "install generated skill-tree directory")
    end
  end

  defp replace_existing!(temp_dir, live_dir, backup_dir) do
    rename!(live_dir, backup_dir, "move existing skill-tree directory to backup")

    case File.rename(temp_dir, live_dir) do
      :ok ->
        remove_backup_after_commit(backup_dir, live_dir)

      {:error, reason} ->
        case File.rename(backup_dir, live_dir) do
          :ok ->
            Mix.raise(
              "failed to install generated skill-tree directory #{live_dir}: #{inspect(reason)}"
            )

          {:error, rollback_reason} ->
            Mix.raise(
              "failed to install generated skill-tree directory #{live_dir}: #{inspect(reason)}; " <>
                "rollback also failed: #{inspect(rollback_reason)}; original remains at #{backup_dir}"
            )
        end
    end
  end

  defp unique_backup_path(live_dir) do
    suffix = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    live_dir <> ".backup-" <> suffix
  end

  defp remove_backup_after_commit(backup_dir, live_dir) do
    case File.rm_rf(backup_dir) do
      {:ok, _removed} ->
        :ok

      {:error, reason, failed_path} ->
        Mix.shell().error(
          "warning: generated skill-tree output is installed at #{live_dir}, but cleanup " <>
            "failed at #{failed_path}: #{inspect(reason)}; original backup remains at #{backup_dir}"
        )
    end
  end

  defp ensure_absent!(path, label) do
    if path_exists!(path), do: Mix.raise("skill-tree #{label} path already exists: #{path}")
  end

  defp rename!(source, destination, action) do
    case File.rename(source, destination) do
      :ok ->
        :ok

      {:error, reason} ->
        Mix.raise("failed to #{action} #{source} -> #{destination}: #{inspect(reason)}")
    end
  end

  defp remove_path!(path) do
    case File.rm_rf(path) do
      {:ok, _removed} ->
        :ok

      {:error, reason, failed_path} ->
        Mix.raise("failed to remove #{failed_path}: #{inspect(reason)}")
    end
  end

  defp path_exists!(path) do
    case File.lstat(path) do
      {:ok, _stat} -> true
      {:error, :enoent} -> false
      {:error, reason} -> Mix.raise("failed to inspect #{path}: #{inspect(reason)}")
    end
  end

  defp mapping_value!(mapping, key, path) when is_list(mapping) do
    case List.keyfind(mapping, key, 0) do
      {^key, value} -> value
      nil -> Mix.raise("expected #{key} in #{path}")
    end
  end

  defp mapping_value!(_mapping, key, path),
    do: Mix.raise("expected an ordered #{key} map in #{path}")
end
