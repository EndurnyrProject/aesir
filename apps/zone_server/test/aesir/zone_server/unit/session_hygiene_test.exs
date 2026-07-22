defmodule Aesir.ZoneServer.Unit.SessionHygieneTest do
  @moduledoc """
  Guards the session catch-all/skill-alias invariants added by the session
  restructure (spec `2026-07-22-session-genserver-restructure`):

    * neither session GenServer may crash on an unrecognized cast/info - the
      permanent logging catch-alls at the bottom of each clause group must log
      and drop instead of raising a `FunctionClauseError`;
    * neither session source may reference a concrete `Mmo.Skills.` module - the
      deferred-skill seam replaced the per-skill session clauses with one generic
      `{:skill_deferred, module, payload}` dispatch, so no skill module is named
      in either session.
  """

  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence

  @mob_session_source File.read!(
                        Path.join(
                          __DIR__,
                          "../../../../lib/aesir/zone_server/unit/mob/mob_session.ex"
                        )
                      )

  @player_session_source File.read!(
                           Path.join(
                             __DIR__,
                             "../../../../lib/aesir/zone_server/unit/player/player_session.ex"
                           )
                         )

  setup :verify_on_exit!
  setup :set_mimic_from_context

  describe "skill-alias guard" do
    test "mob session references no Mmo.Skills. module" do
      refute @mob_session_source =~ "Mmo.Skills."
    end

    test "player session references no Mmo.Skills. module" do
      refute @player_session_source =~ "Mmo.Skills."
    end
  end

  describe "handle_cast catch-all" do
    test "an unknown cast to a live mob session logs and keeps it alive" do
      mob = start_mob_session()

      log =
        capture_log(fn ->
          GenServer.cast(mob.pid, :totally_unknown_cast)
          :sys.get_state(mob.pid)
        end)

      assert log =~ "received unknown cast"
      assert log =~ inspect(mob.unit_id)
      assert Process.alive?(mob.pid)
    end

    test "an unknown cast to a live player session logs and keeps it alive" do
      %{pid: pid, character: character} = start_hygiene_player_session()

      log =
        capture_log(fn ->
          GenServer.cast(pid, :totally_unknown_cast)
          :sys.get_state(pid)
        end)

      assert log =~ "received unknown cast"
      assert log =~ inspect(character.id)
      assert Process.alive?(pid)
    end
  end

  describe "handle_info catch-all" do
    test "an unknown info to a live mob session logs and keeps it alive" do
      mob = start_mob_session()

      log =
        capture_log(fn ->
          send(mob.pid, :totally_unknown_info)
          :sys.get_state(mob.pid)
        end)

      assert log =~ "received unknown info"
      assert log =~ inspect(mob.unit_id)
      assert Process.alive?(mob.pid)
    end

    test "an unknown info to a live player session logs and keeps it alive" do
      %{pid: pid, character: character} = start_hygiene_player_session()

      log =
        capture_log(fn ->
          send(pid, :totally_unknown_info)
          :sys.get_state(pid)
        end)

      assert log =~ "received unknown info"
      assert log =~ inspect(character.id)
      assert Process.alive?(pid)
    end
  end

  defp start_hygiene_player_session do
    Mimic.copy(Persistence)
    Mimic.copy(StatusPersistence)
    Mimic.copy(QuestPersistence)
    Mimic.copy(CharacterPersistence)

    stub(Persistence, :load_inventory, fn _char_id -> [] end)
    stub(StatusPersistence, :restore_on_spawn, fn state -> state end)
    stub(StatusPersistence, :save_statuses, fn _char_id -> :ok end)
    stub(QuestPersistence, :load_on_spawn, fn state -> state end)
    stub(CharacterPersistence, :update_position, fn _id, _x, _y, _map -> {:ok, %Character{}} end)

    character = %Character{
      id: :erlang.unique_integer([:positive]),
      account_id: 100,
      name: "HygieneTestPlayer",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      class: 1,
      base_level: 1,
      job_level: 1,
      sex: "M"
    }

    {:ok, pid} = PlayerSession.start_link(%{character: character, connection_pid: self()})

    %{pid: pid, character: character}
  end
end
