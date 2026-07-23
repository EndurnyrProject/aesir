defmodule Aesir.ZoneServer.Unit.Player.Handlers.MountHandlerTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup
  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.MountResult
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.MountHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  @char_id 8001
  @cavalier_level 3
  @riding_bit Option.id(:riding)
  @falcon_bit Option.id(:falcon)

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

  defp kn_riding_id do
    {:ok, definition} = Catalog.by_name(:kn_riding)
    definition.id
  end

  defp kn_cavaliermastery_id do
    {:ok, definition} = Catalog.by_name(:kn_cavaliermastery)
    definition.id
  end

  defp kn_spearmastery_id do
    {:ok, definition} = Catalog.by_name(:kn_spearmastery)
    definition.id
  end

  defp learned(opts) do
    riding = Keyword.get(opts, :riding_level, 0)
    cavalier = Keyword.get(opts, :cavalier_level, 0)

    %{}
    |> maybe_put(kn_riding_id(), riding)
    |> maybe_put(kn_cavaliermastery_id(), cavalier)
  end

  defp maybe_put(map, _key, 0), do: map
  defp maybe_put(map, key, value), do: Map.put(map, Integer.to_string(key), value)

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
      learned_skills: Keyword.get(opts, :learned_skills, learned(opts))
    }
  end

  defp state(opts) do
    game_state = PlayerState.new(character(opts))
    game_state = %{game_state | action_state: Keyword.get(opts, :action_state, :idle)}
    %{connection_pid: self(), game_state: game_state, interaction_lock: nil}
  end

  describe "mount/1" do
    test "with KN_RIDING learned applies SC_RIDING, speeds the player up, and persists the bit" do
      expect(CharacterPersistence, :update_character, fn @char_id,
                                                         %{option: option},
                                                         async: true ->
        assert option == (@falcon_bit ||| @riding_bit)
        :ok
      end)

      base = state(riding_level: 1, cavalier_level: @cavalier_level, option: @falcon_bit)

      assert {:noreply, new_state} = MountHandler.mount(base)

      assert MountHandler.riding?(new_state)
      assert new_state.game_state.option == (@falcon_bit ||| @riding_bit)
      assert StatusStorage.has_status?(:player, @char_id, :sc_riding)
      assert StatusStorage.get_status(:player, @char_id, :sc_riding).val1 == @cavalier_level
      assert new_state.game_state.walk_speed < 150

      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_OK}}}
    end

    test "without KN_RIDING learned is rejected as MOUNT_SKILL_NOT_LEARNED" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 0)

      assert {:noreply, ^base} = MountHandler.mount(base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_SKILL_NOT_LEARNED}}}
    end

    test "while dead is rejected as MOUNT_DEAD" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 1, action_state: :dead)

      assert {:noreply, ^base} = MountHandler.mount(base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)

      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_DEAD}}}
    end

    test "while already mounted is rejected as MOUNT_ALREADY_MOUNTED" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 1, option: @riding_bit)

      assert {:noreply, ^base} = MountHandler.mount(base)

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_ALREADY_MOUNTED}}}
    end

    test "when SC_RIDING apply fails, stats.riding is reverted rather than left flipped" do
      reject(&CharacterPersistence.update_character/3)

      stub(StatusManager, :handle_apply_status, fn :sc_riding, _params, state ->
        {:reply, {:error, :test_failure}, state}
      end)

      base = state(riding_level: 1, cavalier_level: @cavalier_level, option: 0)

      assert {:noreply, result} = MountHandler.mount(base)

      refute result.game_state.stats.riding
      assert result.game_state.option == 0
      refute MountHandler.riding?(result)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)
    end
  end

  describe "force_mount/1" do
    test "without KN_RIDING learned still applies SC_RIDING and persists the bit" do
      expect(CharacterPersistence, :update_character, fn @char_id,
                                                         %{option: option},
                                                         async: true ->
        assert option == (@falcon_bit ||| @riding_bit)
        :ok
      end)

      base = state(riding_level: 0, cavalier_level: @cavalier_level, option: @falcon_bit)

      assert {:noreply, new_state} = MountHandler.force_mount(base)

      assert MountHandler.riding?(new_state)
      assert new_state.game_state.option == (@falcon_bit ||| @riding_bit)
      assert StatusStorage.has_status?(:player, @char_id, :sc_riding)

      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_OK}}}
    end

    test "while dead is rejected as MOUNT_DEAD" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 0, action_state: :dead)

      assert {:noreply, ^base} = MountHandler.force_mount(base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)

      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_DEAD}}}
    end

    test "while already mounted is rejected as MOUNT_ALREADY_MOUNTED" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 0, option: @riding_bit)

      assert {:noreply, ^base} = MountHandler.force_mount(base)

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_ALREADY_MOUNTED}}}
    end
  end

  describe "dismount/1" do
    test "while riding removes SC_RIDING, clears the bit, and persists the recomputed option" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn @char_id, %{option: option}, async: true ->
        send(test_pid, {:persisted_option, option})
        :ok
      end)

      base = state(riding_level: 1, cavalier_level: @cavalier_level, option: @falcon_bit)
      {:noreply, mounted} = MountHandler.mount(base)
      assert StatusStorage.has_status?(:player, @char_id, :sc_riding)
      mounted_option = @falcon_bit ||| @riding_bit
      assert_received {:persisted_option, ^mounted_option}

      assert {:noreply, dismounted} = MountHandler.dismount(mounted)

      refute MountHandler.riding?(dismounted)
      assert dismounted.game_state.option == @falcon_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)
      assert_received {:persisted_option, @falcon_bit}

      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_OK}}}
    end

    test "while not mounted is a no-op reported as MOUNT_NOT_MOUNTED" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 1)

      assert {:noreply, ^base} = MountHandler.dismount(base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)

      assert_received {:send, :gameplay,
                       {:mount_result, %MountResult{result: :MOUNT_NOT_MOUNTED}}}
    end
  end

  describe "force_dismount/1" do
    test "while riding removes SC_RIDING, clears the bit, and persists without a client reply" do
      test_pid = self()

      stub(CharacterPersistence, :update_character, fn @char_id, %{option: option}, async: true ->
        send(test_pid, {:persisted_option, option})
        :ok
      end)

      base = state(riding_level: 1, cavalier_level: @cavalier_level, option: @falcon_bit)
      {:noreply, mounted} = MountHandler.mount(base)
      assert_received {:persisted_option, _}
      assert_received {:send, :gameplay, {:mount_result, %MountResult{result: :MOUNT_OK}}}

      dismounted = MountHandler.force_dismount(mounted)

      refute MountHandler.riding?(dismounted)
      assert dismounted.game_state.option == @falcon_bit
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)
      assert_received {:persisted_option, @falcon_bit}
      refute_received {:send, :gameplay, {:mount_result, _}}
    end

    test "while not mounted is a no-op" do
      reject(&CharacterPersistence.update_character/3)

      base = state(riding_level: 1)

      assert ^base = MountHandler.force_dismount(base)
      refute_received {:send, :gameplay, {:mount_result, _}}
    end
  end

  describe "load_on_spawn/2" do
    test "re-applies SC_RIDING from the persisted riding bit without re-persisting" do
      reject(&CharacterPersistence.update_character/3)

      char = character(riding_level: 1, cavalier_level: @cavalier_level, option: @riding_bit)
      base = %{connection_pid: self(), game_state: PlayerState.new(char), interaction_lock: nil}

      restored = MountHandler.load_on_spawn(char, base)

      assert StatusStorage.has_status?(:player, @char_id, :sc_riding)
      assert StatusStorage.get_status(:player, @char_id, :sc_riding).val1 == @cavalier_level
      assert restored.game_state.walk_speed < 150
    end

    test "is a no-op when the persisted option lacks the riding bit" do
      reject(&CharacterPersistence.update_character/3)

      char = character(riding_level: 1, option: 0)
      base = state(riding_level: 1)

      assert ^base = MountHandler.load_on_spawn(char, base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)
    end
  end

  describe "recompute/1" do
    test "while riding re-applies SC_RIDING with a fresh Cavalier Mastery val1" do
      base = state(riding_level: 1, cavalier_level: 0, option: @riding_bit)
      before = MountHandler.recompute(base)
      assert StatusStorage.get_status(:player, @char_id, :sc_riding).val1 == 0

      raised =
        put_in(before.game_state.stats.progression.learned_skills[kn_cavaliermastery_id()], 5)

      MountHandler.recompute(raised)

      assert StatusStorage.get_status(:player, @char_id, :sc_riding).val1 == 5
    end

    test "is a no-op when the player is not mounted" do
      base = state(riding_level: 1, cavalier_level: 5, option: 0)

      assert ^base = MountHandler.recompute(base)
      refute StatusStorage.has_status?(:player, @char_id, :sc_riding)
    end
  end

  describe "packet dispatch" do
    test "MountRequest{mount: true} dispatches to MountHandler.mount/1" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(MountHandler, :mount, fn st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%Aesir.Net.MountRequest{mount: true}, base)
    end

    test "MountRequest{mount: false} dispatches to MountHandler.dismount/1" do
      base = %{game_state: %PlayerState{character_id: @char_id}}

      expect(MountHandler, :dismount, fn st -> {:noreply, st} end)

      assert {:noreply, ^base} =
               PacketHandler.handle_message(%Aesir.Net.MountRequest{mount: false}, base)
    end
  end

  describe "Spear Mastery interaction" do
    # rAthena Renewal-shape javelin (1hSpear); its own base attack is stripped
    # from `modifiers.equipment` by not going through `apply_equipment_modifiers`,
    # so `combat_stats.passive_atk` reflects only KN_SPEARMASTERY's contribution.
    # Knight (job id 7) - has a `one_handed_spear` entry in its base ASPD
    # table, unlike novice, so mount/dismount's full recalc pipeline (which
    # includes ASPD) doesn't blow up once the javelin is equipped.
    defp spearman(opts) do
      base = state(opts)
      stats = base.game_state.stats

      armed_stats = %{
        stats
        | equipment: Stats.equipment_from_inventory([%InventoryItem{nameid: 1401, equip: 2}]),
          progression: %{
            stats.progression
            | job_id: 7,
              learned_skills: Map.put(stats.progression.learned_skills, kn_spearmastery_id(), 10)
          }
      }

      put_in(base.game_state.stats, Stats.calculate_stats(armed_stats, @char_id))
    end

    test "mounting raises the Spear Mastery ATK bonus from +40 to +50" do
      stub(CharacterPersistence, :update_character, fn @char_id, %{option: _}, async: true ->
        :ok
      end)

      base = spearman(riding_level: 1, cavalier_level: @cavalier_level, option: 0)
      assert base.game_state.stats.combat_stats.passive_atk == 40

      assert {:noreply, mounted} = MountHandler.mount(base)

      assert mounted.game_state.stats.riding == true
      assert mounted.game_state.stats.combat_stats.passive_atk == 50
    end

    test "dismounting drops the Spear Mastery ATK bonus back to +40" do
      stub(CharacterPersistence, :update_character, fn @char_id, %{option: _}, async: true ->
        :ok
      end)

      base = spearman(riding_level: 1, cavalier_level: @cavalier_level, option: @riding_bit)
      assert base.game_state.stats.combat_stats.passive_atk == 50

      assert {:noreply, dismounted} = MountHandler.dismount(base)

      assert dismounted.game_state.stats.riding == false
      assert dismounted.game_state.stats.combat_stats.passive_atk == 40
    end
  end
end
