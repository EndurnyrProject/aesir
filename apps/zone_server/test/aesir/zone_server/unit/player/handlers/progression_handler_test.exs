defmodule Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandlerTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Net.SkillList
  alias Aesir.Net.SpriteChange
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.ProgressionHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  {:ok, knight_id} = AvailableJobs.job_name_to_id(:knight)
  @knight_id knight_id
  @unknown_job_id 99_999

  setup do
    stub(UnitRegistry, :update_unit_state, fn :player, 1000, _ -> :ok end)
    stub(CharacterPersistence, :update_character, fn 1000, _attrs, async: true -> {:ok, %{}} end)
    stub(Broadcast, :to_player, fn _char_id, _packet -> :ok end)
    stub(Broadcast, :to_visible_players, fn _game_state, _packet, _opts -> :ok end)

    :ok
  end

  defp state do
    base = PlayerState.new(character())
    %{connection_pid: self(), game_state: base}
  end

  defp character do
    %Aesir.Commons.Models.Character{
      id: 1000,
      account_id: 2000,
      name: "Swordy",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      sex: "M",
      hair: 1,
      hair_color: 0,
      clothes_color: 0,
      head_mid: 0,
      head_bottom: 0,
      robe: 0,
      str: 10,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 1
    }
  end

  describe "apply_job_change/2 with a valid job id" do
    test "updates progression.job_id, recomputes stats, and returns {:ok, new_state}" do
      assert {:ok, new_state} = ProgressionHandler.apply_job_change(@knight_id, state())

      assert new_state.game_state.stats.progression.job_id == @knight_id
    end

    test "broadcasts the base-look SpriteChange to the player" do
      test_pid = self()

      stub(Broadcast, :to_player, fn 1000, packet ->
        send(test_pid, {:to_player, packet})
        :ok
      end)

      ProgressionHandler.apply_job_change(@knight_id, state())

      assert_received {:to_player, %SpriteChange{gid: 1000, val: @knight_id}}
    end

    test "sends a refreshed SkillList built from the new progression" do
      ProgressionHandler.apply_job_change(@knight_id, state())

      assert_received {:send, :bulk, {:skill_list, %SkillList{}}}
    end
  end

  describe "apply_job_change/2 with an unknown job id" do
    test "returns {:error, :unknown_job} without mutating state" do
      original = state()

      assert {:error, :unknown_job} =
               ProgressionHandler.apply_job_change(@unknown_job_id, original)
    end

    test "does not broadcast, persist, or send a skill list" do
      reject(&Broadcast.to_player/2)
      reject(&CharacterPersistence.update_character/3)

      ProgressionHandler.apply_job_change(@unknown_job_id, state())

      refute_received {:send, :bulk, {:skill_list, _}}
    end
  end

  describe "handle_change_job/2" do
    test "returns {:noreply, new_state} on a valid job id" do
      assert {:noreply, new_state} = ProgressionHandler.handle_change_job(@knight_id, state())

      assert new_state.game_state.stats.progression.job_id == @knight_id
    end

    test "returns {:noreply, state} unchanged on an unknown job id" do
      original = state()

      assert {:noreply, ^original} =
               ProgressionHandler.handle_change_job(@unknown_job_id, original)
    end
  end
end
