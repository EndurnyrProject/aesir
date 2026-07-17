defmodule Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandlerTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # SA_AUTOSPELL, one of the two Sage menus this transport exists for.
  @src_skill 380
  @entry_ids [11, 17, 21]

  describe "open/5" do
    test "sends the offer to the client and records it as the pending menu" do
      state = SkillMenuHandler.open(build_state(), @src_skill, :SKILLS, @entry_ids, 3)

      assert_receive {:send, :world,
                      {:skill_menu,
                       %SkillMenu{src_skill_id: @src_skill, kind: :SKILLS, entry_ids: @entry_ids}}}

      assert state.pending_skill_menu == %{
               skill_id: @src_skill,
               kind: :SKILLS,
               entry_ids: @entry_ids,
               level: 3
             }
    end
  end

  describe "handle_reply/2 with a matching pending menu" do
    test "accepts an offered id and clears the pending menu" do
      state = pending_state()

      assert {:noreply, new_state} =
               SkillMenuHandler.handle_reply(
                 %SkillMenuReply{src_skill_id: @src_skill, selected_id: 17},
                 state
               )

      assert new_state.pending_skill_menu == nil
    end

    test "cancels silently on selected_id 0" do
      state = pending_state()

      assert {:noreply, new_state} =
               SkillMenuHandler.handle_reply(
                 %SkillMenuReply{src_skill_id: @src_skill, selected_id: 0},
                 state
               )

      assert new_state.pending_skill_menu == nil
      refute_receive {:send, _, _}
    end
  end

  describe "handle_reply/2 drops invalid replies" do
    test "drops a reply when no menu is pending, leaving the session alone" do
      state = build_state()

      assert {:noreply, ^state} =
               SkillMenuHandler.handle_reply(
                 %SkillMenuReply{src_skill_id: @src_skill, selected_id: 17},
                 state
               )
    end

    test "drops a reply for a different skill, keeping the pending menu" do
      state = pending_state()

      assert {:noreply, ^state} =
               SkillMenuHandler.handle_reply(
                 %SkillMenuReply{src_skill_id: 381, selected_id: 17},
                 state
               )

      assert state.pending_skill_menu.skill_id == @src_skill
    end

    test "drops a selection that was never offered, keeping the pending menu" do
      state = pending_state()

      assert {:noreply, ^state} =
               SkillMenuHandler.handle_reply(
                 %SkillMenuReply{src_skill_id: @src_skill, selected_id: 999},
                 state
               )

      assert state.pending_skill_menu.entry_ids == @entry_ids
    end

    test "a stale cancel for a different skill does not clear the pending menu" do
      state = pending_state()

      assert {:noreply, ^state} =
               SkillMenuHandler.handle_reply(
                 %SkillMenuReply{src_skill_id: 381, selected_id: 0},
                 state
               )
    end
  end

  describe "PacketHandler routing" do
    test "routes an injected SkillMenuReply to the pending-menu handler" do
      state = pending_state()

      assert {:noreply, new_state} =
               PacketHandler.handle_message(
                 %SkillMenuReply{src_skill_id: @src_skill, selected_id: 21},
                 state
               )

      assert new_state.pending_skill_menu == nil
    end
  end

  describe "clear/1" do
    test "drops the pending menu and is a no-op when none is pending" do
      assert SkillMenuHandler.clear(pending_state()).pending_skill_menu == nil
      assert SkillMenuHandler.clear(build_state()).pending_skill_menu == nil
    end
  end

  defp pending_state do
    %{
      build_state()
      | pending_skill_menu: %{
          skill_id: @src_skill,
          kind: :SKILLS,
          entry_ids: @entry_ids,
          level: 3
        }
    }
  end

  defp build_state do
    %{
      game_state: %PlayerState{character_id: 1, map_name: "prontera"},
      connection_pid: self(),
      pending_skill_menu: nil
    }
  end
end
