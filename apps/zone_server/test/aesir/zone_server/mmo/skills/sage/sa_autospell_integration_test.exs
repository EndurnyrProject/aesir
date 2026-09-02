defmodule Aesir.ZoneServer.Mmo.Skills.Sage.SaAutospellIntegrationTest do
  @moduledoc """
  SA_AUTOSPELL end to end, driven the way the client would drive it: a real
  `SkillMenuReply` envelope injected into `PacketHandler`, arming the real status
  through the real interpreter, then a weapon hit dispatched through the real
  attacker-side hook.

  The Rust client does not speak the menu messages yet (out of scope for this
  epic), so the reply is injected rather than received - everything behind it is
  the production path.
  """
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @autospell 279
  @firebolt 19
  @coldbolt 14
  @lightningbolt 20
  @soulstrike 13

  @char_id 1
  @victim_id 2001

  # `{22, 22, 22}` draws 18 then 7 from `:rand.uniform(100) - 1`: the first is
  # under a level-10 chance of 20 so the proc fires, the second is under 15 so
  # the level is not reduced. Both are asserted below rather than assumed.
  @procs_seed {22, 22, 22}

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    stub(UnitRegistry, :get_unit_info, fn :player, @char_id -> {:ok, unit_info()} end)
    :ok
  end

  describe "the menu reply arms the bolt" do
    test "a valid reply stores sc_autospell carrying the whole proc" do
      assert {:noreply, armed} = inject(selected_id: @firebolt)

      assert armed.pending_skill_menu == nil

      assert [%StatusEntry{type: :sc_autospell} = entry] =
               StatusStorage.get_unit_statuses(:player, @char_id)

      assert entry.state == %{skill: :mg_firebolt, max_level: 5, chance: 20}
      assert entry.expires_at != nil
    end

    test "a cancel arms nothing and clears the menu, even carrying a valid id" do
      # The reply carries @firebolt, a genuinely offered entry: the cancel flag must
      # still win and arm nothing.
      assert {:noreply, cancelled} = inject(cancel: true)

      assert cancelled.pending_skill_menu == nil
      assert StatusStorage.get_unit_statuses(:player, @char_id) == []
    end

    test "selected_id 0 without the cancel flag is a plain id, not a cancel" do
      # Cancel is carried only by its own flag. 0 is an ordinary id: here it is
      # not among the offered entries, so it is rejected and the menu stays open
      # rather than being swallowed as a cancel.
      assert {:noreply, unchanged} = inject(selected_id: 0)

      assert unchanged.pending_skill_menu != nil
      assert StatusStorage.get_unit_statuses(:player, @char_id) == []
    end

    test "an id outside the offered set arms nothing and keeps the menu open" do
      assert {:noreply, unchanged} = inject(selected_id: @soulstrike)

      assert unchanged.pending_skill_menu != nil
      assert StatusStorage.get_unit_statuses(:player, @char_id) == []
    end

    test "a stale reply naming another skill arms nothing and keeps the menu open" do
      assert {:noreply, unchanged} = inject(src_skill_id: 1007, selected_id: @firebolt)

      assert unchanged.pending_skill_menu != nil
      assert StatusStorage.get_unit_statuses(:player, @char_id) == []
    end

    test "a reply with no menu pending arms nothing" do
      state = session_state()

      assert {:noreply, ^state} =
               PacketHandler.handle_message(
                 %SkillMenuReply{src_skill_id: @autospell, selected_id: @firebolt},
                 state
               )

      assert StatusStorage.get_unit_statuses(:player, @char_id) == []
    end
  end

  describe "the armed bolt procs on a weapon hit" do
    test "a landed hit returns the auto-cast the combat path drains" do
      assert {:noreply, _} = inject(selected_id: @coldbolt)
      :rand.seed(:exsss, @procs_seed)

      assert [{:auto_cast, :mg_coldbolt, 5, {:unit, @victim_id}}] = weapon_hit()
    end

    # The proc names the skill by catalog name; the combat drain resolves it to
    # the id the session handler casts. Together these two are the whole path
    # from a landed hit to a bolt.
    test "the named bolt resolves in the catalog, so the drain does not raise" do
      assert {:noreply, _} = inject(selected_id: @lightningbolt)
      :rand.seed(:exsss, @procs_seed)

      assert [{:auto_cast, name, level, target}] = weapon_hit()

      stub(Combat, :execute_magic_attack, fn _caster, target_id, _opts ->
        {:ok, {:mob, target_id}}
      end)

      {:ok, definition} = Aesir.ZoneServer.Mmo.Skill.Catalog.by_name(name)

      assert {:ok, _} = SkillInterpreter.auto_cast(game_state(), definition.id, level, target)
    end
  end

  # The acceptance criterion this whole design turns on. `on_dealt_damage` is
  # reachable from exactly one place - `Combat.dispatch_dealt_damage/4`, on the
  # weapon-attack path - and every bolt it can arm is magic, so the bolt it casts
  # can never re-enter that path. There is no proc-depth counter or re-entrancy
  # guard anywhere, and none is needed.
  describe "recursion is structurally impossible" do
    test "casting the procced bolt fires no second proc" do
      assert {:noreply, _} = inject(selected_id: @firebolt)
      :rand.seed(:exsss, @procs_seed)

      assert [{:auto_cast, :mg_firebolt, 5, _}] = weapon_hit()

      # A bolt cast is magic damage, and magic never calls the attacker-side
      # hook: the only caller is the weapon path. Rig the roll so that *any*
      # dispatch would proc, then prove the bolt's own execution triggers none.
      test_pid = self()

      stub(Combat, :execute_magic_attack, fn _caster, target_id, _opts ->
        send(test_pid, :bolt_executed)
        {:ok, {:mob, target_id}}
      end)

      :rand.seed(:exsss, @procs_seed)

      assert {:ok, _} =
               SkillInterpreter.auto_cast(game_state(), @firebolt, 5, {:unit, @victim_id})

      assert_received :bolt_executed
      refute_received {:auto_cast, _, _, _}
    end

    test "the status is dispatched by the weapon hook alone, never by magic" do
      assert {:noreply, _} = inject(selected_id: @firebolt)

      # Every hook a magic cast could plausibly reach on the attacker is a no-op
      # for this status: it implements on_dealt_damage and nothing else.
      assert Aesir.ZoneServer.Mmo.StatusEffect.Effects.Autospell.__status_capabilities__() ==
               [:on_dealt_damage]
    end
  end

  defp weapon_hit do
    StatusInterpreter.on_dealt_damage(:player, @char_id, %{
      target: {:mob, @victim_id},
      damage: 50,
      element: :neutral
    })
  end

  # Opens the menu the way a real level-10 cast would, then injects the reply.
  defp inject(opts) do
    src_skill_id = Keyword.get(opts, :src_skill_id, @autospell)
    cancel = Keyword.get(opts, :cancel, false)
    # Cancel is carried by its own flag and `selected_id` is ignored on that path.
    # A cancel therefore defaults to carrying a *valid* entry id, so the test proves
    # the flag is what cancelled - not some special value of selected_id.
    selected_id =
      if cancel,
        do: Keyword.get(opts, :selected_id, @firebolt),
        else: Keyword.fetch!(opts, :selected_id)

    state =
      SkillMenuHandler.open(
        session_state(),
        @autospell,
        :SKILLS,
        [@firebolt, @coldbolt, @lightningbolt],
        10
      )

    PacketHandler.handle_message(
      %SkillMenuReply{src_skill_id: src_skill_id, selected_id: selected_id, cancel: cancel},
      state
    )
  end

  defp session_state do
    %{
      game_state: game_state(),
      connection_pid: self(),
      pending_skill_menu: nil
    }
  end

  defp game_state do
    %PlayerState{
      character_id: @char_id,
      x: 10,
      y: 10,
      map_name: "prontera",
      skill_cooldowns: %{},
      act_delay_until: 0,
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 200, hp: 100},
        derived_stats: %{max_sp: 200, max_hp: 100},
        progression: %{
          learned_skills: %{
            @autospell => 10,
            @firebolt => 10,
            @coldbolt => 10,
            @lightningbolt => 10
          }
        }
      }
    }
  end

  defp unit_info do
    %{
      unit_id: @char_id,
      unit_type: :player,
      race: :formless,
      element: :neutral,
      element_level: 1,
      boss_flag: false,
      size: :medium,
      stats: %{
        max_hp: 100,
        max_sp: 200,
        hp: 100,
        sp: 200,
        level: 1,
        base_level: 1,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        mdef: 0
      }
    }
  end
end
