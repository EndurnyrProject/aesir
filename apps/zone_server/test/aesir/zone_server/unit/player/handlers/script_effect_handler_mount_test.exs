defmodule Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandlerMountTest do
  @moduledoc """
  The `{:set_riding, bool}` op through the real `MountHandler` (mirrors
  `mount_handler_test.exs`'s setup): unlike `setcart`'s silent rejection, a
  mount a script requests is expected to succeed, so the KN_RIDING gate
  surfaces as a halted `{:error, :cannot_mount}` instead of continuing.
  """

  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MountResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 8001
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
    stub(CharacterPersistence, :update_character, fn @char_id, _changes, async: true -> :ok end)

    :ok
  end

  defp kn_riding_id do
    {:ok, definition} = Catalog.by_name(:kn_riding)
    definition.id
  end

  defp learned(riding_level) do
    if riding_level > 0, do: %{Integer.to_string(kn_riding_id()) => riding_level}, else: %{}
  end

  defp character(opts) do
    %Character{
      id: @char_id,
      account_id: 3000,
      name: "Knighty",
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
      class: 0,
      hp: 800,
      sp: 300,
      option: Keyword.get(opts, :option, 0),
      learned_skills: learned(Keyword.get(opts, :riding_level, 0))
    }
  end

  defp state(opts) do
    %{connection_pid: self(), game_state: PlayerState.new(character(opts))}
  end

  describe "{:set_riding, true}" do
    test "with KN_RIDING learned mounts and folds the new game_state" do
      base = state(riding_level: 1)

      {reply, new_state} = ScriptEffectHandler.apply_op({:set_riding, true}, base)

      assert {:ok, game_state} = reply
      assert (game_state.option &&& @riding_bit) != 0
      assert new_state.game_state.option == game_state.option
      assert StatusStorage.has_status?(:player, @char_id, :sc_riding)
      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_OK}}}
    end

    test "without KN_RIDING learned halts with :cannot_mount, mutating nothing" do
      base = state(riding_level: 0)

      {reply, new_state} = ScriptEffectHandler.apply_op({:set_riding, true}, base)

      assert reply == {:error, :cannot_mount}
      assert new_state == base
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_SKILL_NOT_LEARNED}}}
    end

    test "while already mounted is a no-op success" do
      base = state(riding_level: 1, option: @riding_bit)

      {reply, new_state} = ScriptEffectHandler.apply_op({:set_riding, true}, base)

      assert {:ok, game_state} = reply
      assert (game_state.option &&& @riding_bit) != 0
      assert new_state == base

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_ALREADY_MOUNTED}}}
    end
  end

  describe "{:set_riding, false}" do
    test "while riding dismounts and folds the new game_state" do
      mounted = state(riding_level: 1, option: @riding_bit)

      {reply, new_state} = ScriptEffectHandler.apply_op({:set_riding, false}, mounted)

      assert {:ok, game_state} = reply
      refute (game_state.option &&& @riding_bit) != 0
      assert new_state.game_state.option == game_state.option
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)
      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_OK}}}
    end

    test "while not mounted is a no-op success" do
      base = state(riding_level: 1)

      {reply, new_state} = ScriptEffectHandler.apply_op({:set_riding, false}, base)

      assert {:ok, _game_state} = reply
      assert new_state == base

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_NOT_MOUNTED}}}
    end
  end
end
