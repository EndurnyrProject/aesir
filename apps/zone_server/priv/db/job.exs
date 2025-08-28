# Load job data from separate files
{aspd_data, _} = Code.eval_file("re/job_aspd.exs", __DIR__)
{basepoints_data, _} = Code.eval_file("re/job_basepoints.exs", __DIR__)
{exp_data, _} = Code.eval_file("re/job_exp.exs", __DIR__)
{stats_data, _} = Code.eval_file("re/job_stats.exs", __DIR__)

# Helper function to build quick-lookup indices for O(1) lookups
build_index = fn data ->
  Enum.reduce(data, %{}, fn entry, acc ->
    Enum.reduce(Map.get(entry, :jobs, []), acc, fn job, acc2 ->
      existing = Map.get(acc2, job, %{})
      merged = Map.merge(existing, entry)
      Map.put(acc2, job, merged)
    end)
  end)
end

# Helper functions to conditionally add properties to map if source exists
maybe_put = fn map, key, entry, source_key ->
  if entry && Map.has_key?(entry, source_key) do
    Map.put(map, key, Map.get(entry, source_key))
  else
    map
  end
end

maybe_put_with_default = fn map, key, entry, source_key, default ->
  if entry && Map.has_key?(entry, source_key) do
    Map.put(map, key, Map.get(entry, source_key, default))
  else
    map
  end
end

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

aspd_index = build_index.(aspd_data)
basepoints_index = build_index.(basepoints_data)
exp_index = build_index.(exp_data)
stats_index = build_index.(stats_data)

merged_jobs =
  Enum.map(all_jobs, fn job ->
    aspd_entry = Map.get(aspd_index, job)
    basepoints_entry = Map.get(basepoints_index, job)
    exp_entry = Map.get(exp_index, job)
    stats_entry = Map.get(stats_index, job)

    %{job: job}
    |> maybe_put.(:base_aspd, aspd_entry, :base_aspd)
    |> maybe_put_with_default.(:base_hp, basepoints_entry, :base_hp, [])
    |> maybe_put_with_default.(:base_sp, basepoints_entry, :base_sp, [])
    |> maybe_put_with_default.(:base_ap, basepoints_entry, :base_ap, [])
    |> maybe_put_with_default.(:base_exp, exp_entry, :base_exp, [])
    |> maybe_put_with_default.(:job_exp, exp_entry, :job_exp, [])
    |> maybe_put.(:max_weight, stats_entry, :max_weight)
    |> maybe_put.(:hp_factor, stats_entry, :hp_factor)
    |> maybe_put.(:hp_increase, stats_entry, :hp_increase)
    |> maybe_put.(:sp_increase, stats_entry, :sp_increase)
    |> maybe_put_with_default.(:bonus_stats, stats_entry, :bonus_stats, [])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end)

merged_jobs
