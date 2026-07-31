defmodule Aesir.ZoneServer.Integration.ConsumableBuffsPhase2IntegrationTest do
  @moduledoc """
  End-to-end coverage for the Phase-2 consumable buff hooks (EXP rate, drop rate,
  death penalty), each driven through its real consumer with the backing status
  applied in the shared `StatusStorage`:

    1. `SC_EXPBOOST` (Battle Manual) - a `{:mob_kill_exp, base, job, race}` grant routed
       into the player's session yields the boosted base/job EXP via
       `ExperienceHandler`, measurably above an unbuffed control receiving the
       same grant.
    2. `SC_ITEMBOOST` (Bubble Gum) - the killer's merged `drop_rate` bonus is
       read exactly as `LootHandler.maybe_drop_items/2` reads it and threaded
       into `DropCalculator.roll/8`; a seeded RNG makes a borderline roll drop
       under the boost while the same seed drops nothing unbuffed.
    3. `SC_LIFEINSURANCE` (`no_death_penalty`) - a lethal blow through
       `HealthHandler` subtracts the renewal death EXP penalty without insurance
       and preserves EXP with it.

  Drives the real subsystems (status interpreter/storage, modifier calculator,
  experience/drop/health handlers, leveling). Only the network transport is faked
  by the `IntegrationCase` connection process.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.SessionState

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "SC_EXPBOOST" do
    test "a mob-kill EXP grant is boosted above an unbuffed control" do
      buffed =
        start_player_session(id: 9701, name: "Studious", base_level: 10, job_level: 5)

      control =
        start_player_session(id: 9702, name: "Plain", base_level: 10, job_level: 5)

      buffed_id = buffed.character.id
      on_exit(fn -> StatusInterpreter.remove_status(:player, buffed_id, :sc_expboost) end)

      # Battle Manual: +50% EXP, base bonus carries into job (job_exp_rate = 0).
      :ok =
        StatusInterpreter.apply_status(:player, buffed_id, :sc_expboost,
          val1: 50,
          duration: 1_800_000
        )

      flush_packets()

      # Default test mob grants 10 base / 5 job.
      send(buffed.pid, {:progression, {:mob_kill_exp, 10, 5, :formless}})
      send(control.pid, {:progression, {:mob_kill_exp, 10, 5, :formless}})

      buffed_prog = get_player_state(buffed.pid).stats.progression
      control_prog = get_player_state(control.pid).stats.progression

      # 10 * 150/100 = 15 base; 5 * 150/100 = 7 job.
      assert buffed_prog.base_exp == 15
      assert buffed_prog.job_exp == 7
      assert control_prog.base_exp == 10
      assert control_prog.job_exp == 5
      assert buffed_prog.base_exp > control_prog.base_exp
      assert buffed_prog.job_exp > control_prog.job_exp
      # Both grants stay far below the level-10 thresholds.
      assert buffed_prog.base_level == 10
    end
  end

  describe "SC_ITEMBOOST" do
    setup do
      stub(LevelPenalty, :drop, fn _mob_level, _killer_level -> 100 end)
      stub(MapCache, :walkable?, fn _map, _x, _y -> true end)

      stub(ItemManagement, :get_item_by_aegis, fn "Red_Potion" ->
        {:ok, %{id: 501, type: :healing}}
      end)

      :ok
    end

    test "the killer's drop bonus lifts a borderline roll into a drop" do
      player = start_player_session(id: 9703, name: "Lucky")
      char_id = player.character.id
      on_exit(fn -> StatusInterpreter.remove_status(:player, char_id, :sc_itemboost) end)

      # Bubble Gum: +100% drop rate.
      :ok =
        StatusInterpreter.apply_status(:player, char_id, :sc_itemboost,
          val1: 100,
          duration: 900_000
        )

      # Read the bonus exactly as `LootHandler.maybe_drop_items/2` does.
      drop_bonus =
        :player |> ModifierCalculator.get_all_modifiers(char_id) |> Map.get(:drop_rate, 0)

      assert drop_bonus == 100

      drops = [%MobDrop{item: "Red_Potion", rate: 4_000}]

      # Seed {2, 3, 4}: the first roll is 4508 - above the unbuffed 40% rate but
      # within the boosted 80% rate, so the boost is the only reason it drops.
      :rand.seed(:exsss, {2, 3, 4})
      unbuffed = DropCalculator.roll(drops, 0, 1, 1, 0, "prontera", 150, 150)

      :rand.seed(:exsss, {2, 3, 4})
      boosted = DropCalculator.roll(drops, 0, 1, 1, drop_bonus, "prontera", 150, 150)

      assert unbuffed == []
      assert [{501, 1, _x, _y, true}] = boosted
    end
  end

  describe "SC_LIFEINSURANCE" do
    setup do
      assert Config.death_penalty_base() > 0
      assert Config.death_penalty_job() > 0
      :ok
    end

    test "dying without insurance subtracts the renewal death EXP penalty" do
      player = start_player_session(id: 9704, name: "Mortal", base_level: 50, job_level: 8)
      {progression, base_loss, job_loss} = seed_exp_and_expected_loss(player)

      assert base_loss > 0
      assert job_loss > 0

      dead = kill(player)

      assert dead.stats.progression.base_exp == progression.base_exp - base_loss
      assert dead.stats.progression.job_exp == progression.job_exp - job_loss
    end

    test "dying with SC_LIFEINSURANCE preserves EXP" do
      player = start_player_session(id: 9705, name: "Insured", base_level: 50, job_level: 8)
      char_id = player.character.id
      on_exit(fn -> StatusInterpreter.remove_status(:player, char_id, :sc_lifeinsurance) end)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, :sc_lifeinsurance, duration: 1_200_000)

      {progression, base_loss, job_loss} = seed_exp_and_expected_loss(player)
      assert base_loss > 0 and job_loss > 0

      dead = kill(player)

      assert dead.stats.progression.base_exp == progression.base_exp
      assert dead.stats.progression.job_exp == progression.job_exp
    end
  end

  # Grants half a level of base/job EXP (guaranteed no level-up), then returns the
  # resulting progression and the EXP the death penalty is expected to remove.
  defp seed_exp_and_expected_loss(player) do
    progression0 = get_player_state(player.pid).stats.progression
    grant_base = div(Leveling.next_base_exp(progression0), 2)
    grant_job = div(Leveling.next_job_exp(progression0), 2)

    send(player.pid, {:progression, {:mob_kill_exp, grant_base, grant_job, :formless}})

    progression = get_player_state(player.pid).stats.progression
    assert progression.base_exp == grant_base
    assert progression.job_exp == grant_job

    {base_loss, job_loss} =
      Leveling.death_penalty(progression, Config.death_penalty_base(), Config.death_penalty_job())

    {progression, base_loss, job_loss}
  end

  defp kill(player) do
    state = %SessionState{
      game_state: get_player_state(player.pid),
      connection_pid: player.connection_pid
    }

    {:noreply, dead} = HealthHandler.apply_damage(9_999, nil, state)
    dead.game_state
  end
end
