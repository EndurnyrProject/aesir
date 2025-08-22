defmodule Aesir.ZoneServer.Mmo.JobData do
  @moduledoc """
  Manages job data loaded from the database files.
  Provides functions to query job stats, HP/SP tables, and bonuses.
  """
  require Logger

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  @job_id_mappings %{
    # Basic Jobs
    0 => :novice,
    1 => :swordman,
    2 => :mage,
    3 => :archer,
    4 => :acolyte,
    5 => :merchant,
    6 => :thief,

    # 2-1 Jobs
    7 => :knight,
    8 => :priest,
    9 => :wizard,
    10 => :blacksmith,
    11 => :hunter,
    12 => :assassin,
    # Knight with Peco
    13 => :knight,
    14 => :crusader,
    15 => :monk,
    16 => :sage,
    17 => :rogue,
    18 => :alchemist,
    19 => :bard,
    20 => :dancer,
    # Crusader with Peco
    21 => :crusader,

    # Special
    22 => :wedding,
    23 => :super_novice,
    24 => :gunslinger,
    25 => :ninja,
    26 => :xmas,

    # Transcendent Jobs
    4001 => :novice_high,
    4002 => :swordman_high,
    4003 => :mage_high,
    4004 => :archer_high,
    4005 => :acolyte_high,
    4006 => :merchant_high,
    4007 => :thief_high,

    # Transcendent 2nd Jobs
    4008 => :lord_knight,
    4009 => :high_priest,
    4010 => :high_wizard,
    4011 => :whitesmith,
    4012 => :sniper,
    4013 => :assassin_cross,
    # Lord Knight with Peco
    4014 => :lord_knight,
    4015 => :paladin,
    4016 => :champion,
    4017 => :professor,
    4018 => :stalker,
    4019 => :creator,
    4020 => :clown,
    4021 => :gypsy,
    # Paladin with Peco
    4022 => :paladin,

    # Baby Jobs
    4023 => :baby,
    4024 => :baby_swordman,
    4025 => :baby_mage,
    4026 => :baby_archer,
    4027 => :baby_acolyte,
    4028 => :baby_merchant,
    4029 => :baby_thief,
    4030 => :baby_knight,
    4031 => :baby_priest,
    4032 => :baby_wizard,
    4033 => :baby_blacksmith,
    4034 => :baby_hunter,
    4035 => :baby_assassin,
    # Baby Knight with Peco
    4036 => :baby_knight,
    4037 => :baby_crusader,
    4038 => :baby_monk,
    4039 => :baby_sage,
    4040 => :baby_rogue,
    4041 => :baby_alchemist,
    4042 => :baby_bard,
    4043 => :baby_dancer,
    # Baby Crusader with Peco
    4044 => :baby_crusader,
    4045 => :super_baby,

    # Expanded Jobs
    4046 => :taekwon,
    4047 => :star_gladiator,
    # Star Gladiator (Union)
    4048 => :star_gladiator,
    4049 => :soul_linker,

    # 3rd Jobs
    4054 => :rune_knight,
    4055 => :warlock,
    4056 => :ranger,
    4057 => :arch_bishop,
    4058 => :mechanic,
    4059 => :guillotine_cross,

    # 3rd Jobs Trans
    4060 => :rune_knight,
    4061 => :warlock,
    4062 => :ranger,
    4063 => :arch_bishop,
    4064 => :mechanic,
    4065 => :guillotine_cross,
    4066 => :royal_guard,
    4067 => :sorcerer,
    4068 => :minstrel,
    4069 => :wanderer,
    4070 => :sura,
    4071 => :genetic,
    4072 => :shadow_chaser,
    4073 => :royal_guard,
    4074 => :sorcerer,
    4075 => :minstrel,
    4076 => :wanderer,
    4077 => :sura,
    4078 => :genetic,
    4079 => :shadow_chaser,

    # Mounted 3rd Jobs
    4080 => :rune_knight,
    4081 => :rune_knight,
    4082 => :royal_guard,
    4083 => :royal_guard,
    4084 => :ranger,
    4085 => :ranger,
    4086 => :mechanic,
    4087 => :mechanic,

    # Baby 3rd Jobs
    4096 => :baby_rune_knight,
    4097 => :baby_warlock,
    4098 => :baby_ranger,
    4099 => :baby_arch_bishop,
    4100 => :baby_mechanic,
    4101 => :baby_guillotine_cross,
    4102 => :baby_royal_guard,
    4103 => :baby_sorcerer,
    4104 => :baby_minstrel,
    4105 => :baby_wanderer,
    4106 => :baby_sura,
    4107 => :baby_genetic,
    4108 => :baby_shadow_chaser,

    # Expanded Super Jobs
    4190 => :super_novice,
    4191 => :super_baby,

    # Kagerou/Oboro
    4211 => :kagerou,
    4212 => :oboro,

    # Rebellion
    4215 => :rebellion,

    # Summoner
    4218 => :summoner,
    4220 => :baby_summoner,

    # Baby Expanded
    4222 => :baby_ninja,
    4223 => :baby_kagerou,
    4224 => :baby_oboro,
    4225 => :baby_taekwon,
    4226 => :baby_star_gladiator,
    4227 => :baby_soul_linker,
    4228 => :baby_gunslinger,
    4229 => :baby_rebellion,

    # Star Emperor/Soul Reaper
    4239 => :star_emperor,
    4240 => :soul_reaper,
    4241 => :baby_star_emperor,
    4242 => :baby_soul_reaper,

    # 4th Jobs
    4252 => :dragon_knight,
    4253 => :meister,
    4254 => :shadow_cross,
    4255 => :arch_mage,
    4256 => :cardinal,
    4257 => :windhawk,
    4258 => :imperial_guard,
    4259 => :biolo,
    4260 => :abyss_chaser,
    4261 => :elemental_master,
    4262 => :inquisitor,
    4263 => :troubadour,
    4264 => :trouvere
  }

  @doc """
  Initializes the job data ETS tables.
  """
  @spec init() :: :ok
  def init do
    load_job_data()
    load_id_mappings()
  end

  @doc """
  Gets the job atom for a given job ID.
  Returns :novice if the job ID is not found.
  """
  @spec get_job_atom(integer()) :: atom()
  def get_job_atom(job_id) when is_integer(job_id) do
    case :ets.lookup(table_for(:job_id_mappings), {:id_to_atom, job_id}) do
      [{_, atom}] ->
        atom

      [] ->
        raise ArgumentError,
              "Job ID #{job_id} not found. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the job ID for a given job atom.
  Returns 0 (novice) if the job atom is not found.
  """
  @spec get_job_id(atom()) :: integer()
  def get_job_id(job_atom) when is_atom(job_atom) do
    case :ets.lookup(table_for(:job_id_mappings), {:atom_to_id, job_atom}) do
      [{_, id}] ->
        id

      [] ->
        raise ArgumentError,
              "Job atom #{job_atom} not found. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the base HP for a specific job and level.
  """
  @spec get_base_hp(integer(), integer()) :: integer()
  def get_base_hp(job_id, level) when is_integer(job_id) and is_integer(level) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:base_hp, job_atom}) do
      [{_, hp_table}] ->
        find_level_value(hp_table, level, :hp, 40)

      [] ->
        raise ArgumentError,
              "Base HP not found for job #{job_atom} at level #{level}. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the base SP for a specific job and level.
  """
  @spec get_base_sp(integer(), integer()) :: integer()
  def get_base_sp(job_id, level) when is_integer(job_id) and is_integer(level) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:base_sp, job_atom}) do
      [{_, sp_table}] ->
        find_level_value(sp_table, level, :sp, 11)

      [] ->
        raise ArgumentError,
              "Base SP not found for job #{job_atom} at level #{level}. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the job bonuses for a specific job and job level.
  Returns a map of stat_name => bonus_value.
  """
  @spec get_job_bonuses(integer(), integer()) :: map()
  def get_job_bonuses(job_id, job_level) when is_integer(job_id) and is_integer(job_level) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:bonus_stats, job_atom}) do
      [{_, bonus_list}] ->
        calculate_job_bonuses(bonus_list, job_level)

      [] ->
        raise ArgumentError,
              "Job bonuses not found for job #{job_atom} at level #{job_level}. Ensure job data is loaded."
    end
  end

  defp calculate_job_bonuses(bonus_list, job_level) do
    bonus_list
    |> Enum.filter(fn bonus -> bonus.level <= job_level end)
    |> Enum.reduce(%{}, &accumulate_bonus/2)
  end

  defp accumulate_bonus(bonus, acc) do
    # Each bonus entry has one stat with a value of 1
    stat_key = bonus |> Map.keys() |> Enum.find(fn k -> k not in [:level] end)

    if stat_key do
      Map.update(acc, stat_key, bonus[stat_key], &(&1 + bonus[stat_key]))
    else
      acc
    end
  end

  @doc """
  Gets the HP factor for a specific job.
  """
  @spec get_hp_factor(integer()) :: integer()
  def get_hp_factor(job_id) when is_integer(job_id) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:hp_factor, job_atom}) do
      [{_, factor}] ->
        factor

      [] ->
        raise ArgumentError,
              "HP factor not found for job #{job_atom}. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the HP increase value for a specific job.
  """
  @spec get_hp_increase(integer()) :: integer()
  def get_hp_increase(job_id) when is_integer(job_id) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:hp_increase, job_atom}) do
      [{_, increase}] ->
        increase

      [] ->
        raise ArgumentError,
              "HP increase not found for job #{job_atom}. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the SP increase value for a specific job.
  """
  @spec get_sp_increase(integer()) :: integer()
  def get_sp_increase(job_id) when is_integer(job_id) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:sp_increase, job_atom}) do
      [{_, increase}] ->
        increase

      [] ->
        raise ArgumentError,
              "SP increase not found for job #{job_atom}. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the maximum weight for a specific job.
  """
  @spec get_max_weight(integer()) :: integer()
  def get_max_weight(job_id) when is_integer(job_id) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:max_weight, job_atom}) do
      [{_, weight}] ->
        weight

      [] ->
        raise ArgumentError,
              "Max weight not found for job #{job_atom}. Ensure job data is loaded."
    end
  end

  @doc """
  Gets the base ASPD for a specific job and weapon type.
  """
  @spec get_base_aspd(integer(), atom()) :: integer() | nil
  def get_base_aspd(job_id, weapon_type \\ :barehand) when is_integer(job_id) do
    job_atom = get_job_atom(job_id)

    case :ets.lookup(table_for(:job_data), {:base_aspd, job_atom, weapon_type}) do
      [{_, aspd}] ->
        aspd

      [] ->
        raise ArgumentError,
              "Base ASPD not found for job #{job_atom} with weapon type #{weapon_type}. Ensure job data is loaded."
    end
  end

  defp load_job_data do
    job_data_path = Path.join([:code.priv_dir(:zone_server), "db/job.exs"])

    case File.exists?(job_data_path) && Code.eval_file(job_data_path) do
      {job_data, _} when is_list(job_data) ->
        Enum.each(job_data, &store_job_entry/1)
        Logger.debug("Loaded #{length(job_data)} job entries")

      false ->
        raise "Job data file not found at #{job_data_path}"

      _ ->
        raise "Invalid job data format in #{job_data_path}"
    end
  end

  defp store_job_entry(job_entry) do
    job_atom = job_entry.job

    # Store base HP table
    if hp_table = job_entry[:base_hp] do
      :ets.insert(table_for(:job_data), {{:base_hp, job_atom}, hp_table})
    end

    # Store base SP table
    if sp_table = job_entry[:base_sp] do
      :ets.insert(table_for(:job_data), {{:base_sp, job_atom}, sp_table})
    end

    # Store bonus stats
    if bonus_stats = job_entry[:bonus_stats] do
      :ets.insert(table_for(:job_data), {{:bonus_stats, job_atom}, bonus_stats})
    end

    # Store HP factor
    if hp_factor = job_entry[:hp_factor] do
      :ets.insert(table_for(:job_data), {{:hp_factor, job_atom}, hp_factor})
    end

    # Store HP increase
    if hp_increase = job_entry[:hp_increase] do
      :ets.insert(table_for(:job_data), {{:hp_increase, job_atom}, hp_increase})
    end

    # Store SP increase
    if sp_increase = job_entry[:sp_increase] do
      :ets.insert(table_for(:job_data), {{:sp_increase, job_atom}, sp_increase})
    end

    # Store max weight
    if max_weight = job_entry[:max_weight] do
      :ets.insert(table_for(:job_data), {{:max_weight, job_atom}, max_weight})
    end

    # Store ASPD data
    if aspd_data = job_entry[:base_aspd] do
      Enum.each(aspd_data, fn {weapon_type, value} ->
        :ets.insert(table_for(:job_data), {{:base_aspd, job_atom, weapon_type}, value})
      end)
    end
  end

  defp load_id_mappings do
    # Ensure table exists before inserting
    if :ets.whereis(table_for(:job_id_mappings)) == :undefined do
      :ets.new(table_for(:job_id_mappings), [:named_table, :public, :set, read_concurrency: true])
    end

    # Store ID to atom mappings
    Enum.each(@job_id_mappings, fn {id, atom} ->
      :ets.insert(table_for(:job_id_mappings), {{:id_to_atom, id}, atom})
    end)

    # Store atom to ID mappings (reverse)
    Enum.each(@job_id_mappings, fn {id, atom} ->
      :ets.insert(table_for(:job_id_mappings), {{:atom_to_id, atom}, id})
    end)
  end

  defp find_level_value(table, level, key, default) do
    dbg(table)

    case Enum.find(table, fn entry -> entry.level == level end) do
      nil ->
        raise ArgumentError,
              "No entry found for level #{level} in #{key} table. Ensure job data is loaded."

      entry ->
        Map.get(entry, key, default)
    end
  end
end
