defmodule Aesir.ZoneServer.Unit.Player.Handlers.FalconHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 8002
  @ht_falcon_id HtFalcon.definition().id
  @falcon_bit Option.id(:falcon)
  @riding_bit Option.id(:riding)

  setup do
    stub(UnitRegistry, :get_unit_info, fn _unit_type, unit_id ->
      {:ok,
       %{
         unit_id: unit_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{level: 50, base_level: 50, str: 10, agi: 10, vit: 10, int: 10, dex: 10, luk: 10}
       }}
    end)

    stub(UnitRegistry, :update_unit_state, fn :player, @char_id, _gs -> :ok end)

    stub(SpatialIndex, :get_unit_position, fn :player, @char_id ->
      {:ok, {150, 150, "prontera"}}
    end)

    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)

    :ok
  end

  defp learned(opts) do
    case Keyword.get(opts, :falconry_level, 1) do
      0 -> %{}
      level -> %{@ht_falcon_id => level}
    end
  end

  defp character(opts) do
    %Character{
      id: @char_id,
      account_id: 3000,
      name: "Hunty",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      base_level: 50,
      job_level: 50,
      class: 11,
      hp: 800,
      sp: 300,
      option: Keyword.get(opts, :option, 0),
      learned_skills: Keyword.get(opts, :learned_skills, learned(opts))
    }
  end

  defp state(opts) do
    game_state = PlayerState.new(character(opts))
    %{connection_pid: self(), game_state: game_state, interaction_lock: nil}
  end

  describe "set_falcon/2 enable" do
    test "with Falconry Mastery learned applies SC_FALCON, sets the bit, and persists other bits" do
      expect(CharacterPersistence, :update_character, fn @char_id,
                                                         %{option: option},
                                                         async: true ->
        assert option == (@riding_bit ||| @falcon_bit)
        :ok
      end)

      base = state(falconry_level: 1, option: @riding_bit)

      assert {:ok, new_state} = FalconHandler.set_falcon(base, true)

      assert FalconHandler.falcon?(new_state)
      assert new_state.game_state.option == (@riding_bit ||| @falcon_bit)
      assert StatusStorage.has_status?(:player, @char_id, :sc_falcon)
    end

    test "without Falconry Mastery learned is rejected and changes nothing" do
      reject(&CharacterPersistence.update_character/3)

      base = state(falconry_level: 0, option: @riding_bit)

      assert {:error, :falcon_skill_not_learned} = FalconHandler.set_falcon(base, true)

      unchanged = get_game_state_option(base)
      assert unchanged == @riding_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
    end

    test "when already equipped is an idempotent success with no side effects" do
      reject(&CharacterPersistence.update_character/3)

      base = state(falconry_level: 1, option: @falcon_bit)

      assert {:ok, ^base} = FalconHandler.set_falcon(base, true)
    end

    @tag :capture_log
    test "when SC_FALCON apply fails nothing commits (option, persistence)" do
      reject(&CharacterPersistence.update_character/3)

      stub(StatusManager, :handle_apply_status, fn :sc_falcon, _params, state ->
        {:reply, {:error, :test_failure}, state}
      end)

      base = state(falconry_level: 1, option: @riding_bit)

      assert {:error, :status_apply_failed} = FalconHandler.set_falcon(base, true)
      assert get_game_state_option(base) == @riding_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
    end
  end

  describe "set_falcon/2 disable" do
    test "while equipped removes SC_FALCON, clears the bit, and persists other bits" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn @char_id, %{option: option}, async: true ->
        send(test_pid, {:persisted_option, option})
        :ok
      end)

      base = state(falconry_level: 1, option: @riding_bit)
      {:ok, equipped} = FalconHandler.set_falcon(base, true)
      assert_received {:persisted_option, equipped_option}
      assert equipped_option == (@riding_bit ||| @falcon_bit)
      assert StatusStorage.has_status?(:player, @char_id, :sc_falcon)

      assert {:ok, dismissed} = FalconHandler.set_falcon(equipped, false)

      refute FalconHandler.falcon?(dismissed)
      assert dismissed.game_state.option == @riding_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
      assert_received {:persisted_option, @riding_bit}
    end

    test "while not equipped is an idempotent success with no side effects" do
      reject(&CharacterPersistence.update_character/3)

      base = state(falconry_level: 1, option: @riding_bit)

      assert {:ok, ^base} = FalconHandler.set_falcon(base, false)
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
    end
  end

  describe "force_dismiss/1" do
    test "while equipped clears the bit and persists without any client message" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn @char_id, %{option: option}, async: true ->
        send(test_pid, {:persisted_option, option})
        :ok
      end)

      base = state(falconry_level: 1, option: @riding_bit ||| @falcon_bit)

      dismissed = FalconHandler.force_dismiss(base)

      refute FalconHandler.falcon?(dismissed)
      assert dismissed.game_state.option == @riding_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
      assert_received {:persisted_option, @riding_bit}
      refute_received {:send, _, _}
    end

    test "while not equipped is a no-op" do
      reject(&CharacterPersistence.update_character/3)

      base = state(falconry_level: 1, option: @riding_bit)

      assert ^base = FalconHandler.force_dismiss(base)
    end
  end

  describe "load_on_spawn/2" do
    test "with a valid persisted bit and Falconry Mastery re-applies SC_FALCON without persisting" do
      reject(&CharacterPersistence.update_character/3)

      char = character(falconry_level: 1, option: @riding_bit ||| @falcon_bit)
      base = %{connection_pid: self(), game_state: PlayerState.new(char), interaction_lock: nil}

      restored = FalconHandler.load_on_spawn(char, base)

      assert StatusStorage.has_status?(:player, @char_id, :sc_falcon)
      assert FalconHandler.falcon?(restored)
      assert restored.game_state.option == (@riding_bit ||| @falcon_bit)
    end

    test "with a stale bit and no Falconry Mastery clears and persists the bit instead" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn @char_id, %{option: option}, async: true ->
        send(test_pid, {:persisted_option, option})
        :ok
      end)

      char = character(falconry_level: 0, option: @riding_bit ||| @falcon_bit)
      base = %{connection_pid: self(), game_state: PlayerState.new(char), interaction_lock: nil}

      restored = FalconHandler.load_on_spawn(char, base)

      refute FalconHandler.falcon?(restored)
      assert restored.game_state.option == @riding_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
      assert_received {:persisted_option, @riding_bit}
    end

    test "is a no-op when the persisted option lacks the falcon bit" do
      reject(&CharacterPersistence.update_character/3)

      char = character(falconry_level: 1, option: @riding_bit)
      base = %{connection_pid: self(), game_state: PlayerState.new(char), interaction_lock: nil}

      assert ^base = FalconHandler.load_on_spawn(char, base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_falcon)
    end
  end

  describe "falcon?/1" do
    test "reads the bit from a bare PlayerState" do
      assert FalconHandler.falcon?(%PlayerState{option: @falcon_bit})
      refute FalconHandler.falcon?(%PlayerState{option: @riding_bit})
    end
  end

  defp get_game_state_option(%{game_state: game_state}), do: game_state.option
end
