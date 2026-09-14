defmodule Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility do
  @moduledoc """
  Canonical item job families and mode-aware character eligibility profiles.

  Item families identify a job line independently from the character's normal,
  transcendent, baby, third, or fourth class category.
  """

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid

  @families [
    :novice,
    :swordman,
    :mage,
    :archer,
    :acolyte,
    :merchant,
    :thief,
    :taekwon,
    :gunslinger,
    :ninja,
    :summoner,
    :gangsi,
    :wedding,
    :xmas,
    :summer,
    :hanbok,
    :oktoberfest,
    :summer2,
    :super_novice,
    :knight,
    :wizard,
    :hunter,
    :priest,
    :blacksmith,
    :assassin,
    :star_gladiator,
    :rebellion,
    :kagerou_oboro,
    :spirit_handler,
    :death_knight,
    :crusader,
    :sage,
    :bard_dancer,
    :monk,
    :alchemist,
    :rogue,
    :soul_linker,
    :dark_collector
  ]

  @family_by_mapid %{
    0x0 => :novice,
    0x1 => :swordman,
    0x2 => :mage,
    0x3 => :archer,
    0x4 => :acolyte,
    0x5 => :merchant,
    0x6 => :thief,
    0x7 => :taekwon,
    0x8 => :gunslinger,
    0x9 => :ninja,
    0xA => :summoner,
    0xB => :gangsi,
    0xC => :wedding,
    0xD => :xmas,
    0xE => :summer,
    0xF => :hanbok,
    0x10 => :oktoberfest,
    0x11 => :summer2,
    0x100 => :super_novice,
    0x101 => :knight,
    0x102 => :wizard,
    0x103 => :hunter,
    0x104 => :priest,
    0x105 => :blacksmith,
    0x106 => :assassin,
    0x107 => :star_gladiator,
    0x108 => :rebellion,
    0x109 => :kagerou_oboro,
    0x10A => :spirit_handler,
    0x10B => :death_knight,
    0x201 => :crusader,
    0x202 => :sage,
    0x203 => :bard_dancer,
    0x204 => :monk,
    0x205 => :alchemist,
    0x206 => :rogue,
    0x207 => :soul_linker,
    0x20B => :dark_collector
  }

  @alternate_jobs %{
    star_gladiator2: :star_gladiator,
    baby_star_gladiator2: :baby_star_gladiator,
    star_emperor2: :star_emperor,
    baby_star_emperor2: :baby_star_emperor,
    sky_emperor2: :sky_emperor
  }

  @category_by_job [
                     normal:
                       ~w(novice swordman mage archer acolyte merchant thief taekwon gunslinger ninja summoner gangsi wedding xmas summer hanbok oktoberfest summer2 super_novice knight wizard hunter priest blacksmith assassin star_gladiator star_gladiator2 rebellion kagerou oboro spirit_handler death_knight crusader sage bard dancer monk alchemist rogue soul_linker dark_collector)a,
                     upper:
                       ~w(novice_high swordman_high mage_high archer_high acolyte_high merchant_high thief_high lord_knight high_wizard sniper high_priest whitesmith assassin_cross paladin professor clown gypsy champion creator stalker)a,
                     baby:
                       ~w(baby baby_swordman baby_mage baby_archer baby_acolyte baby_merchant baby_thief baby_taekwon baby_gunslinger baby_ninja baby_summoner super_baby baby_knight baby_wizard baby_hunter baby_priest baby_blacksmith baby_assassin baby_star_gladiator baby_star_gladiator2 baby_rebellion baby_kagerou baby_oboro baby_crusader baby_sage baby_bard baby_dancer baby_monk baby_alchemist baby_rogue baby_soul_linker)a,
                     third:
                       ~w(super_novice_e rune_knight warlock ranger arch_bishop mechanic guillotine_cross star_emperor star_emperor2 night_watch shinkiro shiranui royal_guard sorcerer minstrel wanderer sura genetic shadow_chaser soul_reaper)a,
                     third_upper:
                       ~w(rune_knight_t warlock_t ranger_t arch_bishop_t mechanic_t guillotine_cross_t royal_guard_t sorcerer_t minstrel_t wanderer_t sura_t genetic_t shadow_chaser_t)a,
                     third_baby:
                       ~w(super_baby_e baby_rune_knight baby_warlock baby_ranger baby_arch_bishop baby_mechanic baby_guillotine_cross baby_star_emperor baby_star_emperor2 baby_royal_guard baby_sorcerer baby_minstrel baby_wanderer baby_sura baby_genetic baby_shadow_chaser baby_soul_reaper)a,
                     fourth:
                       ~w(hyper_novice dragon_knight arch_mage windhawk cardinal meister shadow_cross sky_emperor sky_emperor2 imperial_guard elemental_master troubadour trouvere inquisitor biolo abyss_chaser soul_ascetic)a
                   ]
                   |> Enum.flat_map(fn {category, jobs} -> Enum.map(jobs, &{&1, category}) end)
                   |> Map.new()

  @source_selectors [
    novice: ~w(EAJ_NOVICE EAJ_NOVICE_HIGH EAJ_BABY),
    swordman: ~w(EAJ_SWORDMAN EAJ_SWORDMAN_HIGH EAJ_BABY_SWORDMAN),
    mage: ~w(EAJ_MAGE EAJ_MAGE_HIGH EAJ_BABY_MAGE),
    archer: ~w(EAJ_ARCHER EAJ_ARCHER_HIGH EAJ_BABY_ARCHER),
    acolyte: ~w(EAJ_ACOLYTE EAJ_ACOLYTE_HIGH EAJ_BABY_ACOLYTE),
    merchant: ~w(EAJ_MERCHANT EAJ_MERCHANT_HIGH EAJ_BABY_MERCHANT),
    thief: ~w(EAJ_THIEF EAJ_THIEF_HIGH EAJ_BABY_THIEF),
    taekwon: ~w(EAJ_TAEKWON EAJ_BABY_TAEKWON),
    gunslinger: ~w(EAJ_GUNSLINGER EAJ_BABY_GUNSLINGER),
    ninja: ~w(EAJ_NINJA EAJ_BABY_NINJA),
    summoner: ~w(EAJ_SUMMONER EAJ_BABY_SUMMONER),
    gangsi: ~w(EAJ_GANGSI),
    super_novice:
      ~w(EAJ_SUPER_NOVICE EAJ_SUPERNOVICE EAJ_SUPER_BABY EAJ_SUPER_NOVICE_E EAJ_SUPER_BABY_E EAJ_HYPER_NOVICE),
    knight:
      ~w(EAJ_KNIGHT EAJ_LORD_KNIGHT EAJ_BABY_KNIGHT EAJ_RUNE_KNIGHT EAJ_RUNE_KNIGHT_T EAJ_BABY_RUNE_KNIGHT EAJ_DRAGON_KNIGHT),
    wizard:
      ~w(EAJ_WIZARD EAJ_HIGH_WIZARD EAJ_BABY_WIZARD EAJ_WARLOCK EAJ_WARLOCK_T EAJ_BABY_WARLOCK EAJ_ARCH_MAGE),
    hunter:
      ~w(EAJ_HUNTER EAJ_SNIPER EAJ_BABY_HUNTER EAJ_RANGER EAJ_RANGER_T EAJ_BABY_RANGER EAJ_WINDHAWK),
    priest:
      ~w(EAJ_PRIEST EAJ_HIGH_PRIEST EAJ_BABY_PRIEST EAJ_ARCH_BISHOP EAJ_ARCH_BISHOP_T EAJ_BABY_ARCH_BISHOP EAJ_CARDINAL),
    blacksmith:
      ~w(EAJ_BLACKSMITH EAJ_WHITESMITH EAJ_BABY_BLACKSMITH EAJ_MECHANIC EAJ_MECHANIC_T EAJ_BABY_MECHANIC EAJ_MEISTER),
    assassin:
      ~w(EAJ_ASSASSIN EAJ_ASSASSIN_CROSS EAJ_BABY_ASSASSIN EAJ_GUILLOTINE_CROSS EAJ_GUILLOTINE_CROSS_T EAJ_BABY_GUILLOTINE_CROSS EAJ_SHADOW_CROSS),
    star_gladiator:
      ~w(EAJ_STAR_GLADIATOR EAJ_STARGLADIATOR EAJ_BABY_STAR_GLADIATOR EAJ_STAR_EMPEROR EAJ_BABY_STAR_EMPEROR EAJ_SKY_EMPEROR),
    rebellion: ~w(EAJ_REBELLION EAJ_BABY_REBELLION EAJ_NIGHT_WATCH),
    kagerou_oboro: ~w(EAJ_KAGEROUOBORO EAJ_BABY_KAGEROUOBORO EAJ_SHINKIROSHIRANUI),
    spirit_handler: ~w(EAJ_SPIRIT_HANDLER),
    death_knight: ~w(EAJ_DEATH_KNIGHT EAJ_DEATHKNIGHT),
    crusader:
      ~w(EAJ_CRUSADER EAJ_PALADIN EAJ_BABY_CRUSADER EAJ_ROYAL_GUARD EAJ_ROYAL_GUARD_T EAJ_BABY_ROYAL_GUARD EAJ_IMPERIAL_GUARD),
    sage:
      ~w(EAJ_SAGE EAJ_PROFESSOR EAJ_BABY_SAGE EAJ_SORCERER EAJ_SORCERER_T EAJ_BABY_SORCERER EAJ_ELEMENTAL_MASTER),
    bard_dancer:
      ~w(EAJ_BARDDANCER EAJ_CLOWNGYPSY EAJ_BABY_BARDDANCER EAJ_MINSTRELWANDERER EAJ_MINSTRELWANDERER_T EAJ_BABY_MINSTRELWANDERER EAJ_TROUBADOURTROUVERE),
    monk:
      ~w(EAJ_MONK EAJ_CHAMPION EAJ_BABY_MONK EAJ_SURA EAJ_SURA_T EAJ_BABY_SURA EAJ_INQUISITOR),
    alchemist:
      ~w(EAJ_ALCHEMIST EAJ_CREATOR EAJ_BABY_ALCHEMIST EAJ_GENETIC EAJ_GENETIC_T EAJ_BABY_GENETIC EAJ_BIOLO),
    rogue:
      ~w(EAJ_ROGUE EAJ_STALKER EAJ_BABY_ROGUE EAJ_SHADOW_CHASER EAJ_SHADOW_CHASER_T EAJ_BABY_SHADOW_CHASER EAJ_ABYSS_CHASER),
    soul_linker:
      ~w(EAJ_SOUL_LINKER EAJ_SOULLINKER EAJ_BABY_SOUL_LINKER EAJ_SOUL_REAPER EAJ_BABY_SOUL_REAPER EAJ_SOUL_ASCETIC),
    dark_collector: ~w(EAJ_DARK_COLLECTOR EAJ_DARKCOLLECTOR)
  ]

  @source_families Map.new(@source_selectors, fn {family, selectors} ->
                     {family, selectors}
                   end)
                   |> Enum.flat_map(fn {family, selectors} ->
                     Enum.map(selectors, &{&1, family})
                   end)
                   |> Map.new()

  @typedoc "The configured game ruleset used to interpret item class categories."
  @type mode :: :renewal | :pre_renewal

  @typedoc "A canonical item job family."
  @type family :: unquote(Enum.reduce(@families, &{:|, [], [&1, &2]}))

  @typedoc "A character class category used by item restrictions."
  @type category :: :normal | :upper | :baby | :third | :third_upper | :third_baby | :fourth

  @doc "Returns the active game ruleset used for item class interpretation."
  @spec mode() :: mode()
  def mode, do: GameMode.mode()

  @doc "Classifies a character job into its item family and permitted class categories."
  @spec classify(integer(), mode()) ::
          {:ok, %{family: family(), classes: [category()]}} | {:error, :unknown_job}
  def classify(job_id, mode) when is_integer(job_id) and mode in [:renewal, :pre_renewal] do
    with {:ok, job} <- AvailableJobs.job_id_to_name(job_id),
         job = JobLineage.normalize(job),
         {:ok, category} <- Map.fetch(@category_by_job, job),
         {:ok, family} <- Map.fetch(@family_by_mapid, family_mapid(job)) do
      {:ok, %{family: family, classes: classes(category, mode)}}
    else
      _unknown_job -> {:error, :unknown_job}
    end
  end

  @doc "Returns every canonical item job family in deterministic order."
  @spec families() :: [family()]
  def families, do: Enum.sort(@families)

  @doc "Resolves an exact exported item-job selector to its canonical family."
  @spec source_family(String.t()) :: {:ok, family()} | {:error, :unknown_source_job}
  def source_family(source_job) when is_binary(source_job) do
    case Map.fetch(@source_families, source_job) do
      {:ok, family} -> {:ok, family}
      :error -> {:error, :unknown_source_job}
    end
  end

  defp family_mapid(job) do
    job
    |> then(&Map.get(@alternate_jobs, &1, &1))
    |> JobMapid.from_job()
    |> band(0x3FF)
  end

  defp classes(:third_baby, :pre_renewal),
    do: [:baby, :upper, :third, :third_upper, :third_baby]

  defp classes(category, :pre_renewal) when category in [:third, :third_upper, :fourth],
    do: [:upper, :third, :third_upper, :third_baby]

  defp classes(category, _mode), do: [category]
end
