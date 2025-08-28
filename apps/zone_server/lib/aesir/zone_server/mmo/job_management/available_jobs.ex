defmodule Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs do
  @job_id_to_name %{
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
    13 => :knight2,
    14 => :crusader,
    15 => :monk,
    16 => :sage,
    17 => :rogue,
    18 => :alchemist,
    19 => :bard,
    20 => :dancer,
    # Crusader with Peco
    21 => :crusader2,

    # Special
    22 => :wedding,
    23 => :super_novice,
    24 => :gunslinger,
    25 => :ninja,
    26 => :xmas,
    27 => :summer,
    28 => :hanbok,
    29 => :oktoberfest,
    30 => :summer2,
    31 => :max_basic,

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
    4014 => :lord_knight2,
    4015 => :paladin,
    4016 => :champion,
    4017 => :professor,
    4018 => :stalker,
    4019 => :creator,
    4020 => :clown,
    4021 => :gypsy,
    # Paladin with Peco
    4022 => :paladin2,

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
    4036 => :baby_knight2,
    4037 => :baby_crusader,
    4038 => :baby_monk,
    4039 => :baby_sage,
    4040 => :baby_rogue,
    4041 => :baby_alchemist,
    4042 => :baby_bard,
    4043 => :baby_dancer,
    # Baby Crusader with Peco
    4044 => :baby_crusader2,
    4045 => :super_baby,

    # Expanded Jobs
    4046 => :taekwon,
    4047 => :star_gladiator,
    # Star Gladiator (Union)
    4048 => :star_gladiator2,
    4049 => :soul_linker,

    # Unused Jobs
    4050 => :gangsi,
    4051 => :death_knight,
    4052 => :dark_collector,

    # 3rd-1 Jobs
    4054 => :rune_knight,
    4055 => :warlock,
    4056 => :ranger,
    4057 => :arch_bishop,
    4058 => :mechanic,
    4059 => :guillotine_cross,

    # 3rd-1 Jobs Trans
    4060 => :rune_knight_t,
    4061 => :warlock_t,
    4062 => :ranger_t,
    4063 => :arch_bishop_t,
    4064 => :mechanic_t,
    4065 => :guillotine_cross_t,

    # 3rd-2 Jobs
    4066 => :royal_guard,
    4067 => :sorcerer,
    4068 => :minstrel,
    4069 => :wanderer,
    4070 => :sura,
    4071 => :genetic,
    4072 => :shadow_chaser,

    # 3rd-2 Jobs Trans
    4073 => :royal_guard_t,
    4074 => :sorcerer_t,
    4075 => :minstrel_t,
    4076 => :wanderer_t,
    4077 => :sura_t,
    4078 => :genetic_t,
    4079 => :shadow_chaser_t,

    # Mounted 3rd Jobs
    4080 => :rune_knight2,
    4081 => :rune_knight_t2,
    4082 => :royal_guard2,
    4083 => :royal_guard_t2,
    4084 => :ranger2,
    4085 => :ranger_t2,
    4086 => :mechanic2,
    4087 => :mechanic_t2,

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

    # Baby Mounted Jobs
    4109 => :baby_rune_knight2,
    4110 => :baby_royal_guard2,
    4111 => :baby_ranger2,
    4112 => :baby_mechanic2,

    # Expanded Super Jobs
    4190 => :super_novice_e,
    4191 => :super_baby_e,

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
    4238 => :baby_star_gladiator2,
    4239 => :star_emperor,
    4240 => :soul_reaper,
    4241 => :baby_star_emperor,
    4242 => :baby_soul_reaper,
    4243 => :star_emperor2,
    4244 => :baby_star_emperor2,

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
    4264 => :trouvere,

    # 4th Jobs Mounted
    4278 => :windhawk2,
    4279 => :meister2,
    4280 => :dragon_knight2,
    4281 => :imperial_guard2,

    # Extended Jobs
    4302 => :sky_emperor,
    4303 => :soul_ascetic,
    4304 => :shinkiro,
    4305 => :shiranui,
    4306 => :night_watch,
    4307 => :hyper_novice,
    4308 => :spirit_handler,
    4316 => :sky_emperor2,

    # Placeholder for jobmax
    4317 => :job_max
  }

  @job_name_to_id Map.new(@job_id_to_name, fn {k, v} -> {v, k} end)

  @spec job_id_to_name(integer()) :: {:ok, atom()} | {:error, :unknown_job_id}
  def job_id_to_name(job_id) when is_integer(job_id) do
    case Map.get(@job_id_to_name, job_id) do
      nil -> {:error, :unknown_job_id}
      job -> {:ok, job}
    end
  end

  @spec job_name_to_id(atom()) :: {:ok, integer} | {:error, :unknown_job}
  def job_name_to_id(job_name) when is_atom(job_name) do
    case Map.get(@job_name_to_id, job_name) do
      nil -> {:error, :unknown_job}
      job_id -> {:ok, job_id}
    end
  end
end
