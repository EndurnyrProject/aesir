defmodule Aesir.ZoneServer.Unit.SessionHygieneTest do
  @moduledoc """
  Guards the session catch-all/skill-alias invariants added by the session
  restructure (spec `2026-07-22-session-genserver-restructure`):

    * neither session GenServer may crash on an unrecognized cast/info - the
      permanent logging catch-alls at the bottom of each clause group must log
      and drop instead of raising a `FunctionClauseError`;
    * neither session source may reference a concrete `Mmo.Skills.` module - the
      deferred-skill seam replaced the per-skill session clauses with one generic
      `{:skill, {:deferred, module, payload}}` dispatch, so no skill module is
      named in either session;
    * the source guard permits only `Homunculus.StateCommit` to replace the
      aggregate's nested `homunculus` field directly.
  """

  use ExUnit.Case, async: false
  use Mimic

  import ExUnit.CaptureLog
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  defmodule DeferredProbe do
    @moduledoc false

    def deferred(test_pid, _state), do: send(test_pid, :deferred_ran)
  end

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

  @zone_server_sources Path.wildcard(
                         Path.join(__DIR__, "../../../../lib/aesir/zone_server/**/*.ex")
                       )

  @homunculus_state_commit_source Path.join(
                                    __DIR__,
                                    "../../../../lib/aesir/zone_server/unit/homunculus/state_commit.ex"
                                  )

  @homunculus_replacement_patterns [
    ~r/%\{\s*[^}]*\|\s*[^}]*\bhomunculus\s*:/s,
    ~r/%SessionState\s*\{[^}]*\bhomunculus\s*:/s,
    ~r/Map\.(?:put|replace|replace!|update|update!)\s*\([^)]*,\s*:homunculus\s*,/s,
    ~r/(?:put_in|update_in)\s*\([^,]*\.homunculus(?:\.\w+)*\s*,/s,
    ~r/(?:put_in|update_in)\s*\([^,]*,\s*\[\s*:homunculus(?:\s*,[^\]]+)*\]\s*,/s
  ]

  setup :verify_on_exit!
  setup :set_mimic_from_context

  describe "skill-alias guard" do
    test "mob session references no Mmo.Skills. module" do
      refute @mob_session_source =~ "Mmo.Skills."
    end

    test "player session references no Mmo.Skills. module" do
      refute @player_session_source =~ "Mmo.Skills."
    end

    test "recognizes the guarded direct replacement forms" do
      [struct_update, session_construction, map_replacement, dot_path_update, key_path_update] =
        @homunculus_replacement_patterns

      assert Regex.match?(struct_update, "%{session | other: value, homunculus: value}")
      assert Regex.match?(session_construction, "%SessionState{other: value, homunculus: value}")

      for function <- ["put", "replace", "replace!", "update", "update!"] do
        assert Regex.match?(map_replacement, "Map.#{function}(session, :homunculus, value)")
      end

      assert Regex.match?(dot_path_update, "put_in(session.homunculus, value)")
      assert Regex.match?(dot_path_update, "update_in(session.homunculus.hp, & &1)")
      assert Regex.match?(key_path_update, "put_in(session, [:homunculus], value)")
      assert Regex.match?(key_path_update, "update_in(session, [:homunculus, :hp], & &1)")
    end

    test "Homunculus StateCommit is the only guarded direct replacement path" do
      assert [@homunculus_state_commit_source] ==
               Enum.filter(@zone_server_sources, fn path ->
                 source = File.read!(path)
                 Enum.any?(@homunculus_replacement_patterns, &Regex.match?(&1, source))
               end)
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

  describe "disconnect cleanup" do
    test "finite song state and queued deferred work do not outlive the player session" do
      %{pid: pid, character: character} = start_hygiene_player_session()
      monitor = Process.monitor(pid)

      assert :ok =
               StatusInterpreter.apply_status(:player, character.id, :sc_whistle,
                 duration: 180_000,
                 caster_id: character.id
               )

      assert StatusStorage.has_status?(:player, character.id, :sc_whistle)
      Process.send_after(pid, {:skill, {:deferred, DeferredProbe, self()}}, 100)
      send(pid, :connection_closed)

      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 1_000
      refute StatusStorage.has_status?(:player, character.id, :sc_whistle)
      assert {:error, :not_found} = UnitRegistry.get_unit(:player, character.id)
      refute_receive :deferred_ran, 150
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
      last_map: "session_hygiene_map",
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
