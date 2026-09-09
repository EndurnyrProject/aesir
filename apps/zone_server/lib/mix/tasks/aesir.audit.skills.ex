defmodule Mix.Tasks.Aesir.Audit.Skills do
  @shortdoc "Audits a job's implemented skills against the source skill database"
  @moduledoc """
  Compares one job's Aesir skill definitions against the source skill
  database for the same mode, and prints a markdown report.

      mix aesir.audit.skills [<rathena_root>] [--mode re|pre-re] --job <job>

  `<rathena_root>` defaults to `../rathena`. `--mode` defaults to `re`.
  `--job` is required and is the job's Aesir name (for example `swordman`).

  ## Strict fields

  Compared per level up to the source skill's max level: `max_level`,
  `range`, `hit_count`, `element`, `splash_radius`, `knockback`, `cast_time`,
  `fixed_cast_time` (renewal only), `after_cast_delay`, `cooldown`,
  `sp_cost`, `hp_cost`, `hp_cost_rate`, `zeny_cost`, `sphere_cost`,
  `item_cost`, `requires_ammo`, `require_weapon`. A skill present in the
  job's tree but absent from the source database is a strict finding for a
  renewal run (`missing in source`); for a pre-renewal run it is only
  informational (`renewal-only`), since renewal-only content is expected to
  be absent from the pre-renewal database.

  ## Informational fields

  Printed for context only, never compared: `Duration1`, `Duration2`,
  `Type`, `TargetType`, `Flags`, `Unit`.

  ## Exit status

  Exits with status `1` when any strict finding exists (a field mismatch, an
  unresolved item cost name, or a skill missing from a renewal source);
  `0` otherwise. Running the task for both modes produces two independent
  suggestion blocks per skill; merging a field into a single mode-keyed
  option across both runs is done by hand.
  """
  use Mix.Task

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Audit
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Mix.Tasks.Aesir.Import

  @typedoc "One tree skill's audit outcome. `notes` are informational, never strict."
  @type result ::
          {:ok, atom(), Definition.t(), [Audit.finding()], [String.t()]}
          | {:missing, atom()}
          | {:renewal_only, atom()}

  @impl Mix.Task
  def run(args) do
    {rathena, mode, job} = parse_args!(args)

    Application.put_env(:commons, :game_mode, mode)

    source_rows = read_source_rows!(rathena, mode)
    job_id = job_id!(job)
    results = audit_job(job_id, source_rows, mode)

    Mix.shell().info(render_report(job, mode, results))

    if strict_findings?(results) do
      exit({:shutdown, 1})
    end
  end

  @doc false
  @spec parse_args!([String.t()]) :: {Path.t(), GameMode.t(), atom()}
  def parse_args!(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: [mode: :string, job: :string])

    unless invalid == [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    job_arg = Keyword.get(opts, :job) || Mix.raise("--job is required")
    {rathena, mode} = Import.parse!(rest ++ mode_args(opts))

    {rathena, mode, job_atom!(job_arg)}
  end

  @spec mode_args(keyword()) :: [String.t()]
  defp mode_args(opts) do
    case Keyword.fetch(opts, :mode) do
      {:ok, mode} -> ["--mode", mode]
      :error -> []
    end
  end

  @spec job_atom!(String.t()) :: atom()
  defp job_atom!(job_arg) do
    # AvailableJobs' job-name atoms only enter the atom table once the module
    # loads; force that before looking the argument up as an existing atom,
    # then confirm it actually names a job rather than some unrelated atom.
    Code.ensure_loaded!(AvailableJobs)
    job = String.to_existing_atom(job_arg)

    case AvailableJobs.job_name_to_id(job) do
      {:ok, _job_id} -> job
      {:error, :unknown_job} -> Mix.raise("unknown job #{inspect(job_arg)}")
    end
  rescue
    ArgumentError -> Mix.raise("unknown job #{inspect(job_arg)}")
  end

  @spec job_id!(atom()) :: non_neg_integer()
  defp job_id!(job) do
    {:ok, job_id} = AvailableJobs.job_name_to_id(job)
    job_id
  end

  @spec read_source_rows!(Path.t(), GameMode.t()) :: %{String.t() => map()}
  defp read_source_rows!(rathena, mode) do
    rathena
    |> Path.join("db/skill_db.yml")
    |> Import.read_mode_filtered!(mode)
    |> Map.new(fn row -> {row |> Map.fetch!("Name") |> String.upcase(), row} end)
  end

  @spec audit_job(non_neg_integer(), %{String.t() => map()}, GameMode.t()) :: [result()]
  defp audit_job(job_id, source_rows, mode) do
    job_id
    |> SkillTree.tree_for()
    |> Map.keys()
    |> Enum.sort()
    |> Enum.map(&audit_skill(&1, source_rows, mode))
  end

  @spec audit_skill(non_neg_integer(), %{String.t() => map()}, GameMode.t()) :: result()
  defp audit_skill(skill_id, source_rows, mode) do
    {:ok, definition} = Catalog.by_id(skill_id)
    key = definition.name |> Atom.to_string() |> String.upcase()

    case {Map.fetch(source_rows, key), mode} do
      {{:ok, row}, _mode} ->
        findings = Audit.compare(definition, row, mode)
        display = display_definition(definition, findings, mode)
        {:ok, definition.name, display, findings, notes(row)}

      {:error, :pre_renewal} ->
        {:renewal_only, definition.name}

      {:error, :renewal} ->
        {:missing, definition.name}
    end
  end

  @spec notes(map()) :: [String.t()]
  defp notes(row) do
    case Audit.negative_hit_count_levels(row, Map.fetch!(row, "MaxLevel")) do
      [] -> []
      negatives -> ["negative source HitCount values: #{inspect(negatives)}"]
    end
  end

  @spec display_definition(Definition.t(), [Audit.finding()], GameMode.t()) :: Definition.t()
  defp display_definition(definition, findings, mode) do
    case Catalog.module_for(definition.name) do
      :error ->
        definition

      {:ok, module} ->
        findings
        |> Enum.uniq_by(& &1.field)
        |> Enum.reduce(definition, &keyed_field(&1, &2, module, mode))
    end
  end

  @spec keyed_field(Audit.finding(), Definition.t(), module(), GameMode.t()) :: Definition.t()
  defp keyed_field(%{field: field}, definition, module, mode) do
    other = Audit.other_mode(mode)
    current = Map.get(definition, field)
    other_value = module.definition(other) |> Map.get(field)

    if other_value == current do
      definition
    else
      Map.put(definition, field, Keyword.new([{mode, current}, {other, other_value}]))
    end
  end

  @spec strict_findings?([result()]) :: boolean()
  defp strict_findings?(results) do
    Enum.any?(results, fn
      {:ok, _name, _definition, findings, _notes} -> findings != []
      {:missing, _name} -> true
      {:renewal_only, _name} -> false
    end)
  end

  @doc false
  @spec render_report(atom(), GameMode.t(), [result()]) :: String.t()
  def render_report(job, mode, results) do
    [
      "# Skill audit: #{job} (#{mode})",
      render_table(results),
      render_informational(results),
      render_suggestions(results, mode)
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @spec render_table([result()]) :: String.t()
  defp render_table(results) do
    rows = Enum.flat_map(results, &table_rows/1)

    if rows == [] do
      "No strict mismatches."
    else
      Enum.join(["| Skill | Field | Aesir | rAthena |", "| --- | --- | --- | --- |" | rows], "\n")
    end
  end

  @spec table_rows(result()) :: [String.t()]
  defp table_rows({:ok, name, _definition, findings, _notes}) do
    Enum.map(findings, fn %{field: field, aesir: aesir, source: source} ->
      "| #{name} | #{field} | #{inspect(aesir)} | #{inspect(source)} |"
    end)
  end

  defp table_rows({:missing, name}), do: ["| #{name} | - | - | missing in source |"]
  defp table_rows({:renewal_only, _name}), do: []

  @spec render_informational([result()]) :: String.t()
  defp render_informational(results) do
    results
    |> Enum.flat_map(&informational_lines/1)
    |> Enum.join("\n")
  end

  @spec informational_lines(result()) :: [String.t()]
  defp informational_lines({:renewal_only, name}) do
    ["- `#{name}`: renewal-only, not present in this mode's source"]
  end

  defp informational_lines({:ok, name, _definition, _findings, notes}) do
    Enum.map(notes, &"- `#{name}`: #{&1}")
  end

  defp informational_lines({:missing, _name}), do: []

  @spec render_suggestions([result()], GameMode.t()) :: String.t()
  defp render_suggestions(results, mode) do
    results
    |> Enum.flat_map(&suggestion_block(&1, mode))
    |> Enum.join("\n\n")
  end

  @spec suggestion_block(result(), GameMode.t()) :: [String.t()]
  defp suggestion_block({:ok, _name, _definition, [], _notes}, _mode), do: []

  defp suggestion_block({:ok, name, definition, findings, _notes}, mode) do
    ["## #{name}\n\n" <> Audit.suggest(definition, findings, mode)]
  end

  defp suggestion_block(_result, _mode), do: []
end
