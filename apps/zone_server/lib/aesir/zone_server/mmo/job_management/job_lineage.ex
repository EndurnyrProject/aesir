defmodule Aesir.ZoneServer.Mmo.JobManagement.JobLineage do
  @moduledoc """
  Canonical job ancestry used by mechanics that outlive a published skill tree.

  Keep this graph synchronized with `AvailableJobs` and the job database: every
  available job must be an explicit node, an intentional root, or a normalized
  mounted alias. `validate!/0` is the exhaustive CI guard for that contract.

  A job may have more than one parent when normal, transcendent, or baby variants
  converge on a later class. Mounted forms normalize to their canonical class.
  This keeps lineage checks exact at the declared owner tier instead of reducing
  jobs to a shared first class and accidentally admitting sibling branches.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.Jobs

  @parents %{
    swordman: [:novice],
    mage: [:novice],
    archer: [:novice],
    acolyte: [:novice],
    merchant: [:novice],
    thief: [:novice],
    knight: [:swordman],
    crusader: [:swordman],
    priest: [:acolyte],
    monk: [:acolyte],
    wizard: [:mage],
    sage: [:mage],
    blacksmith: [:merchant],
    alchemist: [:merchant],
    hunter: [:archer],
    bard: [:archer],
    dancer: [:archer],
    assassin: [:thief],
    rogue: [:thief],
    super_novice: [:novice],
    gunslinger: [:novice],
    ninja: [:novice],
    novice_high: [:novice],
    swordman_high: [:swordman, :novice_high],
    mage_high: [:mage, :novice_high],
    archer_high: [:archer, :novice_high],
    acolyte_high: [:acolyte, :novice_high],
    merchant_high: [:merchant, :novice_high],
    thief_high: [:thief, :novice_high],
    lord_knight: [:knight, :swordman_high],
    paladin: [:crusader, :swordman_high],
    high_priest: [:priest, :acolyte_high],
    champion: [:monk, :acolyte_high],
    high_wizard: [:wizard, :mage_high],
    professor: [:sage, :mage_high],
    whitesmith: [:blacksmith, :merchant_high],
    creator: [:alchemist, :merchant_high],
    sniper: [:hunter, :archer_high],
    clown: [:bard, :archer_high],
    gypsy: [:dancer, :archer_high],
    assassin_cross: [:assassin, :thief_high],
    stalker: [:rogue, :thief_high],
    baby: [:novice],
    baby_swordman: [:swordman, :baby],
    baby_mage: [:mage, :baby],
    baby_archer: [:archer, :baby],
    baby_acolyte: [:acolyte, :baby],
    baby_merchant: [:merchant, :baby],
    baby_thief: [:thief, :baby],
    baby_knight: [:knight, :baby_swordman],
    baby_crusader: [:crusader, :baby_swordman],
    baby_priest: [:priest, :baby_acolyte],
    baby_monk: [:monk, :baby_acolyte],
    baby_wizard: [:wizard, :baby_mage],
    baby_sage: [:sage, :baby_mage],
    baby_blacksmith: [:blacksmith, :baby_merchant],
    baby_alchemist: [:alchemist, :baby_merchant],
    baby_hunter: [:hunter, :baby_archer],
    baby_bard: [:bard, :baby_archer],
    baby_dancer: [:dancer, :baby_archer],
    baby_assassin: [:assassin, :baby_thief],
    baby_rogue: [:rogue, :baby_thief],
    super_baby: [:super_novice, :baby],
    rune_knight: [:knight],
    rune_knight_t: [:lord_knight],
    royal_guard: [:crusader],
    royal_guard_t: [:paladin],
    warlock: [:wizard],
    warlock_t: [:high_wizard],
    sorcerer: [:sage],
    sorcerer_t: [:professor],
    arch_bishop: [:priest],
    arch_bishop_t: [:high_priest],
    sura: [:monk],
    sura_t: [:champion],
    mechanic: [:blacksmith],
    mechanic_t: [:whitesmith],
    genetic: [:alchemist],
    genetic_t: [:creator],
    ranger: [:hunter],
    ranger_t: [:sniper],
    minstrel: [:bard],
    minstrel_t: [:clown],
    wanderer: [:dancer],
    wanderer_t: [:gypsy],
    guillotine_cross: [:assassin],
    guillotine_cross_t: [:assassin_cross],
    shadow_chaser: [:rogue],
    shadow_chaser_t: [:stalker],
    baby_rune_knight: [:baby_knight],
    baby_royal_guard: [:baby_crusader],
    baby_warlock: [:baby_wizard],
    baby_sorcerer: [:baby_sage],
    baby_arch_bishop: [:baby_priest],
    baby_sura: [:baby_monk],
    baby_mechanic: [:baby_blacksmith],
    baby_genetic: [:baby_alchemist],
    baby_ranger: [:baby_hunter],
    baby_minstrel: [:baby_bard],
    baby_wanderer: [:baby_dancer],
    baby_guillotine_cross: [:baby_assassin],
    baby_shadow_chaser: [:baby_rogue],
    dragon_knight: [:rune_knight, :rune_knight_t],
    imperial_guard: [:royal_guard, :royal_guard_t],
    arch_mage: [:warlock, :warlock_t],
    elemental_master: [:sorcerer, :sorcerer_t],
    cardinal: [:arch_bishop, :arch_bishop_t],
    inquisitor: [:sura, :sura_t],
    meister: [:mechanic, :mechanic_t],
    biolo: [:genetic, :genetic_t],
    windhawk: [:ranger, :ranger_t],
    troubadour: [:minstrel, :minstrel_t],
    trouvere: [:wanderer, :wanderer_t],
    shadow_cross: [:guillotine_cross, :guillotine_cross_t],
    abyss_chaser: [:shadow_chaser, :shadow_chaser_t],
    super_novice_e: [:super_novice],
    super_baby_e: [:super_baby, :super_novice_e],
    hyper_novice: [:super_novice_e],
    taekwon: [:novice],
    star_gladiator: [:taekwon],
    star_gladiator2: [:star_gladiator],
    soul_linker: [:taekwon],
    baby_taekwon: [:taekwon, :baby],
    baby_star_gladiator: [:star_gladiator, :baby_taekwon],
    baby_star_gladiator2: [:baby_star_gladiator],
    baby_soul_linker: [:soul_linker, :baby_taekwon],
    star_emperor: [:star_gladiator],
    star_emperor2: [:star_emperor],
    soul_reaper: [:soul_linker],
    baby_star_emperor: [:star_emperor, :baby_star_gladiator],
    baby_star_emperor2: [:baby_star_emperor],
    baby_soul_reaper: [:soul_reaper, :baby_soul_linker],
    sky_emperor: [:star_emperor],
    sky_emperor2: [:sky_emperor],
    soul_ascetic: [:soul_reaper],
    kagerou: [:ninja],
    oboro: [:ninja],
    baby_ninja: [:ninja, :baby],
    baby_kagerou: [:kagerou, :baby_ninja],
    baby_oboro: [:oboro, :baby_ninja],
    shinkiro: [:kagerou],
    shiranui: [:oboro],
    rebellion: [:gunslinger],
    baby_gunslinger: [:gunslinger, :baby],
    baby_rebellion: [:rebellion, :baby_gunslinger],
    night_watch: [:rebellion],
    baby_summoner: [:summoner],
    spirit_handler: [:summoner],
    gangsi: [:novice],
    death_knight: [:gangsi],
    dark_collector: [:gangsi]
  }

  @roots MapSet.new([
           :novice,
           :wedding,
           :xmas,
           :summer,
           :hanbok,
           :oktoberfest,
           :summer2,
           :max_basic,
           :summoner,
           :job_max
         ])

  @aliases %{
    knight2: :knight,
    crusader2: :crusader,
    lord_knight2: :lord_knight,
    paladin2: :paladin,
    baby_knight2: :baby_knight,
    baby_crusader2: :baby_crusader,
    rune_knight2: :rune_knight,
    rune_knight_t2: :rune_knight_t,
    royal_guard2: :royal_guard,
    royal_guard_t2: :royal_guard_t,
    ranger2: :ranger,
    ranger_t2: :ranger_t,
    mechanic2: :mechanic,
    mechanic_t2: :mechanic_t,
    baby_rune_knight2: :baby_rune_knight,
    baby_royal_guard2: :baby_royal_guard,
    baby_ranger2: :baby_ranger,
    baby_mechanic2: :baby_mechanic,
    windhawk2: :windhawk,
    meister2: :meister,
    dragon_knight2: :dragon_knight,
    imperial_guard2: :imperial_guard
  }

  @doc "Raises when the lineage diverges from either public job catalog."
  @spec validate!() :: :ok
  def validate! do
    available_jobs =
      Enum.map(AvailableJobs.ids(), fn job_id ->
        {:ok, job} = AvailableJobs.job_id_to_name(job_id)
        {job_id, job}
      end)

    database_jobs = Enum.map(Jobs.all(), &{&1.id, &1.name})
    validate_graph!(@parents, @roots, @aliases, available_jobs, database_jobs)
  end

  @doc false
  def validate_graph!(parents, roots, aliases, available_jobs, database_jobs) do
    represented? = fn job ->
      Map.has_key?(parents, job) or MapSet.member?(roots, job) or Map.has_key?(aliases, job)
    end

    validate_jobs!("AvailableJobs", available_jobs, represented?)
    validate_jobs!("job database", database_jobs, represented?)
    Enum.each(parents, &validate_parent_targets!(&1, represented?))
    Enum.each(aliases, &validate_alias_target!(&1, represented?))
    validate_acyclic!(parents, aliases, roots)
  end

  defp validate_jobs!(source, jobs, represented?) do
    Enum.each(jobs, fn {job_id, job} ->
      unless represented?.(job) do
        raise "job #{inspect(job)} (#{job_id}) from #{source} is absent from JobLineage"
      end
    end)
  end

  defp validate_parent_targets!({job, parents}, represented?) do
    Enum.each(parents, fn parent ->
      unless represented?.(parent) do
        raise "job #{inspect(job)} has unknown lineage parent #{inspect(parent)}"
      end
    end)
  end

  defp validate_alias_target!({job, canonical_job}, represented?) do
    unless represented?.(canonical_job) do
      raise "job #{inspect(job)} has invalid canonical lineage #{inspect(canonical_job)}"
    end
  end

  @doc "Returns true when `job_id` is the owner job or one of its descendants."
  @spec descendant_or_self?(integer(), integer()) :: boolean()
  def descendant_or_self?(job_id, owner_job_id) do
    with {:ok, job} <- AvailableJobs.job_id_to_name(job_id),
         {:ok, owner} <- AvailableJobs.job_id_to_name(owner_job_id) do
      descendant_or_self?(job, owner, MapSet.new())
    else
      _unknown_job -> false
    end
  end

  defp descendant_or_self?(job, owner, seen) do
    job = normalize(job)
    owner = normalize(owner)

    cond do
      job == owner ->
        true

      MapSet.member?(seen, job) ->
        false

      true ->
        seen = MapSet.put(seen, job)
        Enum.any?(Map.get(@parents, job, []), &descendant_or_self?(&1, owner, seen))
    end
  end

  defp validate_acyclic!(parents, aliases, roots) do
    edges = Map.merge(parents, Map.new(aliases, fn {job, target} -> {job, [target]} end))
    nodes = Map.keys(edges) ++ MapSet.to_list(roots)

    _colors =
      Enum.reduce(nodes, %{}, fn node, colors ->
        visit!(node, edges, colors, [])
      end)

    :ok
  end

  defp visit!(node, edges, colors, path) do
    case Map.get(colors, node) do
      :black ->
        colors

      :gray ->
        cycle_start = Enum.find_index(path, &(&1 == node))
        cycle = Enum.drop(path, cycle_start) ++ [node]
        raise "JobLineage cycle detected: #{Enum.map_join(cycle, " -> ", &inspect/1)}"

      nil ->
        colors = Map.put(colors, node, :gray)
        path = path ++ [node]

        colors =
          Enum.reduce(Map.get(edges, node, []), colors, fn target, acc ->
            visit!(target, edges, acc, path)
          end)

        Map.put(colors, node, :black)
    end
  end

  defp normalize(job), do: Map.get(@aliases, job, job)
end
