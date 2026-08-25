defmodule Aesir.ZoneServer.Mmo.JobManagement.Importer do
  @moduledoc """
  Merges rAthena's selected-mode job databases into our own-schema job maps.

  rAthena splits job data across four same-schema (`JOB_STATS`) files that merge
  by job name, each grouping many jobs under one entry:

    * `job_stats.yml`       - `MaxWeight`, `BonusStats`
    * `job_basepoints.yml`  - `BaseHp` / `BaseSp` / `BaseAp` per level
    * `job_aspd.yml`        - `BaseASPD` per weapon
    * `job_exp.yml`         - `BaseExp` groups (carry `MaxBaseLevel`) and
                              `JobExp` groups (carry `MaxJobLevel`)

  rAthena builds with `HP_SP_TABLES` enabled, so the explicit base-point tables
  win where present; any level the table leaves at `0` is filled with the
  `calc_basehp/sp/ap` formula (`pc.cpp`), driven by `HpFactor`/`HpIncrease` and
  friends. The 4th jobs ship no HP/SP table at all, so they are entirely
  formula-driven. We pre-resolve this here, baking complete dense tables (from
  level 1 to `MaxBaseLevel`) so the runtime stays a plain level lookup.

  The renewal formula also adds class-family bonuses for the formula-driven jobs:
  Summoner (Spirit_Handler) +50% HP/SP, Super Novice (Hyper_Novice) +2000 HP at
  base 99/150, and Ninja/Gunslinger (Shinkiro/Shiranui/Night_Watch) SP tweaks.

  Source job spellings resolve through the closed `AvailableJobs` vocabulary and
  fragments merge by numeric job ID. A job is emitted only when base points,
  ASPD, base EXP, and job EXP are all present; stats remain optional.
  Used only by the one-time `mix aesir.import.jobs` task; not on any runtime path.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs

  @weapons %{
    "Fist" => "fist",
    "Dagger" => "dagger",
    "1hSword" => "one_handed_sword",
    "2hSword" => "two_handed_sword",
    "1hSpear" => "one_handed_spear",
    "2hSpear" => "two_handed_spear",
    "1hAxe" => "one_handed_axe",
    "2hAxe" => "two_handed_axe",
    "Mace" => "mace",
    "2hMace" => "two_handed_mace",
    "Staff" => "staff",
    "2hStaff" => "two_handed_staff",
    "Bow" => "bow",
    "Knuckle" => "knuckle",
    "Musical" => "musical",
    "Whip" => "whip",
    "Book" => "book",
    "Katar" => "katar",
    "Revolver" => "revolver",
    "Rifle" => "rifle",
    "Gatling" => "gatling",
    "Shotgun" => "shotgun",
    "Grenade" => "grenade",
    "Huuma" => "huuma",
    "Shield" => "shield"
  }

  # Expanded/special classes that don't belong to a basic/2nd/trans/3rd/4th tier.
  @special_ids MapSet.new([
                 23,
                 24,
                 25,
                 4046,
                 4047,
                 4048,
                 4049,
                 4050,
                 4051,
                 4052,
                 4190,
                 4211,
                 4212,
                 4215,
                 4218,
                 4239,
                 4240,
                 4243
               ])

  @type bodies :: %{stats: [map()], basepoints: [map()], aspd: [map()], exp: [map()]}

  @doc """
  Builds the full list of own-schema job maps from the four parsed rAthena bodies.

  Raises with a descriptive message on any unmapped job/weapon or missing data -
  this is a dev tool meant to fail loud.
  """
  @spec build(bodies()) :: [map()]
  def build(%{stats: stats, basepoints: basepoints, aspd: aspd, exp: exp}) do
    stats_by = expand(stats)
    points_by = expand(basepoints)
    aspd_by = expand(aspd)
    base_exp_by = exp |> Enum.filter(&Map.has_key?(&1, "BaseExp")) |> expand()
    job_exp_by = exp |> Enum.filter(&Map.has_key?(&1, "JobExp")) |> expand()

    points_by
    |> Map.keys()
    |> intersection(Map.keys(aspd_by))
    |> intersection(Map.keys(base_exp_by))
    |> intersection(Map.keys(job_exp_by))
    |> Enum.sort()
    |> Enum.map(&to_map(&1, stats_by, points_by, aspd_by, base_exp_by, job_exp_by))
  end

  @doc """
  Returns the tier file basename (without extension) a job map belongs to.
  """
  @spec tier(map()) :: String.t()
  def tier(%{"id" => id, "name" => name}) do
    cond do
      String.contains?(name, "baby") -> "baby"
      MapSet.member?(@special_ids, id) -> "special"
      id in 0..6 -> "basic"
      id in 7..21 -> "2nd"
      id in 4001..4022 -> "trans"
      id in 4054..4087 -> "3rd"
      id >= 4252 -> "4th"
      true -> "special"
    end
  end

  # A job may appear in several groups within one file (e.g. job_basepoints lists
  # all BaseHp groups, then all BaseSp, then all BaseAp), so payloads are merged.
  @spec expand([map()]) :: %{non_neg_integer() => map()}
  defp expand(groups) do
    Enum.reduce(groups, %{}, fn group, acc ->
      {jobs, payload} = Map.pop!(group, "Jobs")

      Enum.reduce(Map.keys(jobs), acc, fn source_name, expanded ->
        {job_id, _name} = canonical_job!(source_name)
        Map.update(expanded, job_id, payload, &Map.merge(&1, payload))
      end)
    end)
  end

  @spec intersection([non_neg_integer()], [non_neg_integer()]) :: [non_neg_integer()]
  defp intersection(left, right) do
    right = MapSet.new(right)
    Enum.filter(left, &MapSet.member?(right, &1))
  end

  @spec to_map(non_neg_integer(), map(), map(), map(), map(), map()) :: map()
  defp to_map(job_id, stats_by, points_by, aspd_by, base_exp_by, job_exp_by) do
    {:ok, name} = AvailableJobs.job_id_to_name(job_id)
    stats = Map.get(stats_by, job_id, %{})
    points = Map.fetch!(points_by, job_id)
    aspd = Map.fetch!(aspd_by, job_id)
    base_exp = Map.fetch!(base_exp_by, job_id)
    job_exp = Map.fetch!(job_exp_by, job_id)

    max_base_level = Map.fetch!(base_exp, "MaxBaseLevel")
    factors = factors(stats)
    family = family(name)

    %{
      "id" => job_id,
      "name" => Atom.to_string(name),
      "max_weight" => Map.get(stats, "MaxWeight", 20_000),
      "max_base_level" => max_base_level,
      "max_job_level" => Map.fetch!(job_exp, "MaxJobLevel"),
      "base_hp" =>
        base_points(points["BaseHp"], "Hp", max_base_level, &calc_hp(&1, factors, family)),
      "base_sp" =>
        base_points(points["BaseSp"], "Sp", max_base_level, &calc_sp(&1, factors, family)),
      "base_ap" => base_points(points["BaseAp"], "Ap", max_base_level, &calc_ap(&1, factors)),
      "base_exp" => levels(base_exp["BaseExp"], "Exp"),
      "job_exp" => levels(job_exp["JobExp"], "Exp"),
      "bonus_stats" => bonus(stats["BonusStats"]),
      "base_aspd" => aspd_map(aspd["BaseASPD"])
    }
    |> prune()
  end

  # Drops empty/all-zero tables so the loader falls back to struct defaults.
  @spec prune(map()) :: map()
  defp prune(map) do
    Map.reject(map, fn {_k, v} ->
      v in [[], %{}] or (is_list(v) and Enum.all?(v, &(&1 == 0)))
    end)
  end

  @spec factors(map()) :: map()
  defp factors(stats) do
    %{
      hp_factor: Map.get(stats, "HpFactor", 0),
      hp_increase: Map.get(stats, "HpIncrease", 500),
      sp_factor: Map.get(stats, "SpFactor", 0),
      sp_increase: Map.get(stats, "SpIncrease", 100),
      ap_factor: Map.get(stats, "ApFactor", 0),
      ap_increase: Map.get(stats, "ApIncrease", 0)
    }
  end

  # Only the formula-driven 4th jobs need a family; their lower-tier relatives
  # carry explicit tables, so the formula (and its bonus) never runs for them.
  @spec family(atom()) :: :summoner | :super_novice | :ninja | :gunslinger | :none
  defp family(:spirit_handler), do: :summoner
  defp family(:hyper_novice), do: :super_novice
  defp family(name) when name in [:shinkiro, :shiranui], do: :ninja
  defp family(:night_watch), do: :gunslinger
  defp family(_name), do: :none

  # Builds a dense level-1..max list: the table value, or the formula where 0.
  @spec base_points([map()] | nil, String.t(), pos_integer(), (pos_integer() -> non_neg_integer())) ::
          [non_neg_integer()]
  defp base_points(entries, key, max_level, calc) do
    table = if entries, do: Map.new(entries, &{&1["Level"], &1[key]}), else: %{}

    Enum.map(1..max_level, fn level ->
      case Map.get(table, level, 0) do
        0 -> calc.(level)
        value -> value
      end
    end)
  end

  # rAthena calc_basehp (renewal): the pre-re Ninja/Gunslinger HP block is skipped.
  @spec calc_hp(pos_integer(), map(), atom()) :: non_neg_integer()
  defp calc_hp(level, f, family) do
    base = 35.0 + Float.floor(level * (f.hp_increase / 100)) + factor_sum(level, f.hp_factor)

    base =
      case family do
        :summoner -> base + Float.floor(base / 2 + 0.5)
        :super_novice -> base + super_novice_bonus(level)
        _ -> base
      end

    trunc(base)
  end

  # rAthena calc_basesp.
  @spec calc_sp(pos_integer(), map(), atom()) :: non_neg_integer()
  defp calc_sp(level, f, family) do
    base = 10.0 + Float.floor(level * (f.sp_increase / 100)) + factor_sum(level, f.sp_factor)

    base =
      case family do
        :ninja -> if level >= 10, do: base - 22, else: 11.0 + 3 * level
        :gunslinger -> if level >= 10, do: base - 18, else: 9.0 + 3 * level
        :summoner -> base + Float.floor(base / 2 + 0.5)
        _ -> base
      end

    trunc(base)
  end

  # rAthena calc_baseap.
  @spec calc_ap(pos_integer(), map()) :: non_neg_integer()
  defp calc_ap(level, f) do
    base = if level >= 200, do: 200.0, else: 0.0
    trunc(base + Float.floor(level * (f.ap_increase / 100)) + factor_sum(level, f.ap_factor))
  end

  @spec factor_sum(pos_integer(), non_neg_integer()) :: float()
  defp factor_sum(level, _factor) when level < 2, do: 0.0

  defp factor_sum(level, factor) do
    Enum.reduce(2..level, 0.0, fn i, acc -> acc + Float.floor(factor / 100 * i + 0.5) end)
  end

  @spec super_novice_bonus(pos_integer()) :: non_neg_integer()
  defp super_novice_bonus(level) do
    if(level >= 99, do: 2000, else: 0) + if(level >= 150, do: 2000, else: 0)
  end

  @spec canonical_job!(String.t()) :: {non_neg_integer(), atom()}
  defp canonical_job!(source_name) do
    case AvailableJobs.canonical_source_job(source_name) do
      {:ok, job} ->
        job

      {:error, :unknown_source_job} ->
        raise "no job id for source job #{inspect(source_name)} - add it to AvailableJobs"
    end
  end

  @spec levels([map()] | nil, String.t()) :: [non_neg_integer()]
  defp levels(nil, _key), do: []

  defp levels(entries, key) do
    by_level = Map.new(entries, &{&1["Level"], &1[key]})
    max = by_level |> Map.keys() |> Enum.max()
    Enum.map(1..max, &Map.get(by_level, &1, 0))
  end

  @spec bonus([map()] | nil) :: [map()]
  defp bonus(nil), do: []

  defp bonus(entries) do
    Enum.map(entries, fn entry ->
      Map.new(entry, fn {k, v} -> {String.downcase(k), v} end)
    end)
  end

  @spec aspd_map(map() | nil) :: map()
  defp aspd_map(nil), do: %{}

  defp aspd_map(weapons) do
    Map.new(weapons, fn {weapon, value} ->
      case Map.fetch(@weapons, weapon) do
        {:ok, mapped} -> {mapped, value}
        :error -> raise "unknown weapon type #{inspect(weapon)} in job_aspd"
      end
    end)
  end
end
