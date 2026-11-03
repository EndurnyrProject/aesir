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
    * each companion aggregate nested in `SessionState` (`@companion_fields`)
      may be replaced directly only by its own `StateCommit`; every other module
      goes through that commit path so world presence stays synchronized.
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
  alias Aesir.ZoneServer.Unit.Player.SkillCooldownPersistence
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

  # Companion aggregates nested in `SessionState`, each with the one source file
  # allowed to replace the field directly. Future companions (pet, mercenary)
  # add one entry here.
  @companion_fields %{
    homunculus: "unit/homunculus/state_commit.ex"
  }

  @map_writers [:put, :replace, :replace!, :update, :update!]
  @path_writers [:put_in, :update_in]

  setup :verify_on_exit!
  setup :set_mimic_from_context

  describe "skill-alias guard" do
    test "mob session references no Mmo.Skills. module" do
      refute @mob_session_source =~ "Mmo.Skills."
    end

    test "player session references no Mmo.Skills. module" do
      refute @player_session_source =~ "Mmo.Skills."
    end

    test "player session returns new game state only through StateCommit" do
      # Terminal `%{state | game_state: ...}` rebinds skip the registry and
      # party/guild sync. The one tolerated site is terminate/2, which has no
      # observers left.
      raw_rebinds =
        ~r/%\{state \| game_state:/
        |> Regex.scan(@player_session_source)
        |> length()

      assert raw_rebinds == 1
    end

    test "player session contains no Homunculus species or skill IDs" do
      for id <- 6_001..6_016, do: refute(@player_session_source =~ Integer.to_string(id))
      for id <- 8_001..8_016, do: refute(@player_session_source =~ Integer.to_string(id))
    end

    test "every Homunculus mailbox shape delegates through its namespace" do
      assert @player_session_source =~
               "handle_info({:timeout, ref, {:homunculus, event}}, state)"

      assert @player_session_source =~ "handle_cast({:homunculus, command}, state)"
      assert @player_session_source =~ "handle_call({:homunculus, command}, from, state)"
      refute @player_session_source =~ "handle_info({:homunculus,"
    end

    test "recognizes the guarded direct replacement forms" do
      assert replaces_field?("%{session | other: value, homunculus: value}", :homunculus)
      assert replaces_field?("%SessionState{other: value, homunculus: value}", :homunculus)
      assert replaces_field?("%Player.SessionState{homunculus: value}", :homunculus)

      for function <- @map_writers do
        assert replaces_field?("Map.#{function}(session, :homunculus, value)", :homunculus)
      end

      assert replaces_field?("put_in(session.homunculus, value)", :homunculus)
      assert replaces_field?("update_in(session.homunculus.hp, & &1)", :homunculus)
      assert replaces_field?("put_in(session, [:homunculus], value)", :homunculus)
      assert replaces_field?("update_in(session, [:homunculus, :hp], & &1)", :homunculus)

      refute replaces_field?("%{homunculus: value}", :homunculus)
      refute replaces_field?("session.homunculus.hp", :homunculus)
      refute replaces_field?("%{session | homunculus_runtime: value}", :homunculus)
      refute replaces_field?("Map.get(session, :homunculus)", :homunculus)
      refute replaces_field?("put_in(session.other.homunculus, value)", :homunculus)
      refute replaces_field?("def f(%SessionState{homunculus: h} = s), do: s", :homunculus)
      refute replaces_field?("%SessionState{homunculus: h} = session", :homunculus)
      refute replaces_field?("x |> Map.put(:entity_type, :homunculus)", :homunculus)
      assert replaces_field?("struct(session, homunculus: value)", :homunculus)
      assert replaces_field?("session |> Map.put(:homunculus, value)", :homunculus)
      assert replaces_field?("Map.merge(session, %{homunculus: value})", :homunculus)
    end

    test "each companion StateCommit is the only direct replacement path of its field" do
      sources = Enum.map(@zone_server_sources, &{&1, Code.string_to_quoted!(File.read!(&1))})

      for {field, commit_source} <- @companion_fields do
        writers =
          for {path, ast} <- sources, replaces_field?(ast, field), do: Path.expand(path)

        assert [
                 Path.expand(
                   Path.join("../../../../lib/aesir/zone_server", commit_source),
                   __DIR__
                 )
               ] ==
                 writers,
               "only #{commit_source} may replace SessionState.#{field} directly"
      end
    end
  end

  # Source-level guard. Pipes are resolved and pattern positions (function
  # heads, `=`/`<-`/`->` left sides) blanked before scanning, so only
  # expression-position writes count.
  defp replaces_field?(source, field) when is_binary(source),
    do: replaces_field?(Code.string_to_quoted!(source), field)

  defp replaces_field?(ast, field) do
    {_ast, found?} =
      ast
      |> Macro.prewalk(&normalize/1)
      |> Macro.prewalk(false, fn
        node, true -> {node, true}
        node, false -> {node, direct_replacement?(node, field)}
      end)

    found?
  end

  defp normalize({:|>, _, [lhs, {call, meta, args}]}) when is_list(args),
    do: {call, meta, [lhs | args]}

  defp normalize({definer, meta, [_head, body]}) when definer in [:def, :defp],
    do: {definer, meta, [:__pattern__, body]}

  defp normalize({op, meta, [_lhs, rhs]}) when op in [:=, :<-],
    do: {op, meta, [:__pattern__, rhs]}

  defp normalize({:->, meta, [_lhs, rhs]}), do: {:->, meta, [[:__pattern__], rhs]}
  defp normalize(node), do: node

  # `%{session | field: _}`
  defp direct_replacement?({:%{}, _, [{:|, _, [_map, updates]}]}, field),
    do: has_field?(updates, field)

  # `%SessionState{field: _}` (any alias ending in SessionState)
  defp direct_replacement?({:%, _, [{:__aliases__, _, parts}, {:%{}, _, fields}]}, field),
    do: List.last(parts) == :SessionState and has_field?(fields, field)

  # `struct(session, field: _)` and `struct!/2`
  defp direct_replacement?({fun, _, [_session, fields]}, field) when fun in [:struct, :struct!],
    do: has_field?(fields, field)

  # `Map.put(session, :field, _)` and the other map writers, `Map.merge(session, %{field: _})`
  defp direct_replacement?({{:., _, [{:__aliases__, _, [:Map]}, fun]}, _, [_, key | _]}, field),
    do: (fun in @map_writers and key == field) or (fun == :merge and has_field?(key, field))

  # `put_in(session.field..., _)` and `put_in(session, [:field | _], _)`
  defp direct_replacement?({fun, _, [path, _value]}, field) when fun in @path_writers,
    do: field_path?(path, field)

  defp direct_replacement?({fun, _, [_data, keys, _value]}, field) when fun in @path_writers,
    do: field_path?(keys, field)

  defp direct_replacement?(_node, _field), do: false

  defp has_field?({:%{}, _, fields}, field), do: has_field?(fields, field)

  defp has_field?(fields, field) when is_list(fields),
    do: Keyword.keyword?(fields) and Keyword.has_key?(fields, field)

  defp has_field?(_other, _field), do: false

  defp field_path?([key | _], field), do: key == field

  defp field_path?({{:., _, [{_, _, context}, key]}, _, []}, field) when is_atom(context),
    do: key == field

  defp field_path?({{:., _, [inner, _key]}, _, []}, field), do: field_path?(inner, field)
  defp field_path?(_path, _field), do: false

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
    stub(SkillCooldownPersistence, :restore_on_spawn, fn state -> state end)
    stub(SkillCooldownPersistence, :save_cooldowns, fn _game_state -> :ok end)
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
