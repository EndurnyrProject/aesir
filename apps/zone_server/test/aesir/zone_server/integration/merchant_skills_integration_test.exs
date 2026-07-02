defmodule Aesir.ZoneServer.Integration.MerchantSkillsIntegrationTest do
  @moduledoc """
  End-to-end coverage that the Merchant combat & utility kit (MC_INCCARRY,
  MC_MAMMONITE, MC_LOUD) is playable on the real stack, mirroring the cart
  subsystem integration coverage. Every step drives the live session/handler/
  status/combat/persistence subsystems:

    1. Enlarge Weight Limit — learning MC_INCCARRY to level 5 through the live
       learning flow raises `Weight.max_weight/1` by `10_000` over the base,
       via the real passive aggregation + stat recalc pipeline.
    2. Crazy Uproar — a real `SkillCast` request drives the timed-cast ->
       cast-complete -> commit pipeline; `SC_LOUD` lands in `StatusStorage` and
       the post-commit stat recalc raises effective STR by 4.
    3. Mammonite — a real `SkillCast` request against a mob deals weapon
       damage (`Combat.execute_skill_attack`) and debits + persists 100 zeny
       (`CharacterPersistence.update_character`, inline in the test sandbox).
    4. Mammonite with insufficient zeny — the real `Interpreter.cast/4` entry
       point (the same synchronous wrapper the session driver's instant-cast
       path calls internally) fails with `{:error, :insufficient_zeny}`, spends
       no zeny, and no damage is dealt.

  ## Scoping

  - MC_LOUD's `Effects.Loud` grants `%{str: 4, watk: 30}` (rAthena's `+4 STR,
    +30 batk`). Effective STR is wired through `Stats.get_effective_stat/2` and
    is asserted directly. The `:watk` bonus (shared with `Effects.Impositio`)
    lands in `modifiers.status_effects`, is readable via
    `Stats.get_status_modifier/2` (asserted here), and flows into melee/skill
    damage as flat weapon ATK via `DamageCalculator`'s status-effect damage
    modifiers — the `:watk`-reaches-damage wiring is proven deterministically in
    `damage_calculator_test.exs` ("adds flat weapon ATK (:watk) granted by
    statuses").
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCooldown
  alias Aesir.Net.SkillDamage
  alias Aesir.Net.SkillList
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.Stats

  # rAthena class id for the 1st-class Merchant; PlayerState derives job_id from it.
  @merchant_class 5

  describe "MC_INCCARRY (Enlarge Weight Limit)" do
    test "learning level 5 raises max_weight by 10000 over the base" do
      %{pid: pid} = start_merchant()

      base_max_weight = Weight.max_weight(get_player_state(pid).stats)

      inccarry = catalog_id(:mc_inccarry)
      for _ <- 1..5, do: learn(pid, inccarry)

      boosted_max_weight = Weight.max_weight(get_player_state(pid).stats)

      assert boosted_max_weight == base_max_weight + 10_000
    end
  end

  describe "MC_LOUD (Crazy Uproar)" do
    test "casting applies SC_LOUD and the stat recalc shows +4 STR and +30 batk" do
      %{pid: pid, character: char} = start_merchant()

      on_exit(fn -> StatusStorage.remove_status(:player, char.id, :sc_loud) end)

      loud = catalog_id(:mc_loud)
      learn(pid, loud)
      flush_packets()

      str_before = Stats.get_effective_stat(get_player_state(pid).stats, :str)

      simulate_incoming_message(pid, %SkillCast{
        skill_id: loud,
        level: 1,
        target_id: char.id
      })

      # The cooldown sweep is the last packet commit_cast emits, so waiting on
      # it serializes past the full timed-cast -> commit -> stat-recalc pipeline.
      assert_receive {:packet_sent, %SkillCooldown{skill_id: ^loud, tick: 30_000}, _}, 2_000

      assert StatusStorage.has_status?(:player, char.id, :sc_loud)

      after_stats = get_player_state(pid).stats
      assert Stats.get_effective_stat(after_stats, :str) == str_before + 4
      assert Stats.get_status_modifier(after_stats, :watk) == 30
    end
  end

  describe "MC_MAMMONITE (Mammonite)" do
    test "level 1 on a mob deals weapon damage and deducts 100 zeny from the caster" do
      %{pid: pid, character: char} = start_merchant(zeny: 1_000)

      mob =
        start_mob_session(unit_id: 96_101, map_name: "prontera", position: {151, 150}, hp: 5_000)

      mob_id = mob.unit_id

      mammonite = catalog_id(:mc_mammonite)
      learn(pid, mammonite)
      flush_packets()

      simulate_incoming_message(pid, %SkillCast{
        skill_id: mammonite,
        level: 1,
        target_id: mob_id
      })

      assert_receive {:packet_sent,
                      %SkillDamage{skill_id: ^mammonite, target_id: ^mob_id, damage: damage}, _},
                     1_000

      assert damage > 0

      assert get_player_state(pid).zeny == 900
      assert Repo.get(Character, char.id).zeny == 900
    end

    test "insufficient zeny fails with {:error, :insufficient_zeny} and deals no damage" do
      %{pid: pid, character: char} = start_merchant(zeny: 50)

      mob =
        start_mob_session(unit_id: 96_102, map_name: "prontera", position: {151, 150}, hp: 5_000)

      mob_id = mob.unit_id

      mammonite = catalog_id(:mc_mammonite)
      learn(pid, mammonite)
      flush_packets()

      caster_state = get_player_state(pid)

      assert {:error, :insufficient_zeny} =
               Interpreter.cast(caster_state, mammonite, 1, {:unit, mob_id})

      refute_receive {:packet_sent, %SkillDamage{skill_id: ^mammonite}, _}, 200

      assert get_player_state(pid).zeny == 50
      assert Repo.get(Character, char.id).zeny == 50
    end
  end

  defp start_merchant(opts \\ []) do
    zeny = Keyword.get(opts, :zeny, 1_000)

    character = insert_merchant(zeny: zeny, skill_point: 20)

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    flush_packets()

    Map.put(session, :character, character)
  end

  defp insert_merchant(attrs) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "merchant#{uniq}",
        userid: "merchant#{uniq}",
        user_pass: "password",
        email: "merchant#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: "Trader#{uniq}",
            class: @merchant_class,
            base_level: 50,
            job_level: 50,
            str: 10,
            agi: 10,
            vit: 10,
            int: 10,
            dex: 10,
            luk: 10,
            last_map: "prontera",
            last_x: 150,
            last_y: 150,
            save_map: "prontera",
            save_x: 150,
            save_y: 150
          },
          Map.new(attrs)
        )
      )
      |> Repo.insert()

    character
  end

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp learn(pid, skill_id) do
    simulate_incoming_message(pid, %LearnSkill{skill_id: skill_id})
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
  end
end
