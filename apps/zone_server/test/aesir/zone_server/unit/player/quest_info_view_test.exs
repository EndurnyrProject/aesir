defmodule Aesir.ZoneServer.Unit.Player.QuestInfoViewTest do
  @moduledoc """
  Covers the questinfo runtime: the `questinfo` DSL op registering into
  `Npc.QuestInfo` from an OnInit context, and `QuestInfoView.refresh/1`
  evaluating per-player conditions, diffing against the tracked display, and
  pushing `QuestInfoIcon` packets (show / no-op / clear).
  """

  use ExUnit.Case, async: false

  @moduletag :capture_log

  import Aesir.ZoneServer.Script.Dsl, only: [get_char_var: 3]

  alias Aesir.Net.QuestInfoIcon
  alias Aesir.ZoneServer.Npc.QuestInfo
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.QuestInfoView
  alias Aesir.ZoneServer.Unit.Player.SessionState

  defmodule QiNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 155, y: 180, sprite: 58, name: "Qi"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnInit", ctx) do
      questinfo(ctx, 0, 1, fn c -> get_char_var(c, :qi_flag, 0) == 1 end)
    end
  end

  setup do
    QuestInfo.reload()
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  defp game_state(vars, map \\ "prontera") do
    %PlayerState{
      character_id: 1,
      account_id: 100,
      map_name: map,
      vars: vars,
      temp_vars: %{},
      inventory: %{},
      quest_log: %{}
    }
  end

  defp session(vars, map \\ "prontera") do
    %SessionState{game_state: game_state(vars, map), connection_pid: self()}
  end

  test "the questinfo DSL op in OnInit registers the icon on the NPC's map" do
    Registry.reload([QiNpc])
    [{_module, placement}] = Registry.entries()
    gid = Registry.entity_id(placement)

    QiNpc.on_event("OnInit", Ctx.detached(QiNpc, gid))

    assert [%{gid: ^gid, x: 155, y: 180, entries: [entry]}] = QuestInfo.for_map("prontera")
    assert entry.icon == 0
    assert entry.color == 1
    assert is_function(entry.condition, 1)
  end

  test "refresh sends an icon packet when the condition passes" do
    QuestInfo.register(999, "prontera", 155, 180, 0, 1, fn c ->
      get_char_var(c, :qi_flag, 0) == 1
    end)

    QuestInfoView.refresh(session(%{"qi_flag" => 1}))

    assert_receive {:send, :world,
                    {:quest_info_icon,
                     %QuestInfoIcon{npc_id: 999, x: 155, y: 180, icon: 0, color: 1}}}
  end

  test "refresh sends nothing when the condition fails and nothing was shown" do
    QuestInfo.register(999, "prontera", 155, 180, 0, 1, fn c ->
      get_char_var(c, :qi_flag, 0) == 1
    end)

    QuestInfoView.refresh(session(%{"qi_flag" => 0}))
    refute_receive {:send, :world, {:quest_info_icon, _}}
  end

  test "a nil condition always shows" do
    QuestInfo.register(999, "prontera", 155, 180, 2, 0, nil)

    QuestInfoView.refresh(session(%{}))
    assert_receive {:send, :world, {:quest_info_icon, %QuestInfoIcon{npc_id: 999, icon: 2}}}
  end

  test "an unchanged icon is not re-sent, and a now-failing one is cleared" do
    QuestInfo.register(999, "prontera", 155, 180, 0, 1, fn c ->
      get_char_var(c, :qi_flag, 0) == 1
    end)

    state = QuestInfoView.refresh(session(%{"qi_flag" => 1}))
    assert_receive {:send, :world, {:quest_info_icon, %QuestInfoIcon{icon: 0}}}

    state = QuestInfoView.refresh(%{state | game_state: game_state(%{"qi_flag" => 1})})
    refute_receive {:send, :world, _}

    QuestInfoView.refresh(%{state | game_state: game_state(%{"qi_flag" => 0})})
    assert_receive {:send, :world, {:quest_info_icon, %QuestInfoIcon{npc_id: 999, icon: 9999}}}
  end

  test "the first passing entry wins when an NPC declares several icons" do
    gid = 777
    QuestInfo.register(gid, "prontera", 1, 2, 0, 1, fn c -> get_char_var(c, :stage, 0) == 1 end)
    QuestInfo.register(gid, "prontera", 1, 2, 7, 1, fn c -> get_char_var(c, :stage, 0) >= 1 end)

    QuestInfoView.refresh(session(%{"stage" => 2}))
    assert_receive {:send, :world, {:quest_info_icon, %QuestInfoIcon{npc_id: ^gid, icon: 7}}}
  end

  test "a map change resets prior display without sending stale clears" do
    QuestInfo.register(999, "prontera", 1, 2, 0, 1, nil)

    state = QuestInfoView.refresh(session(%{}))
    assert_receive {:send, :world, {:quest_info_icon, %QuestInfoIcon{npc_id: 999, icon: 0}}}

    QuestInfoView.refresh(%{state | game_state: game_state(%{}, "geffen")})
    refute_receive {:send, :world, _}
  end
end
