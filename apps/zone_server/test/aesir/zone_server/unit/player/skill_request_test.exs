defmodule Aesir.ZoneServer.Unit.Player.SkillRequestTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.NoCast
  alias Aesir.ZoneServer.Mmo.StatusEffect.StatusDisplay
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Proximity
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SkillRequest

  @id 8_652
  @now 1_000_000
  @fire_bolt 19
  @thunderstorm 21
  @sword_mastery 2
  @teleport 26
  @ice_wall 87
  @first_aid 142
  @chain_combo 272
  @cast_cancel 275
  @autospell 279
  @basilica 362
  @emergency_call 10_013
  @iron 94
  @npc_lock {nil, nil, 0x5000_0001}

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    stub_body_state(0)
    stub(MapFlags, :get, fn _map, _flag -> false end)
    stub(NoCast, :refused?, fn _skill_id, _map -> false end)
    %{state: session_state()}
  end

  describe "targeted/5 request kind" do
    test "a ground, passive, forging or unknown skill is refused silently", %{state: state} do
      for skill_id <- [@thunderstorm, @sword_mastery, @iron, 9_999] do
        assert targeted(state, skill_id) == {:refuse, :silent}
      end
    end
  end

  describe "targeted/5 in an NPC dialog" do
    @describetag game_mode: :renewal
    test "renewal refuses with the busy notice, a self skill included by default", %{
      state: state
    } do
      dialog = in_dialog(state)

      assert targeted(dialog, @fire_bolt) == {:refuse, {:notice, :SYSTEM_NOTICE_ID_BUSY}}
      assert targeted(dialog, @first_aid) == {:refuse, {:notice, :SYSTEM_NOTICE_ID_BUSY}}
    end

    test "a self skill passes once the script enables item use, unless a work flag is held",
         %{state: state} do
      enabled = %{in_dialog(state) | npc_item_flag: true}

      assert {:use, _} = targeted(enabled, @first_aid)
      assert targeted(enabled, @fire_bolt) == {:refuse, {:notice, :SYSTEM_NOTICE_ID_BUSY}}

      working = %{enabled | pending_skill_menu: %{kind: :OPTIONS}}
      assert targeted(working, @first_aid) == {:refuse, {:notice, :SYSTEM_NOTICE_ID_BUSY}}
    end

    test "the dialog refusal comes before sitting", %{state: state} do
      seated = state |> in_dialog() |> put_action(:sitting)
      assert targeted(seated, @fire_bolt) == {:refuse, {:notice, :SYSTEM_NOTICE_ID_BUSY}}
    end
  end

  describe "targeted/5 in a pre-renewal NPC dialog" do
    @describetag game_mode: :pre_renewal
    test "a self skill passes by default and anything else is refused silently", %{
      state: state
    } do
      dialog = in_dialog(state)

      assert {:use, _} = targeted(dialog, @first_aid)
      assert targeted(dialog, @fire_bolt) == {:refuse, :silent}
    end
  end

  describe "targeted/5 while held" do
    test "a trade, chat room, vending stall, storage window or stun refuses silently", %{
      state: state
    } do
      held = [
        %{state | trade: %{pid: self(), monitor: make_ref(), partner_char_id: 1}},
        put_in(state.game_state.waiting_room, 1),
        put_action(state, :vending),
        put_in(state.game_state.storage, %{})
      ]

      for held_state <- held, do: assert(targeted(held_state, @fire_bolt) == {:refuse, :silent})

      stub_body_state(3)
      assert targeted(state, @fire_bolt) == {:refuse, :silent}
    end

    test "Burning does not hold the player", %{state: state} do
      stub_body_state(7)
      assert {:use, _} = targeted(state, @fire_bolt)
    end

    test "an open storage window lets a self skill through, even while stunned", %{state: state} do
      stub_body_state(3)
      storage = put_in(state.game_state.storage, %{})

      assert {:use, _} = targeted(storage, @first_aid)
      assert targeted(storage, @fire_bolt) == {:refuse, :silent}
    end

    test "sitting refuses silently", %{state: state} do
      assert targeted(put_action(state, :sitting), @first_aid) == {:refuse, :silent}
    end
  end

  describe "not_ok/3" do
    test "noskill refuses silently unless an item skill is pending", %{state: state} do
      stub(MapFlags, :get, fn _map, flag -> flag == :noskill end)

      assert targeted(state, @fire_bolt) == {:refuse, :silent}
      assert {:use, _} = targeted(with_item_skill(state, @first_aid, 1), @fire_bolt)
    end

    test "a cooldown refuses silently, or with the delay failure under @showdelay", %{
      state: state
    } do
      cooling = put_in(state.game_state.skill_cooldowns, %{@fire_bolt => @now + 5000})

      assert targeted(cooling, @fire_bolt) == {:refuse, :silent}

      shown = put_in(cooling.game_state.show_delay, true)
      assert targeted(shown, @fire_bolt) == {:refuse, {:fail, :skill_interval}}
    end

    test "the map restriction shows the area notice, and an item skill skips it", %{
      state: state
    } do
      stub(NoCast, :refused?, fn @teleport, "prontera" -> true end)

      assert targeted(state, @teleport) ==
               {:refuse, {:notice, :SYSTEM_NOTICE_ID_IMPOSSIBLE_SKILL_AREA}}

      assert {:use, %{origin: :item}} = targeted(with_item_skill(state, @teleport, 1), @teleport)

      keeping = with_item_skill(state, @teleport, 1, true)
      assert {:refuse, {:notice, _}} = targeted(keeping, @teleport)
    end

    test "a cooldown is checked before the map restriction, after noskill", %{state: state} do
      stub(NoCast, :refused?, fn _skill_id, _map -> true end)
      cooling = put_in(state.game_state.skill_cooldowns, %{@teleport => @now + 5000})
      cooling = put_in(cooling.game_state.show_delay, true)

      assert targeted(cooling, @teleport) == {:refuse, {:fail, :skill_interval}}

      stub(MapFlags, :get, fn _map, flag -> flag == :noskill end)
      assert targeted(cooling, @teleport) == {:refuse, :silent}
    end

    test "Teleport refuses a noteleport map with its map notice", %{state: state} do
      stub(MapFlags, :get, fn _map, flag -> flag == :noteleport end)

      assert targeted(state, @teleport) ==
               {:refuse, {:notice, :SYSTEM_NOTICE_ID_MAP_CANT_TELEPORT}}
    end

    test "a Teleport item skill above level 2 passes every map restriction", %{state: state} do
      stub(MapFlags, :get, fn _map, flag -> flag in [:noskill, :noteleport] end)
      stub(NoCast, :refused?, fn _skill_id, _map -> true end)

      assert {:use, %{level: 3}} = targeted(with_item_skill(state, @teleport, 3), @teleport)
    end

    test "Ice Wall refuses a noicewall map and Urgent Call any map off GvG ground", %{
      state: state
    } do
      stub(MapFlags, :get, fn _map, flag -> flag == :noicewall end)
      assert ground(state, @ice_wall) == {:refuse, {:fail, :failed}}

      assert targeted(state, @emergency_call) == {:refuse, {:fail, :failed}}

      stub(MapFlags, :gvg2?, fn "prontera" -> true end)
      assert {:use, _} = targeted(state, @emergency_call)
    end

    test "Vending refuses a novending map with its line and a failure, before the cell", %{
      state: state
    } do
      stub(MapFlags, :get, fn _map, flag -> flag == :novending end)
      stub(MapCache, :get, fn "prontera" -> {:ok, :map} end)
      stub(MapData, :check_cell, fn :map, 50, 50, :chk_novending -> true end)
      stub(Proximity, :npc_near?, fn _map, _x, _y -> true end)

      assert SkillRequest.not_ok(state, 41, @now) ==
               {:refuse, {:message, "You can't open a shop on this map", {:fail, :failed}}}
    end

    test "Vending refuses a novending cell with its line and a failure, before a nearby NPC", %{
      state: state
    } do
      stub(MapCache, :get, fn "prontera" -> {:ok, :map} end)
      stub(MapData, :check_cell, fn :map, 50, 50, :chk_novending -> true end)
      stub(Proximity, :npc_near?, fn _map, _x, _y -> true end)

      assert SkillRequest.not_ok(state, 41, @now) ==
               {:refuse, {:message, "You can't open a shop on this cell.", {:fail, :failed}}}
    end

    test "Vending refuses with an NPC within three cells", %{state: state} do
      stub(Proximity, :npc_near?, fn "prontera", 50, 50 -> true end)
      assert SkillRequest.not_ok(state, 41, @now) == {:refuse, {:fail, :npc_nearby}}
    end
  end

  describe "targeted/5 readiness" do
    test "a cast in flight refuses silently, except Cast Cancel, which skips the act delay", %{
      state: state
    } do
      casting = put_in(state.game_state.casting, %{skill_id: @fire_bolt})
      delayed = put_in(casting.game_state.act_delay_until, @now + 5000)

      assert targeted(casting, @first_aid) == {:refuse, :silent}
      assert {:use, _} = targeted(delayed, @cast_cancel)
    end

    test "the act delay refuses with the delay reply unless the skill comes from an item", %{
      state: state
    } do
      delayed = put_in(state.game_state.act_delay_until, @now + 5000)

      assert targeted(delayed, @fire_bolt) == {:refuse, :silent}

      assert targeted(put_in(delayed.game_state.show_delay, true), @fire_bolt) ==
               {:refuse, {:fail, :skill_interval}}

      assert {:use, %{origin: :item}} =
               targeted(with_item_skill(delayed, @fire_bolt, 1), @fire_bolt)
    end

    test "the act delay comes after the map restriction", %{state: state} do
      stub(NoCast, :refused?, fn _skill_id, _map -> true end)
      delayed = put_in(state.game_state.act_delay_until, @now + 5000)

      assert {:refuse, {:notice, :SYSTEM_NOTICE_ID_IMPOSSIBLE_SKILL_AREA}} =
               targeted(delayed, @fire_bolt)
    end

    @tag game_mode: :pre_renewal
    test "Basilica holds everyone but its caster ending it", %{state: state} do
      stub(StatusStorage, :has_status?, fn :player, @id, status -> status == :sc_basilica end)
      assert targeted(state, @first_aid) == {:refuse, :silent}

      stub(StatusStorage, :has_status?, fn :player, @id, status ->
        status == :sc_basilica_caster
      end)

      assert targeted(state, @first_aid) == {:refuse, :silent}
      assert {:use, _} = targeted(state, @basilica)
    end

    @tag game_mode: :renewal
    test "renewal Basilica holds no one", %{state: state} do
      stub(StatusStorage, :has_status?, fn :player, @id, _status -> true end)
      assert {:use, _} = targeted(state, @first_aid)
    end

    test "an open menu refuses silently, except Autospell's", %{state: state} do
      menus = [
        %{state | pending_skill_menu: %{skill_id: 27, kind: :OPTIONS}},
        %{state | interaction_lock: {nil, nil, SessionState.system_dialog_gid()}},
        %{state | pending_skill_text_input: :pending}
      ]

      for menu_state <- menus, do: assert(targeted(menu_state, @first_aid) == {:refuse, :silent})

      autospell = %{state | pending_skill_menu: %{skill_id: @autospell, kind: :SKILL}}
      assert {:use, _} = targeted(autospell, @first_aid)
    end
  end

  describe "targeted/5 use" do
    test "a self skill is aimed at the user, a combo follow-up keeps the client's target", %{
      state: state
    } do
      assert {:use, %{target: @id}} = targeted(state, @first_aid, 1, 777)
      assert {:use, %{target: 777}} = targeted(state, @chain_combo, 1, 777)
      assert {:use, %{target: 777}} = targeted(state, @fire_bolt, 1, 777)
    end

    test "a skill runs at the requested level, at least 1, capped by the player's own", %{
      state: state
    } do
      learned = learn(state, @fire_bolt, 5)

      assert {:use, %{origin: :skill, level: 3}} = targeted(learned, @fire_bolt, 3)
      assert {:use, %{level: 5}} = targeted(learned, @fire_bolt, 9)
      assert {:use, %{level: 1}} = targeted(learned, @fire_bolt, 0)
      assert {:use, %{level: 0}} = targeted(state, @fire_bolt, 3)
    end

    test "an ordinary request ends the invincibility and clears a pending item skill", %{
      state: state
    } do
      pending = with_item_skill(state, @teleport, 1)

      assert {:use, %{ends_invincibility?: true, clears_item_skill?: true}} =
               targeted(pending, @fire_bolt)
    end

    test "an item skill runs at the item's level and spares the invincibility when self-aimed",
         %{state: state} do
      assert {:use, %{origin: :item, level: 4, ends_invincibility?: false}} =
               targeted(with_item_skill(state, @first_aid, 4), @first_aid, 1)

      assert {:use, %{origin: :item, ends_invincibility?: true, clears_item_skill?: false}} =
               targeted(with_item_skill(state, @fire_bolt, 4), @fire_bolt, 1)
    end
  end

  describe "ground/5" do
    test "a skill that is not a ground skill is refused silently", %{state: state} do
      assert ground(state, @fire_bolt) == {:refuse, :silent}
    end

    @tag game_mode: :renewal
    test "renewal refuses a held work flag with the busy notice", %{state: state} do
      working = %{state | pending_skill_menu: %{kind: :OPTIONS}}
      assert ground(working, @thunderstorm) == {:refuse, {:notice, :SYSTEM_NOTICE_ID_BUSY}}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal refuses a held work flag silently", %{state: state} do
      working = %{state | pending_skill_menu: %{kind: :OPTIONS}}
      assert ground(working, @thunderstorm) == {:refuse, :silent}
    end

    test "a dialog, trade, storage window, sitting or stun does not refuse it", %{state: state} do
      stub_body_state(3)

      held = [
        in_dialog(state),
        %{state | trade: %{pid: self(), monitor: make_ref(), partner_char_id: 1}},
        put_in(state.game_state.storage, %{}),
        put_action(state, :sitting),
        put_action(state, :vending)
      ]

      for held_state <- held,
          do: assert({:use, _} = ground(learn(held_state, @thunderstorm, 1), @thunderstorm))
    end

    test "a skill asking for text fails generically while sitting", %{state: state} do
      stub(Aesir.ZoneServer.Unit.Player.Handlers.SkillTextInputHandler, :input_required?, fn
        @thunderstorm -> true
      end)

      assert ground(put_action(state, :sitting), @thunderstorm) == {:refuse, {:fail, :failed}}
      assert {:use, _} = ground(state, @thunderstorm)
    end

    test "casting refuses silently and the act delay with the delay reply", %{state: state} do
      casting = put_in(state.game_state.casting, %{skill_id: @fire_bolt})
      assert ground(casting, @thunderstorm) == {:refuse, :silent}

      delayed = put_in(state.game_state.act_delay_until, @now + 5000)
      delayed = put_in(delayed.game_state.show_delay, true)
      assert ground(delayed, @thunderstorm) == {:refuse, {:fail, :skill_interval}}
    end

    test "a level 0 request, or one for a skill the player lacks, runs at level 0", %{
      state: state
    } do
      learned = learn(state, @thunderstorm, 5)

      assert {:use, %{level: 3, ends_invincibility?: true}} = ground(learned, @thunderstorm, 3)
      assert {:use, %{level: 5}} = ground(learned, @thunderstorm, 9)
      assert {:use, %{level: 0}} = ground(learned, @thunderstorm, 0)
      assert {:use, %{level: 0, ends_invincibility?: true}} = ground(state, @thunderstorm, 3)
    end

    test "an item skill runs at the item's level", %{state: state} do
      assert {:use, %{origin: :item, level: 2, ends_invincibility?: true}} =
               ground(with_item_skill(state, @thunderstorm, 2), @thunderstorm, 0)
    end
  end

  defp targeted(state, skill_id, level \\ 1, target \\ 777),
    do: SkillRequest.targeted(state, skill_id, level, target, @now)

  defp ground(state, skill_id, level \\ 1),
    do: SkillRequest.ground(state, skill_id, level, {55, 55}, @now)

  defp in_dialog(state), do: %{state | interaction_lock: @npc_lock}
  defp put_action(state, action), do: put_in(state.game_state.action_state, action)

  defp learn(state, skill_id, level),
    do: put_in(state.game_state.stats.progression.learned_skills, %{skill_id => level})

  defp with_item_skill(state, skill_id, level, keep? \\ false),
    do: %{
      state
      | pending_item_skill: %{skill_id: skill_id, level: level, keep_requirement?: keep?}
    }

  defp stub_body_state(body_state) do
    stub(StatusDisplay, :spawn_state, fn :player, @id ->
      %{body_state: body_state, health_state: 0, effect_state: 0, virtue: 0}
    end)
  end

  defp session_state do
    character = %Character{
      id: @id,
      account_id: 2,
      name: "Wizard",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 1,
      job_level: 1,
      class: 0
    }

    game_state = %{PlayerState.new(character) | pending_map_load: nil}
    game_state = put_in(game_state.stats.progression.learned_skills, %{})
    %SessionState{connection_pid: self(), game_state: %{game_state | act_delay_until: 0}}
  end
end
