defmodule Aesir.ZoneServer.Mmo.JobManagement.JobMapid do
  @moduledoc """
  The "mapid" job-number system behind the `eaclass`/`roclass` script commands.

  A mapid is a bitfield that packs a job's first-job base, its branch
  (2-1 / 2-2 / third / fourth) and its version (transcendent / baby) into one
  integer, so scripts can bit-test and flip those traits (`eaclass() & EAJL_2`,
  `roclass(eaclass() | EAJL_THIRD)`). The layout mirrors the client-side job
  tree: the low byte is the first-job index, then branch bits (`0x100`,
  `0x200`, `0x1000`, `0x10000`) and version bits (`0x100000`, `0x200000`).

  This module is the single source of truth for the atom↔mapid conversion and
  for the `EAJ_*`/`EAJL_*` script constants. The id↔atom half reuses
  `AvailableJobs` (the canonical job catalog), so only the atom→mapid table is
  declared here.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs

  @flag_bits %{
    "EAJL_2_1" => 0x100,
    "EAJL_2_2" => 0x200,
    "EAJL_2" => 0x300,
    "EAJL_THIRD" => 0x1000,
    "EAJL_FOURTH" => 0x10000,
    "EAJL_UPPER" => 0x100000,
    "EAJL_BABY" => 0x200000,
    "EAJ_BASEMASK" => 0xFF,
    "EAJ_UPPERMASK" => 0xFFF,
    "EAJ_THIRDMASK" => 0xFFFF,
    "EAJ_FOURTHMASK" => 0xFFFFF
  }

  # First job → base index (the low byte of the mapid).
  @base_index %{
    novice: 0x0,
    swordman: 0x1,
    mage: 0x2,
    archer: 0x3,
    acolyte: 0x4,
    merchant: 0x5,
    thief: 0x6,
    taekwon: 0x7,
    gunslinger: 0x8,
    ninja: 0x9,
    summoner: 0xA,
    gangsi: 0xB,
    wedding: 0xC,
    xmas: 0xD,
    summer: 0xE,
    hanbok: 0xF,
    oktoberfest: 0x10,
    summer2: 0x11
  }

  # Branch/version bitmasks.
  @l2_1 0x100
  @l2_2 0x200
  @l_third 0x1000
  @l_fourth 0x10000
  @l_upper 0x100000
  @l_baby 0x200000

  # The canonical atom → mapid table. Every entry is `@base_index | branch |
  # version`. Sex-paired jobs (bard/dancer, kagerou/oboro, …) share one mapid
  # and resolve through `@pairs`.
  @atom_to_mapid %{
    # Novice + first jobs
    novice: @base_index[:novice],
    swordman: @base_index[:swordman],
    mage: @base_index[:mage],
    archer: @base_index[:archer],
    acolyte: @base_index[:acolyte],
    merchant: @base_index[:merchant],
    thief: @base_index[:thief],
    taekwon: @base_index[:taekwon],
    gunslinger: @base_index[:gunslinger],
    ninja: @base_index[:ninja],
    summoner: @base_index[:summoner],
    gangsi: @base_index[:gangsi],
    wedding: @base_index[:wedding],
    xmas: @base_index[:xmas],
    summer: @base_index[:summer],
    hanbok: @base_index[:hanbok],
    oktoberfest: @base_index[:oktoberfest],
    summer2: @base_index[:summer2],
    # 2-1 jobs
    super_novice: @l2_1,
    knight: @l2_1 + @base_index[:swordman],
    wizard: @l2_1 + @base_index[:mage],
    hunter: @l2_1 + @base_index[:archer],
    priest: @l2_1 + @base_index[:acolyte],
    blacksmith: @l2_1 + @base_index[:merchant],
    assassin: @l2_1 + @base_index[:thief],
    star_gladiator: @l2_1 + @base_index[:taekwon],
    rebellion: @l2_1 + @base_index[:gunslinger],
    kagerou: @l2_1 + @base_index[:ninja],
    oboro: @l2_1 + @base_index[:ninja],
    spirit_handler: @l2_1 + @base_index[:summoner],
    death_knight: @l2_1 + @base_index[:gangsi],
    # 2-2 jobs
    crusader: @l2_2 + @base_index[:swordman],
    sage: @l2_2 + @base_index[:mage],
    bard: @l2_2 + @base_index[:archer],
    dancer: @l2_2 + @base_index[:archer],
    monk: @l2_2 + @base_index[:acolyte],
    alchemist: @l2_2 + @base_index[:merchant],
    rogue: @l2_2 + @base_index[:thief],
    soul_linker: @l2_2 + @base_index[:taekwon],
    dark_collector: @l2_2 + @base_index[:gangsi],
    # Transcendent novice + first jobs
    novice_high: @l_upper + @base_index[:novice],
    swordman_high: @l_upper + @base_index[:swordman],
    mage_high: @l_upper + @base_index[:mage],
    archer_high: @l_upper + @base_index[:archer],
    acolyte_high: @l_upper + @base_index[:acolyte],
    merchant_high: @l_upper + @base_index[:merchant],
    thief_high: @l_upper + @base_index[:thief],
    # Transcendent 2-1 jobs
    lord_knight: @l_upper + @l2_1 + @base_index[:swordman],
    high_wizard: @l_upper + @l2_1 + @base_index[:mage],
    sniper: @l_upper + @l2_1 + @base_index[:archer],
    high_priest: @l_upper + @l2_1 + @base_index[:acolyte],
    whitesmith: @l_upper + @l2_1 + @base_index[:merchant],
    assassin_cross: @l_upper + @l2_1 + @base_index[:thief],
    # Transcendent 2-2 jobs
    paladin: @l_upper + @l2_2 + @base_index[:swordman],
    professor: @l_upper + @l2_2 + @base_index[:mage],
    clown: @l_upper + @l2_2 + @base_index[:archer],
    gypsy: @l_upper + @l2_2 + @base_index[:archer],
    champion: @l_upper + @l2_2 + @base_index[:acolyte],
    creator: @l_upper + @l2_2 + @base_index[:merchant],
    stalker: @l_upper + @l2_2 + @base_index[:thief],
    # Baby novice + first jobs
    baby: @l_baby + @base_index[:novice],
    baby_swordman: @l_baby + @base_index[:swordman],
    baby_mage: @l_baby + @base_index[:mage],
    baby_archer: @l_baby + @base_index[:archer],
    baby_acolyte: @l_baby + @base_index[:acolyte],
    baby_merchant: @l_baby + @base_index[:merchant],
    baby_thief: @l_baby + @base_index[:thief],
    baby_taekwon: @l_baby + @base_index[:taekwon],
    baby_gunslinger: @l_baby + @base_index[:gunslinger],
    baby_ninja: @l_baby + @base_index[:ninja],
    baby_summoner: @l_baby + @base_index[:summoner],
    # Baby 2-1 jobs
    super_baby: @l_baby + @l2_1 + @base_index[:novice],
    baby_knight: @l_baby + @l2_1 + @base_index[:swordman],
    baby_wizard: @l_baby + @l2_1 + @base_index[:mage],
    baby_hunter: @l_baby + @l2_1 + @base_index[:archer],
    baby_priest: @l_baby + @l2_1 + @base_index[:acolyte],
    baby_blacksmith: @l_baby + @l2_1 + @base_index[:merchant],
    baby_assassin: @l_baby + @l2_1 + @base_index[:thief],
    baby_star_gladiator: @l_baby + @l2_1 + @base_index[:taekwon],
    baby_rebellion: @l_baby + @l2_1 + @base_index[:gunslinger],
    baby_kagerou: @l_baby + @l2_1 + @base_index[:ninja],
    baby_oboro: @l_baby + @l2_1 + @base_index[:ninja],
    # Baby 2-2 jobs
    baby_crusader: @l_baby + @l2_2 + @base_index[:swordman],
    baby_sage: @l_baby + @l2_2 + @base_index[:mage],
    baby_bard: @l_baby + @l2_2 + @base_index[:archer],
    baby_dancer: @l_baby + @l2_2 + @base_index[:archer],
    baby_monk: @l_baby + @l2_2 + @base_index[:acolyte],
    baby_alchemist: @l_baby + @l2_2 + @base_index[:merchant],
    baby_rogue: @l_baby + @l2_2 + @base_index[:thief],
    baby_soul_linker: @l_baby + @l2_2 + @base_index[:taekwon],
    # 3-1 jobs
    super_novice_e: @l_third + @l2_1 + @base_index[:novice],
    rune_knight: @l_third + @l2_1 + @base_index[:swordman],
    warlock: @l_third + @l2_1 + @base_index[:mage],
    ranger: @l_third + @l2_1 + @base_index[:archer],
    arch_bishop: @l_third + @l2_1 + @base_index[:acolyte],
    mechanic: @l_third + @l2_1 + @base_index[:merchant],
    guillotine_cross: @l_third + @l2_1 + @base_index[:thief],
    star_emperor: @l_third + @l2_1 + @base_index[:taekwon],
    night_watch: @l_third + @l2_1 + @base_index[:gunslinger],
    shinkiro: @l_third + @l2_1 + @base_index[:ninja],
    shiranui: @l_third + @l2_1 + @base_index[:ninja],
    # 3-2 jobs
    royal_guard: @l_third + @l2_2 + @base_index[:swordman],
    sorcerer: @l_third + @l2_2 + @base_index[:mage],
    minstrel: @l_third + @l2_2 + @base_index[:archer],
    wanderer: @l_third + @l2_2 + @base_index[:archer],
    sura: @l_third + @l2_2 + @base_index[:acolyte],
    genetic: @l_third + @l2_2 + @base_index[:merchant],
    shadow_chaser: @l_third + @l2_2 + @base_index[:thief],
    soul_reaper: @l_third + @l2_2 + @base_index[:taekwon],
    # Transcendent 3-1 jobs
    rune_knight_t: @l_third + @l_upper + @l2_1 + @base_index[:swordman],
    warlock_t: @l_third + @l_upper + @l2_1 + @base_index[:mage],
    ranger_t: @l_third + @l_upper + @l2_1 + @base_index[:archer],
    arch_bishop_t: @l_third + @l_upper + @l2_1 + @base_index[:acolyte],
    mechanic_t: @l_third + @l_upper + @l2_1 + @base_index[:merchant],
    guillotine_cross_t: @l_third + @l_upper + @l2_1 + @base_index[:thief],
    # Transcendent 3-2 jobs
    royal_guard_t: @l_third + @l_upper + @l2_2 + @base_index[:swordman],
    sorcerer_t: @l_third + @l_upper + @l2_2 + @base_index[:mage],
    minstrel_t: @l_third + @l_upper + @l2_2 + @base_index[:archer],
    wanderer_t: @l_third + @l_upper + @l2_2 + @base_index[:archer],
    sura_t: @l_third + @l_upper + @l2_2 + @base_index[:acolyte],
    genetic_t: @l_third + @l_upper + @l2_2 + @base_index[:merchant],
    shadow_chaser_t: @l_third + @l_upper + @l2_2 + @base_index[:thief],
    # Baby 3-1 jobs
    super_baby_e: @l_third + @l_baby + @l2_1 + @base_index[:novice],
    baby_rune_knight: @l_third + @l_baby + @l2_1 + @base_index[:swordman],
    baby_warlock: @l_third + @l_baby + @l2_1 + @base_index[:mage],
    baby_ranger: @l_third + @l_baby + @l2_1 + @base_index[:archer],
    baby_arch_bishop: @l_third + @l_baby + @l2_1 + @base_index[:acolyte],
    baby_mechanic: @l_third + @l_baby + @l2_1 + @base_index[:merchant],
    baby_guillotine_cross: @l_third + @l_baby + @l2_1 + @base_index[:thief],
    baby_star_emperor: @l_third + @l_baby + @l2_1 + @base_index[:taekwon],
    # Baby 3-2 jobs
    baby_royal_guard: @l_third + @l_baby + @l2_2 + @base_index[:swordman],
    baby_sorcerer: @l_third + @l_baby + @l2_2 + @base_index[:mage],
    baby_minstrel: @l_third + @l_baby + @l2_2 + @base_index[:archer],
    baby_wanderer: @l_third + @l_baby + @l2_2 + @base_index[:archer],
    baby_sura: @l_third + @l_baby + @l2_2 + @base_index[:acolyte],
    baby_genetic: @l_third + @l_baby + @l2_2 + @base_index[:merchant],
    baby_shadow_chaser: @l_third + @l_baby + @l2_2 + @base_index[:thief],
    baby_soul_reaper: @l_third + @l_baby + @l2_2 + @base_index[:taekwon],
    # 4-1 jobs
    hyper_novice: @l_fourth + @l_third + @l2_1 + @base_index[:novice],
    dragon_knight: @l_fourth + @l_third + @l2_1 + @base_index[:swordman],
    arch_mage: @l_fourth + @l_third + @l2_1 + @base_index[:mage],
    windhawk: @l_fourth + @l_third + @l2_1 + @base_index[:archer],
    cardinal: @l_fourth + @l_third + @l2_1 + @base_index[:acolyte],
    meister: @l_fourth + @l_third + @l2_1 + @base_index[:merchant],
    shadow_cross: @l_fourth + @l_third + @l2_1 + @base_index[:thief],
    sky_emperor: @l_fourth + @l_third + @l2_1 + @base_index[:taekwon],
    # 4-2 jobs
    imperial_guard: @l_fourth + @l_third + @l2_2 + @base_index[:swordman],
    elemental_master: @l_fourth + @l_third + @l2_2 + @base_index[:mage],
    troubadour: @l_fourth + @l_third + @l2_2 + @base_index[:archer],
    trouvere: @l_fourth + @l_third + @l2_2 + @base_index[:archer],
    inquisitor: @l_fourth + @l_third + @l2_2 + @base_index[:acolyte],
    biolo: @l_fourth + @l_third + @l2_2 + @base_index[:merchant],
    abyss_chaser: @l_fourth + @l_third + @l2_2 + @base_index[:thief],
    soul_ascetic: @l_fourth + @l_third + @l2_2 + @base_index[:taekwon]
  }

  # Sex-paired jobs share one mapid; the reverse lookup picks by sex. Each entry
  # pairs the `EAJ_*` constant name with the `{male, female}` job atoms.
  @pairs %{
    (@l2_1 + @base_index[:ninja]) => {"EAJ_KAGEROUOBORO", {:kagerou, :oboro}},
    (@l2_2 + @base_index[:archer]) => {"EAJ_BARDDANCER", {:bard, :dancer}},
    (@l_upper + @l2_2 + @base_index[:archer]) => {"EAJ_CLOWNGYPSY", {:clown, :gypsy}},
    (@l_baby + @l2_1 + @base_index[:ninja]) =>
      {"EAJ_BABY_KAGEROUOBORO", {:baby_kagerou, :baby_oboro}},
    (@l_baby + @l2_2 + @base_index[:archer]) =>
      {"EAJ_BABY_BARDDANCER", {:baby_bard, :baby_dancer}},
    (@l_third + @l2_1 + @base_index[:ninja]) => {"EAJ_SHINKIROSHIRANUI", {:shinkiro, :shiranui}},
    (@l_third + @l2_2 + @base_index[:archer]) => {"EAJ_MINSTRELWANDERER", {:minstrel, :wanderer}},
    (@l_third + @l_upper + @l2_2 + @base_index[:archer]) =>
      {"EAJ_MINSTRELWANDERER_T", {:minstrel_t, :wanderer_t}},
    (@l_third + @l_baby + @l2_2 + @base_index[:archer]) =>
      {"EAJ_BABY_MINSTRELWANDERER", {:baby_minstrel, :baby_wanderer}},
    (@l_fourth + @l_third + @l2_2 + @base_index[:archer]) =>
      {"EAJ_TROUBADOURTROUVERE", {:troubadour, :trouvere}}
  }

  # Extra `EAJ_*` spellings rAthena exports alongside the canonical ones.
  @ea_aliases %{
    "EAJ_SUPERNOVICE" => "EAJ_SUPER_NOVICE",
    "EAJ_STARGLADIATOR" => "EAJ_STAR_GLADIATOR",
    "EAJ_SOULLINKER" => "EAJ_SOUL_LINKER",
    "EAJ_DEATHKNIGHT" => "EAJ_DEATH_KNIGHT",
    "EAJ_DARKCOLLECTOR" => "EAJ_DARK_COLLECTOR"
  }

  # The reverse direction: mapid → job atom or `{male, female}` pair.
  @mapid_to_job (
                  non_paired =
                    @atom_to_mapid
                    |> Enum.reject(fn {_atom, mapid} -> Map.has_key?(@pairs, mapid) end)
                    |> Map.new(fn {atom, mapid} -> {mapid, atom} end)

                  Map.merge(
                    non_paired,
                    Map.new(@pairs, fn {mapid, {_name, pair}} -> {mapid, pair} end)
                  )
                )

  # `EAJ_*` job constants: canonical name for every unpaired job, plus the
  # shared-pair names and aliases.
  @ea_job_constants (
                      paired_atoms =
                        @pairs
                        |> Enum.flat_map(fn {_mapid, {_name, {male, female}}} ->
                          [male, female]
                        end)
                        |> Map.new(fn atom -> {atom, true} end)

                      single =
                        @atom_to_mapid
                        |> Enum.reject(fn {atom, _mapid} -> Map.has_key?(paired_atoms, atom) end)
                        |> Map.new(fn {atom, mapid} ->
                          {"EAJ_" <> String.upcase(Atom.to_string(atom)), mapid}
                        end)

                      pair_names = Map.new(@pairs, fn {mapid, {name, _pair}} -> {name, mapid} end)

                      Map.merge(single, pair_names)
                    )

  # The full `EAJ_*`/`EAJL_*` constant table: flags/masks + job constants.
  @constants (
               aliased =
                 Map.new(@ea_aliases, fn {alias_name, canonical} ->
                   {alias_name, Map.fetch!(@ea_job_constants, canonical)}
                 end)

               @flag_bits |> Map.merge(@ea_job_constants) |> Map.merge(aliased)
             )

  @doc """
  The mapid for a job, given its atom or numeric id.

  Returns `-1` for an unknown job or for a job with no mapid equivalent (the
  mounted `*2` forms and the `max_basic`/`job_max` placeholders).
  """
  @spec from_job(atom() | integer()) :: integer()
  def from_job(job) when is_atom(job), do: Map.get(@atom_to_mapid, job, -1)

  def from_job(job_id) when is_integer(job_id) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, name} -> from_job(name)
      {:error, _} -> -1
    end
  end

  @doc """
  The numeric job id for a mapid, resolved against `sex`.

  `sex` follows the client convention (`0` female, non-zero male). Returns `-1`
  for an unknown mapid.
  """
  @spec to_job(integer(), integer()) :: integer()
  def to_job(mapid, sex) when is_integer(mapid) do
    case Map.get(@mapid_to_job, mapid) do
      {male, female} -> job_id(if sex == 0, do: female, else: male)
      nil -> -1
      atom -> job_id(atom)
    end
  end

  defp job_id(atom) do
    case AvailableJobs.job_name_to_id(atom) do
      {:ok, id} -> id
      {:error, _} -> -1
    end
  end

  @doc """
  Resolves an `EAJ_*`/`EAJL_*` script constant to its numeric mapid value.
  """
  @spec constant(String.t()) :: {:ok, integer()} | :error
  def constant(name) when is_binary(name), do: Map.fetch(@constants, name)

  @doc """
  Raises if the mapid table drifts from the canonical job catalog: every atom
  must resolve to a known job id, and the sex-pair table must agree with the
  atom table.
  """
  @spec validate!() :: :ok
  def validate! do
    Enum.each(Map.keys(@atom_to_mapid), fn atom ->
      unless match?({:ok, _}, AvailableJobs.job_name_to_id(atom)) do
        raise "job #{inspect(atom)} is absent from AvailableJobs"
      end
    end)

    Enum.each(@pairs, fn {mapid, {_name, {male, female}}} ->
      if Map.get(@atom_to_mapid, male) != mapid or Map.get(@atom_to_mapid, female) != mapid do
        raise "sex-paired mapid #{inspect(mapid)} disagrees with the atom table"
      end
    end)

    :ok
  end
end
