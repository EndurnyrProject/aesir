defmodule Aesir.ZoneServer.Mmo.JobManagement.ItemEligibilityTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.ItemEligibility

  test "the family vocabulary is exactly the families real jobs classify into" do
    classified =
      expected_profiles() |> Map.values() |> Enum.map(& &1.family) |> Enum.uniq() |> Enum.sort()

    assert ItemEligibility.families() == classified
  end

  test "resolves exported item-job selectors to their canonical family" do
    for {selector, family} <- [
          {"EAJ_NOVICE_HIGH", :novice},
          {"EAJ_BABY", :novice},
          {"EAJ_SUPERNOVICE", :super_novice},
          {"EAJ_HYPER_NOVICE", :super_novice},
          {"EAJ_LORD_KNIGHT", :knight},
          {"EAJ_DRAGON_KNIGHT", :knight},
          {"EAJ_BARDDANCER", :bard_dancer},
          {"EAJ_KAGEROUOBORO", :kagerou_oboro},
          {"EAJ_STARGLADIATOR", :star_gladiator},
          {"EAJ_SOUL_ASCETIC", :soul_linker}
        ] do
      assert ItemEligibility.source_family(selector) == {:ok, family}
    end

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
