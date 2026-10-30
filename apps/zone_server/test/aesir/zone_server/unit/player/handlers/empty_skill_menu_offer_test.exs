defmodule Aesir.ZoneServer.Unit.Player.Handlers.EmptySkillMenuOfferTest do
  use ExUnit.Case, async: true

  alias Aesir.Net.SkillMenu
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "empty_offer_preserves_pending_descriptor" do
    for pending <- [nil, %{skill_id: 279, kind: :SKILLS, entry_ids: [19], level: 1}] do
      state = %{connection_pid: self(), game_state: %PlayerState{}, pending_skill_menu: pending}

      assert SkillMenuHandler.open(state, 477, :INVENTORY_SLOTS, [], 10,
               preserve_pending_on_empty: true
             ) == state

      assert_received {:send, :world, {:skill_menu, %SkillMenu{src_skill_id: 477, entry_ids: []}}}
    end
  end

  test "defaults_still_arm_empty_menus_and_nonempty_offers_replace_pending" do
    state = %{connection_pid: self(), game_state: %PlayerState{}, pending_skill_menu: nil}
    empty = SkillMenuHandler.open(state, 279, :SKILLS, [], 1)
    assert empty.pending_skill_menu.entry_ids == []

    offered =
      SkillMenuHandler.open(empty, 477, :INVENTORY_SLOTS, [0], 10,
        preserve_pending_on_empty: true,
        context: %{learned_rank: 10}
      )

    assert %{skill_id: 477, entry_ids: [0], context: %{learned_rank: 10}} =
             offered.pending_skill_menu
  end
end
