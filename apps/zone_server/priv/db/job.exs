{aspd_data, _} = Code.eval_file("re/job_aspd.exs", __DIR__)
{basepoints_data, _} = Code.eval_file("re/job_basepoints.exs", __DIR__)
{exp_data, _} = Code.eval_file("re/job_exp.exs", __DIR__)
{stats_data, _} = Code.eval_file("re/job_stats.exs", __DIR__)

# Extract all unique job atoms from all files
all_jobs =
  [aspd_data, basepoints_data, exp_data, stats_data]
  |> Enum.flat_map(fn data_list ->
    Enum.flat_map(data_list, fn entry ->
      Map.get(entry, :jobs, [])
    end)
  end)
  |> Enum.uniq()
  |> Enum.sort()

# Build merged job data
merged_jobs =
  Enum.map(all_jobs, fn job ->
    # Find ASPD data for this job
    aspd_entry =
      Enum.find(aspd_data, fn entry ->
        job in Map.get(entry, :jobs, [])
      end)

    # Find basepoints data for this job
    basepoints_entry =
      Enum.find(basepoints_data, fn entry ->
        job in Map.get(entry, :jobs, [])
      end)

    # Find exp data for this job
    exp_entry =
      Enum.find(exp_data, fn entry ->
        job in Map.get(entry, :jobs, [])
      end)

    # Find stats data for this job
    stats_entry =
      Enum.find(stats_data, fn entry ->
        job in Map.get(entry, :jobs, [])
      end)

    # Build the merged entry for this job
    job_data = %{
      job: job
    }

    # Add ASPD data if present
    job_data =
      if aspd_entry do
        Map.put(job_data, :base_aspd, Map.get(aspd_entry, :base_aspd))
      else
        job_data
      end

    # Add basepoints data if present
    job_data =
      if basepoints_entry do
        job_data
        |> Map.put(:base_hp, Map.get(basepoints_entry, :base_hp, []))
        |> Map.put(:base_sp, Map.get(basepoints_entry, :base_sp, []))
      else
        job_data
      end

    # Add exp data if present
    job_data =
      if exp_entry do
        job_data
        |> Map.put(:base_exp, Map.get(exp_entry, :base_exp, []))
        |> Map.put(:job_exp, Map.get(exp_entry, :job_exp, []))
      else
        job_data
      end

    # Add stats data if present
    job_data =
      if stats_entry do
        job_data
        |> Map.put(:max_weight, Map.get(stats_entry, :max_weight))
        |> Map.put(:hp_factor, Map.get(stats_entry, :hp_factor))
        |> Map.put(:hp_increase, Map.get(stats_entry, :hp_increase))
        |> Map.put(:sp_increase, Map.get(stats_entry, :sp_increase))
        |> Map.put(:bonus_stats, Map.get(stats_entry, :bonus_stats, []))
      else
        job_data
      end

    # Remove nil values
    job_data
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end)

# Return the merged job data
merged_jobs
