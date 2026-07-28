defmodule Aesir.ZoneServer.Unit.Player.StatusPersistenceTest do
  use Aesir.DataCase, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence

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

    test "skips and warns about non-permanent statuses without an expiry", %{
      character: character
    } do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_blessing, val1: 10)

      log = capture_log(fn -> assert :ok = StatusPersistence.save_statuses(character.id) end)

      assert Repo.all(CharacterStatus) == []
      assert log =~ "Dropping non-permanent status sc_blessing without a finite expiry"
    end

    test "persists a permanent status with a nil remaining duration", %{character: character} do
      :ok = StatusStorage.apply_status(:player, character.id, :sc_autoberserk, val1: 1)

      :ok = StatusPersistence.save_statuses(character.id)

      assert [%CharacterStatus{status_type: "sc_autoberserk", remaining_ms: nil}] =
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

    test "drops malformed and stale finite rows without applying them", %{character: character} do
      for {status_type, remaining_ms} <- [
            {"sc_blessing", nil},
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
      assert log =~ "Dropping persisted finite status sc_blessing with invalid remaining duration"
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
