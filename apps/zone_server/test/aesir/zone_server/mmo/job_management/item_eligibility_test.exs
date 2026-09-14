defmodule Aesir.ZoneServer.Mmo.JobManagement.ItemEligibilityTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage

  test "exposes the exact canonical item family vocabulary and existing mounted normalization" do
    assert ItemEligibility.families() ==
             Enum.sort([
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
             ])

    assert JobLineage.normalize(:lord_knight2) == :lord_knight
    assert JobLineage.normalize(:star_gladiator2) == :star_gladiator2
  end

  test "resolves the complete exported source selector vocabulary without invented names" do
    expected = [
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

    for {family, selectors} <- expected, selector <- selectors do
      assert ItemEligibility.source_family(selector) == {:ok, family}
    end

    assert ItemEligibility.source_family("EAJ_LORD_KNIGHT") == {:ok, :knight}
    assert ItemEligibility.source_family("EAJ_BARD") == {:error, :unknown_source_job}
    assert ItemEligibility.source_family("EAJ_WEDDING") == {:error, :unknown_source_job}
  end

  test "classifies every real job identity with its Renewal family and category" do
    expected = expected_profiles()
    expected_ids = expected |> Map.keys() |> Enum.sort()
    real_ids = AvailableJobs.ids() -- [31, 4317]

    assert expected_ids == real_ids

    for {job_id, profile} <- expected do
      assert ItemEligibility.classify(job_id, :renewal) == {:ok, profile}
    end

    assert ItemEligibility.classify(31, :renewal) == {:error, :unknown_job}
    assert ItemEligibility.classify(4317, :renewal) == {:error, :unknown_job}
    assert ItemEligibility.classify(99_999, :renewal) == {:error, :unknown_job}
  end

  test "pre-renewal broadens only third-flagged class permissions" do
    expected = expected_profiles()

    for {job_id, %{family: family, classes: [category]}} <- expected do
      classes =
        case category do
          :third_baby ->
            [:baby, :upper, :third, :third_upper, :third_baby]

          category when category in [:third, :third_upper, :fourth] ->
            [:upper, :third, :third_upper, :third_baby]

          category ->
            [category]
        end

      assert ItemEligibility.classify(job_id, :pre_renewal) ==
               {:ok, %{family: family, classes: classes}}
    end
  end

  test "mode delegates to the configured runtime mode" do
    assert ItemEligibility.mode() == GameMode.mode()
  end

  defp expected_profiles do
    [
      {:normal, :novice, ~w(novice)a},
      {:normal, :swordman, ~w(swordman)a},
      {:normal, :mage, ~w(mage)a},
      {:normal, :archer, ~w(archer)a},
      {:normal, :acolyte, ~w(acolyte)a},
      {:normal, :merchant, ~w(merchant)a},
      {:normal, :thief, ~w(thief)a},
      {:normal, :taekwon, ~w(taekwon)a},
      {:normal, :gunslinger, ~w(gunslinger)a},
      {:normal, :ninja, ~w(ninja)a},
      {:normal, :summoner, ~w(summoner)a},
      {:normal, :gangsi, ~w(gangsi)a},
      {:normal, :wedding, ~w(wedding)a},
      {:normal, :xmas, ~w(xmas)a},
      {:normal, :summer, ~w(summer)a},
      {:normal, :hanbok, ~w(hanbok)a},
      {:normal, :oktoberfest, ~w(oktoberfest)a},
      {:normal, :summer2, ~w(summer2)a},
      {:normal, :super_novice, ~w(super_novice)a},
      {:normal, :knight, ~w(knight knight2)a},
      {:normal, :wizard, ~w(wizard)a},
      {:normal, :hunter, ~w(hunter)a},
      {:normal, :priest, ~w(priest)a},
      {:normal, :blacksmith, ~w(blacksmith)a},
      {:normal, :assassin, ~w(assassin)a},
      {:normal, :star_gladiator, ~w(star_gladiator star_gladiator2)a},
      {:normal, :rebellion, ~w(rebellion)a},
      {:normal, :kagerou_oboro, ~w(kagerou oboro)a},
      {:normal, :spirit_handler, ~w(spirit_handler)a},
      {:normal, :death_knight, ~w(death_knight)a},
      {:normal, :crusader, ~w(crusader crusader2)a},
      {:normal, :sage, ~w(sage)a},
      {:normal, :bard_dancer, ~w(bard dancer)a},
      {:normal, :monk, ~w(monk)a},
      {:normal, :alchemist, ~w(alchemist)a},
      {:normal, :rogue, ~w(rogue)a},
      {:normal, :soul_linker, ~w(soul_linker)a},
      {:normal, :dark_collector, ~w(dark_collector)a},
      {:upper, :novice, ~w(novice_high)a},
      {:upper, :swordman, ~w(swordman_high)a},
      {:upper, :mage, ~w(mage_high)a},
      {:upper, :archer, ~w(archer_high)a},
      {:upper, :acolyte, ~w(acolyte_high)a},
      {:upper, :merchant, ~w(merchant_high)a},
      {:upper, :thief, ~w(thief_high)a},
      {:upper, :knight, ~w(lord_knight lord_knight2)a},
      {:upper, :wizard, ~w(high_wizard)a},
      {:upper, :hunter, ~w(sniper)a},
      {:upper, :priest, ~w(high_priest)a},
      {:upper, :blacksmith, ~w(whitesmith)a},
      {:upper, :assassin, ~w(assassin_cross)a},
      {:upper, :crusader, ~w(paladin paladin2)a},
      {:upper, :sage, ~w(professor)a},
      {:upper, :bard_dancer, ~w(clown gypsy)a},
      {:upper, :monk, ~w(champion)a},
      {:upper, :alchemist, ~w(creator)a},
      {:upper, :rogue, ~w(stalker)a},
      {:baby, :novice, ~w(baby)a},
      {:baby, :swordman, ~w(baby_swordman)a},
      {:baby, :mage, ~w(baby_mage)a},
      {:baby, :archer, ~w(baby_archer)a},
      {:baby, :acolyte, ~w(baby_acolyte)a},
      {:baby, :merchant, ~w(baby_merchant)a},
      {:baby, :thief, ~w(baby_thief)a},
      {:baby, :taekwon, ~w(baby_taekwon)a},
      {:baby, :gunslinger, ~w(baby_gunslinger)a},
      {:baby, :ninja, ~w(baby_ninja)a},
      {:baby, :summoner, ~w(baby_summoner)a},
      {:baby, :super_novice, ~w(super_baby)a},
      {:baby, :knight, ~w(baby_knight baby_knight2)a},
      {:baby, :wizard, ~w(baby_wizard)a},
      {:baby, :hunter, ~w(baby_hunter)a},
      {:baby, :priest, ~w(baby_priest)a},
      {:baby, :blacksmith, ~w(baby_blacksmith)a},
      {:baby, :assassin, ~w(baby_assassin)a},
      {:baby, :star_gladiator, ~w(baby_star_gladiator baby_star_gladiator2)a},
      {:baby, :rebellion, ~w(baby_rebellion)a},
      {:baby, :kagerou_oboro, ~w(baby_kagerou baby_oboro)a},
      {:baby, :crusader, ~w(baby_crusader baby_crusader2)a},
      {:baby, :sage, ~w(baby_sage)a},
      {:baby, :bard_dancer, ~w(baby_bard baby_dancer)a},
      {:baby, :monk, ~w(baby_monk)a},
      {:baby, :alchemist, ~w(baby_alchemist)a},
      {:baby, :rogue, ~w(baby_rogue)a},
      {:baby, :soul_linker, ~w(baby_soul_linker)a},
      {:third, :super_novice, ~w(super_novice_e)a},
      {:third, :knight, ~w(rune_knight rune_knight2)a},
      {:third, :wizard, ~w(warlock)a},
      {:third, :hunter, ~w(ranger ranger2)a},
      {:third, :priest, ~w(arch_bishop)a},
      {:third, :blacksmith, ~w(mechanic mechanic2)a},
      {:third, :assassin, ~w(guillotine_cross)a},
      {:third, :star_gladiator, ~w(star_emperor star_emperor2)a},
      {:third, :rebellion, ~w(night_watch)a},
      {:third, :kagerou_oboro, ~w(shinkiro shiranui)a},
      {:third, :crusader, ~w(royal_guard royal_guard2)a},
      {:third, :sage, ~w(sorcerer)a},
      {:third, :bard_dancer, ~w(minstrel wanderer)a},
      {:third, :monk, ~w(sura)a},
      {:third, :alchemist, ~w(genetic)a},
      {:third, :rogue, ~w(shadow_chaser)a},
      {:third, :soul_linker, ~w(soul_reaper)a},
      {:third_upper, :knight, ~w(rune_knight_t rune_knight_t2)a},
      {:third_upper, :wizard, ~w(warlock_t)a},
      {:third_upper, :hunter, ~w(ranger_t ranger_t2)a},
      {:third_upper, :priest, ~w(arch_bishop_t)a},
      {:third_upper, :blacksmith, ~w(mechanic_t mechanic_t2)a},
      {:third_upper, :assassin, ~w(guillotine_cross_t)a},
      {:third_upper, :crusader, ~w(royal_guard_t royal_guard_t2)a},
      {:third_upper, :sage, ~w(sorcerer_t)a},
      {:third_upper, :bard_dancer, ~w(minstrel_t wanderer_t)a},
      {:third_upper, :monk, ~w(sura_t)a},
      {:third_upper, :alchemist, ~w(genetic_t)a},
      {:third_upper, :rogue, ~w(shadow_chaser_t)a},
      {:third_baby, :super_novice, ~w(super_baby_e)a},
      {:third_baby, :knight, ~w(baby_rune_knight baby_rune_knight2)a},
      {:third_baby, :wizard, ~w(baby_warlock)a},
      {:third_baby, :hunter, ~w(baby_ranger baby_ranger2)a},
      {:third_baby, :priest, ~w(baby_arch_bishop)a},
      {:third_baby, :blacksmith, ~w(baby_mechanic baby_mechanic2)a},
      {:third_baby, :assassin, ~w(baby_guillotine_cross)a},
      {:third_baby, :star_gladiator, ~w(baby_star_emperor baby_star_emperor2)a},
      {:third_baby, :crusader, ~w(baby_royal_guard baby_royal_guard2)a},
      {:third_baby, :sage, ~w(baby_sorcerer)a},
      {:third_baby, :bard_dancer, ~w(baby_minstrel baby_wanderer)a},
      {:third_baby, :monk, ~w(baby_sura)a},
      {:third_baby, :alchemist, ~w(baby_genetic)a},
      {:third_baby, :rogue, ~w(baby_shadow_chaser)a},
      {:third_baby, :soul_linker, ~w(baby_soul_reaper)a},
      {:fourth, :super_novice, ~w(hyper_novice)a},
      {:fourth, :knight, ~w(dragon_knight dragon_knight2)a},
      {:fourth, :wizard, ~w(arch_mage)a},
      {:fourth, :hunter, ~w(windhawk windhawk2)a},
      {:fourth, :priest, ~w(cardinal)a},
      {:fourth, :blacksmith, ~w(meister meister2)a},
      {:fourth, :assassin, ~w(shadow_cross)a},
      {:fourth, :star_gladiator, ~w(sky_emperor sky_emperor2)a},
      {:fourth, :crusader, ~w(imperial_guard imperial_guard2)a},
      {:fourth, :sage, ~w(elemental_master)a},
      {:fourth, :bard_dancer, ~w(troubadour trouvere)a},
      {:fourth, :monk, ~w(inquisitor)a},
      {:fourth, :alchemist, ~w(biolo)a},
      {:fourth, :rogue, ~w(abyss_chaser)a},
      {:fourth, :soul_linker, ~w(soul_ascetic)a}
    ]
    |> Enum.flat_map(fn {category, family, jobs} ->
      Enum.map(jobs, fn job ->
        {:ok, job_id} = AvailableJobs.job_name_to_id(job)
        {job_id, %{family: family, classes: [category]}}
      end)
    end)
    |> Map.new()
  end
end
