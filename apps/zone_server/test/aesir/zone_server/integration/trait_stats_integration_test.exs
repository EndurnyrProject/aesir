defmodule Aesir.ZoneServer.Integration.TraitStatsIntegrationTest do
  @moduledoc """
  End-to-end coverage for the SP-B renewal trait-stat lifecycle on the real
  stack. Every step drives the live session/handler/stat/combat/persistence
  subsystems (no re-stubbing of units already unit-tested):

    1. A rune_knight at base 200 / job 70 changes into dragon_knight through the
       live `JobChange` broadcast: the change is gated by `TraitJobs`, grants +7
       trait points, and sets AP full (`ap == max_ap`, `max_ap > 0`).
    2. An ineligible rune_knight (job level below the parent max) is rejected
       with `:requirements_not_met` and nothing mutates.
    3. Leveling the dragon_knight 200 -> 205 accrues the cumulative trait-point
       delta (19), so the pool becomes `7 + 19`.
    4. Allocating POW from the trait-point pool raises the persisted `pow` column
       and lifts the recomputed combat stats through the patk multiplier path
       (base ATK +5*POW, patk +div(POW, 3)).
    5. `@resetstat` zeroes the trait stats and restores the pool to
       `trait_points_at(level) + 7`.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.StatusParams
  alias Aesir.Net.StatUp
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.JobManagement.JobChange
  alias Aesir.ZoneServer.Mmo.StatPoint
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Phoenix.PubSub

  # rAthena class ids: 4054 rune_knight (3rd), 4252 dragon_knight (4th/trait).
  @rune_knight 4054
  @dragon_knight 4252

  describe "trait-stat lifecycle" do
    test "change, accrue, allocate, and reset drive the full trait-point pool" do
      %{pid: pid, character: char} =
        start_char(class: @rune_knight, base_level: 200, job_level: 70)

      char_id = char.id

      # 1. Eligible 4th-job change: +7 trait points, AP filled to max.
      :ok = JobChange.request(char_id, @dragon_knight)
      changed = get_player_state(pid)

      assert changed.stats.progression.job_id == @dragon_knight
      assert changed.stats.progression.trait_point == 7
      assert changed.stats.derived_stats.max_ap > 0
      assert changed.stats.current_state.ap == changed.stats.derived_stats.max_ap
      assert Repo.get(Character, char_id).trait_point == 7

      # 3. Level 200 -> 205 accrues the cumulative table delta (7 + 19 == 26).
      GenServer.cast(pid, {:progression, {:add_base_level, 5}})
      leveled = get_player_state(pid)

      assert leveled.stats.progression.base_level == 205
      assert leveled.stats.progression.trait_point == 7 + 19
      assert leveled.stats.progression.trait_point == 7 + StatPoint.trait_gain(200, 205)

      # 4. Allocate POW from the trait pool: persisted row + measurable combat lift.
      patk_before = leveled.stats.combat_stats.patk
      atk_before = leveled.stats.combat_stats.atk

      simulate_incoming_message(pid, %StatUp{stat_id: StatusParams.pow(), amount: 6})
      allocated = get_player_state(pid)

      assert allocated.stats.base_stats.pow == 6
      assert allocated.stats.progression.trait_point == 26 - 6

      # Row 1 (base ATK += 5*POW) and row 5 (patk += div(POW, 3)) with CON 0.
      assert allocated.stats.combat_stats.atk == atk_before + 5 * 6
      assert allocated.stats.combat_stats.patk == patk_before + div(6, 3)

      persisted = Repo.get(Character, char_id)
      assert persisted.pow == 6
      assert persisted.trait_point == 20

      # 5. @resetstat restores the pool and zeroes the trait stats.
      PubSub.broadcast(Aesir.PubSub, "player:#{char_id}", {:progression, {:reset_stats}})
      reset = get_player_state(pid)

      assert reset.stats.base_stats.pow == 0
      assert reset.stats.progression.trait_point == StatPoint.trait_points_at(205) + 7
      assert Repo.get(Character, char_id).pow == 0
    end

    test "an ineligible change is rejected with :requirements_not_met and mutates nothing" do
      # Job level 69 is below the rune_knight parent max (70) -> ineligible.
      %{pid: pid, character: char} =
        start_char(class: @rune_knight, base_level: 200, job_level: 69)

      char_id = char.id

      before = get_player_state(pid)

      assert {:error, :requirements_not_met} =
               ProgressionHandler.apply_job_change(@dragon_knight, %{game_state: before})

      :ok = JobChange.request(char_id, @dragon_knight)
      after_state = get_player_state(pid)

      assert after_state.stats.progression.job_id == @rune_knight
      assert after_state.stats.progression.trait_point == 0
      assert Repo.get(Character, char_id).class == @rune_knight
      assert Repo.get(Character, char_id).trait_point == 0
    end
  end

  defp start_char(attrs) do
    character = insert_character(attrs)

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    Map.put(session, :character, character)
  end

  defp insert_character(attrs) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "trait#{uniq}",
        userid: "trait#{uniq}",
        user_pass: "password",
        email: "trait#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: "Trait#{uniq}",
            class: @rune_knight,
            base_level: 200,
            job_level: 70,
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
end
