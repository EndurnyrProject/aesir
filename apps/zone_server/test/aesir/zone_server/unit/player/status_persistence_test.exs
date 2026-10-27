defmodule Aesir.ZoneServer.Unit.Player.StatusPersistenceTest do
  use Aesir.DataCase, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.SpecialEffect
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  @moduletag :capture_log

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Registry.load_definitions()

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "statususer",
        user_pass: "password",
        sex: "M",
        email: "status@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      Character.new(%{
        account_id: account.id,
        char_num: 0,
        name: "StatusChar",
        class: 0,
        str: 5,
        agi: 5,
        vit: 5,
        int: 5,
        dex: 5,
        luk: 5,
        hp: 100,
        max_hp: 150,
        sp: 50,
        max_sp: 75,
        last_map: "prontera.gat",
        last_x: 100,
        last_y: 200,
        base_exp: 0,
        job_exp: 0
      })
      |> Repo.insert()

    %{character: character}
  end

  describe "save_statuses/1" do
    test "persists survivable statuses with their remaining duration", %{character: character} do
      :ok =
        StatusStorage.apply_status(:player, character.id, :sc_blessing,
          val1: 10,
          duration: 60_000
        )

      :ok = StatusPersistence.save_statuses(character.id)

      assert [row] = Repo.all(CharacterStatus)
      assert row.char_id == character.id
      assert row.status_type == "sc_blessing"
      assert row.val1 == 10
      assert row.remaining_ms > 0
      assert row.remaining_ms <= 60_000
    end

    test "skips no_save statuses", %{character: character} do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_push_cart, val1: 10, val2: 1)
      :ok = StatusStorage.apply_status(:player, character.id, :sc_hiding, duration: 30_000)

      :ok = StatusPersistence.save_statuses(character.id)

      assert Repo.all(CharacterStatus) == []
    end

    test "persists an infinite non-permanent status with a nil remaining duration", %{
      character: character
    } do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_cloaking, val1: 5)

      :ok = StatusPersistence.save_statuses(character.id)

      assert [%CharacterStatus{status_type: "sc_cloaking", val1: 5, remaining_ms: nil}] =
               Repo.all(CharacterStatus)
    end

    test "persists a permanent status with a nil remaining duration", %{character: character} do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_autoberserk, val1: 1)

      :ok = StatusPersistence.save_statuses(character.id)

      assert [%CharacterStatus{status_type: "sc_autoberserk", remaining_ms: nil}] =
               Repo.all(CharacterStatus)
    end

    test "saves an item's timed Summer with its remaining time", %{character: character} do
      :ok = UnitRegistry.register_player(PlayerState.new(character), self())

      :ok =
        Interpreter.apply_status(:player, character.id, :sc_summer,
          caster_id: character.id,
          val1: 1,
          duration: 600_000
        )

      :ok = StatusPersistence.save_statuses(character.id)

      assert [%CharacterStatus{status_type: "sc_summer", remaining_ms: remaining_ms}] =
               Repo.all(CharacterStatus)

      assert is_integer(remaining_ms)
      assert remaining_ms > 0
      assert remaining_ms <= 600_000
    end

    test "saves a worn costume's Summer as infinite", %{character: character} do
      :ok = UnitRegistry.register_player(PlayerState.new(character), self())

      :ok =
        Interpreter.apply_status(:player, character.id, :sc_summer,
          caster_id: character.id,
          val1: 1,
          duration: :infinite
        )

      :ok = StatusPersistence.save_statuses(character.id)

      assert [%CharacterStatus{status_type: "sc_summer", remaining_ms: nil}] =
               Repo.all(CharacterStatus)
    end

    test "skips statuses that already expired", %{character: character} do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_blessing, duration: 10)

      :ok =
        StatusStorage.update_status(
          :player,
          character.id,
          :sc_blessing,
          &%{&1 | expires_at: System.monotonic_time(:millisecond) - 1}
        )

      :ok = StatusPersistence.save_statuses(character.id)

      assert Repo.all(CharacterStatus) == []
    end

    test "persists the time left until a ticking status's next tick", %{character: character} do
      :ok =
        StatusStorage.apply_status(:player, character.id, :sc_poison,
          tick: 1_000,
          duration: 10_000
        )

      :ok =
        StatusStorage.update_status(
          :player,
          character.id,
          :sc_poison,
          &%{&1 | next_tick_at: System.monotonic_time(:millisecond) + 300}
        )

      :ok = StatusStorage.apply_status(:player, character.id, :sc_blessing, duration: 60_000)

      :ok = StatusPersistence.save_statuses(character.id)

      rows = Map.new(Repo.all(CharacterStatus), &{&1.status_type, &1})
      assert rows["sc_poison"].next_tick_ms in 0..300
      assert rows["sc_blessing"].next_tick_ms == nil
    end

    test "replaces previously saved rows", %{character: character} do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_blessing, duration: 60_000)
      :ok = StatusPersistence.save_statuses(character.id)

      :ok = StatusStorage.clear_unit_statuses(:player, character.id)
      :ok = StatusStorage.apply_status(:player, character.id, :sc_angelus, duration: 60_000)
      :ok = StatusPersistence.save_statuses(character.id)

      assert [%CharacterStatus{status_type: "sc_angelus"}] = Repo.all(CharacterStatus)
    end
  end

  describe "restore_on_spawn/1" do
    test "re-applies saved rows with the loaded flag and consumes them", %{character: character} do
      :ok =
        StatusStorage.apply_status(:player, character.id, :sc_blessing,
          val1: 10,
          duration: 60_000
        )

      :ok = StatusPersistence.save_statuses(character.id)
      :ok = StatusStorage.clear_unit_statuses(:player, character.id)

      state = %{game_state: %{character_id: character.id}}
      test_pid = self()

      expect(StatusManager, :handle_apply_status, fn status_id, params, session_state ->
        send(test_pid, {:applied, status_id, params})
        {:reply, :ok, session_state}
      end)

      assert ^state = StatusPersistence.restore_on_spawn(state)

      assert_received {:applied, :sc_blessing, params}
      assert params[:val1] == 10
      assert params[:loaded] == true
      assert params[:duration] > 0
      assert Repo.all(CharacterStatus) == []
    end

    test "restores a saved infinite Cloaking with its Cloak option", %{character: character} do
      player = PlayerState.new(character)
      player = put_in(player.stats.progression.learned_skills[135], 5)
      :ok = UnitRegistry.register_player(player, self())

      %CharacterStatus{}
      |> CharacterStatus.changeset(%{
        char_id: character.id,
        status_type: "sc_cloaking",
        val1: 5,
        tick: 4_000,
        remaining_ms: nil
      })
      |> Repo.insert!()

      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})

      assert %{val1: 5, expires_at: nil} =
               StatusStorage.get_status(:player, character.id, :sc_cloaking)

      assert Bitwise.band(
               StatusDisplay.spawn_state(:player, character.id).effect_state,
               Option.id(:cloak)
             ) != 0
    end

    test "restores a saved Summer with its remaining time or as infinite", %{
      character: character
    } do
      player = PlayerState.new(character)
      :ok = UnitRegistry.register_player(player, self())
      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      for remaining_ms <- [300_000, nil] do
        %CharacterStatus{}
        |> CharacterStatus.changeset(%{
          char_id: character.id,
          status_type: "sc_summer",
          val1: 1,
          remaining_ms: remaining_ms
        })
        |> Repo.insert!()

        before = System.monotonic_time(:millisecond)
        StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})
        after_restore = System.monotonic_time(:millisecond)

        %{expires_at: expires_at} = StatusStorage.get_status(:player, character.id, :sc_summer)

        if remaining_ms do
          assert is_integer(expires_at)
          assert expires_at >= before + remaining_ms
          assert expires_at <= after_restore + remaining_ms
        else
          assert expires_at == nil
        end

        :ok = StatusStorage.clear_unit_statuses(:player, character.id)
      end
    end

    test "a status applied by a monster restores with that monster as its source", %{
      character: character
    } do
      player = PlayerState.new(character)
      :ok = UnitRegistry.register_player(player, self())
      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      :ok =
        Interpreter.apply_status(:player, character.id, :sc_poison,
          val1: 1,
          duration: 10_000,
          caster_id: 4_242,
          source_type: :mob,
          loaded: true
        )

      :ok = StatusPersistence.save_statuses(character.id)
      :ok = StatusStorage.clear_unit_statuses(:player, character.id)

      StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})

      assert %{source_id: 4_242, source_type: :mob} =
               StatusStorage.get_status(:player, character.id, :sc_poison)
    end

    test "a value the status sets when it starts is stored and survives a relog", %{
      character: character
    } do
      player = PlayerState.new(character)
      :ok = UnitRegistry.register_player(player, self())
      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      :ok = Interpreter.apply_status(:player, character.id, :sc_sacrifice, val1: 3)

      assert %{val2: 5} = StatusStorage.get_status(:player, character.id, :sc_sacrifice)

      :ok = StatusPersistence.save_statuses(character.id)
      assert [%CharacterStatus{status_type: "sc_sacrifice", val2: 5}] = Repo.all(CharacterStatus)
      :ok = StatusStorage.clear_unit_statuses(:player, character.id)

      StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})

      assert %{val2: 5, state: %{remaining: 5}} =
               StatusStorage.get_status(:player, character.id, :sc_sacrifice)
    end

    @tag game_mode: :renewal
    test "a Splasher saved with 3 s left explodes 3 s after the restore, from its monster source",
         %{character: character} do
      player = PlayerState.new(character)
      :ok = UnitRegistry.register_player(player, self())
      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      source =
        %MobState{
          instance_id: 3_000,
          mob_id: 1,
          mob_data: Aesir.TestMob.definition(),
          spawn_ref: nil,
          map_name: player.map_name,
          x: player.x + 1,
          y: player.y,
          hp: 100,
          sp: 0,
          spawned_at: 0
        }
        |> Aesir.TestMob.publish(max_hp: 100, max_sp: 0)

      :ok = UnitRegistry.register_unit(:mob, 3_000, MobState, source, self())
      :ok = SpatialIndex.add_unit(:player, character.id, player.x, player.y, player.map_name)
      applied_at = System.monotonic_time(:millisecond)

      :ok =
        Interpreter.apply_status(:player, character.id, :sc_splasher,
          val1: 5,
          val4: 3_000,
          duration: :infinite,
          first_tick: 500,
          caster_id: 3_000,
          source_type: :mob
        )

      :ok = StatusPersistence.save_statuses(character.id)
      :ok = StatusStorage.clear_unit_statuses(:player, character.id)

      StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})
      after_restore = System.monotonic_time(:millisecond)

      assert %{
               val1: 5,
               val4: 3_000,
               tick: 500,
               source_id: 3_000,
               source_type: :mob,
               expires_at: nil
             } = restored = StatusStorage.get_status(:player, character.id, :sc_splasher)

      assert restored.next_tick_at in (applied_at + 500)..(after_restore + 500)

      expect(Combat, :execute_forced_no_card_splash, fn ^source, _cell, 2, opts ->
        assert opts[:skill_ratio] == 900
        []
      end)

      expect(SpecialEffect, :play, fn {:player, _id}, :splasher -> :ok end)

      # The first step is due when the time left until it runs out; then one
      # every half second, the sixth exploding: 0.5 s + 5 x 0.5 s = 3 s.
      steps =
        Stream.repeatedly(fn ->
          Interpreter.process_tick_if_current(
            :player,
            character.id,
            :sc_splasher,
            restored.generation
          )
        end)
        |> Enum.take_while(&(&1 == :continue))
        |> length()

      assert steps == 5
      refute StatusStorage.has_status?(:player, character.id, :sc_splasher)
    end

    test "a restored poison takes its next tick after the time that was left", %{
      character: character
    } do
      player = PlayerState.new(character)
      :ok = UnitRegistry.register_player(player, self())

      %CharacterStatus{}
      |> CharacterStatus.changeset(%{
        char_id: character.id,
        status_type: "sc_poison",
        val1: 1,
        tick: 1_000,
        remaining_ms: 10_000,
        next_tick_ms: 300
      })
      |> Repo.insert!()

      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      before = System.monotonic_time(:millisecond)
      StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})
      after_restore = System.monotonic_time(:millisecond)

      %{next_tick_at: next_tick_at, tick: 1_000} =
        StatusStorage.get_status(:player, character.id, :sc_poison)

      assert next_tick_at >= before + 300
      assert next_tick_at <= after_restore + 300
    end

    test "a restored Cloaking drains its first SP after the time that was left", %{
      character: character
    } do
      player = PlayerState.new(character)
      player = put_in(player.stats.progression.learned_skills[135], 5)
      :ok = UnitRegistry.register_player(player, self())

      %CharacterStatus{}
      |> CharacterStatus.changeset(%{
        char_id: character.id,
        status_type: "sc_cloaking",
        val1: 5,
        tick: 4_000,
        remaining_ms: nil,
        next_tick_ms: 700
      })
      |> Repo.insert!()

      stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
      stub(StatusSync, :send_param, fn _connection, _param, _value -> :ok end)

      before = System.monotonic_time(:millisecond)
      StatusPersistence.restore_on_spawn(%{game_state: player, connection_pid: self()})
      after_restore = System.monotonic_time(:millisecond)

      %{next_tick_at: next_tick_at} =
        StatusStorage.get_status(:player, character.id, :sc_cloaking)

      assert next_tick_at >= before + 700
      assert next_tick_at <= after_restore + 700
    end

    test "drops malformed and stale finite rows without applying them", %{character: character} do
      for {status_type, remaining_ms} <- [
            {"sc_angelus", 0},
            {"sc_increaseagi", -1}
          ] do
        %CharacterStatus{}
        |> CharacterStatus.changeset(%{
          char_id: character.id,
          status_type: status_type,
          remaining_ms: remaining_ms
        })
        |> Repo.insert!()
      end

      reject(&StatusManager.handle_apply_status/3)
      state = %{game_state: %{character_id: character.id}}

      log = capture_log(fn -> assert ^state = StatusPersistence.restore_on_spawn(state) end)

      assert Repo.all(CharacterStatus) == []
      assert log =~ "Dropping persisted finite status sc_angelus with invalid remaining duration"

      assert log =~
               "Dropping persisted finite status sc_increaseagi with invalid remaining duration"
    end

    test "drops rows whose status type no longer exists", %{character: character} do
      %CharacterStatus{}
      |> CharacterStatus.changeset(%{
        char_id: character.id,
        status_type: "sc_gone",
        remaining_ms: 1_000
      })
      |> Repo.insert!()

      reject(&StatusManager.handle_apply_status/3)

      state = %{game_state: %{character_id: character.id}}

      assert ^state = StatusPersistence.restore_on_spawn(state)
      assert Repo.all(CharacterStatus) == []
    end
  end
end
