defmodule Aesir.ZoneServer.Integration.NpcskillIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcTalk
  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Npc.Registry, as: NpcRegistry

  @position {150, 150}

  defmodule SupportNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 150, y: 150, dir: 0, sprite: 58, name: "Support NPC"}]

    @impl true
    def on_talk(ctx) do
      ctx
      |> npcskill(:al_heal, 10, 99, 60)
      |> npcskill(:al_blessing, 5, 99, 60)
      |> npcskill(:al_incagi, 5, 99, 60)
      |> npcskill(:pr_kyrie, 5, 99, 60)
      |> npcskill(:al_cure, 1, 99, 60)
      |> mes("Done")
      |> close()
    end
  end

  defmodule UnsupportedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 151, y: 150, dir: 0, sprite: 58, name: "Unsupported NPC"}]

    @impl true
    def on_talk(ctx) do
      ctx
      |> npcskill(:mg_firebolt, 10, 99, 60)
      |> mes("Still here")
      |> close()
    end
  end

  setup do
    on_exit(fn -> :persistent_term.erase(NpcRegistry) end)
    NpcRegistry.reload([SupportNpc, UnsupportedNpc])

    {:ok, support_gid: gid_for(SupportNpc), unsupported_gid: gid_for(UnsupportedNpc)}
  end

  test "a dialog heal restores exactly 1,145 HP and sends an NPC-sourced skill effect", %{
    support_gid: gid
  } do
    player = start_player(hp: 1)
    max_hp = get_player_state(player.pid).stats.derived_stats.max_hp
    hp_before = current_hp(player.pid)

    assert hp_before < max_hp - 1_145

    talk(player, gid)

    assert_eventually(fn -> current_hp(player.pid) == hp_before + 1_145 end)

    assert Enum.any?(collect_packets_of_type(SkillEffect), fn effect ->
             effect.skill_id == skill_id(:al_heal) and
               effect.src_id == gid and effect.target_id == player.character.id
           end)
  end

  test "a dialog applies Blessing, Increase AGI, and Kyrie with their real values", %{
    support_gid: gid
  } do
    player = start_player()
    char_id = player.character.id
    max_hp = get_player_state(player.pid).stats.derived_stats.max_hp

    talk(player, gid)

    blessing_duration = duration(:al_blessing, 5)

    assert_eventually(fn ->
      match?(
        %{val1: 5, val2: 5, source_id: ^gid},
        StatusStorage.get_status(:player, char_id, :sc_blessing)
      )
    end)

    assert %{started_at: started_at, expires_at: expires_at} =
             StatusStorage.get_status(:player, char_id, :sc_blessing)

    assert expires_at - started_at == blessing_duration

    assert_eventually(fn ->
      match?(
        %{val1: 5, val2: 7, source_id: ^gid},
        StatusStorage.get_status(:player, char_id, :sc_increaseagi)
      )
    end)

    assert_eventually(fn ->
      match?(
        %{val1: 5, val2: barrier, source_id: ^gid} when barrier == div(max_hp * 20, 100),
        StatusStorage.get_status(:player, char_id, :sc_kyrie)
      )
    end)
  end

  test "a dialog Cure removes Silence, Blind, and Confusion", %{support_gid: gid} do
    player = start_player()
    char_id = player.character.id

    for status <- [:sc_silence, :sc_blind, :sc_confusion] do
      assert :ok =
               StatusInterpreter.apply_status(:player, char_id, status,
                 duration: 10_000,
                 bypass_resistance: true
               )
    end

    assert Enum.all?(
             [:sc_silence, :sc_blind, :sc_confusion],
             &StatusStorage.has_status?(:player, char_id, &1)
           )

    talk(player, gid)

    assert_eventually(fn ->
      Enum.all?([:sc_silence, :sc_blind, :sc_confusion], fn status ->
        not StatusStorage.has_status?(:player, char_id, status)
      end)
    end)
  end

  test "an unsupported npcskill leaves the dialog alive and sends no skill effect", %{
    unsupported_gid: gid
  } do
    player = start_player()

    flush_packets()
    simulate_incoming_message(player.pid, %NpcTalk{npc_id: gid})

    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: "Still here"}, _}, 500
    assert collect_packets_of_type(SkillEffect) == []
    assert Process.alive?(player.pid)
  end

  defp start_player(opts \\ []) do
    player =
      start_player_session(
        Keyword.merge(
          [
            id: System.unique_integer([:positive]),
            name: "NpcSkill",
            base_level: 99,
            vit: 255,
            position: @position
          ],
          opts
        )
      )

    on_exit(fn -> end_player_session(player) end)
    player
  end

  defp talk(player, gid) do
    flush_packets()
    simulate_incoming_message(player.pid, %NpcTalk{npc_id: gid})
    assert_receive {:packet_sent, %NpcDialog{expect: :CLOSE, text: "Done"}, _}, 500
  end

  defp gid_for(module) do
    {^module, placement} = Enum.find(NpcRegistry.entries(), fn {mod, _} -> mod == module end)
    NpcRegistry.entity_id(placement)
  end

  defp skill_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp duration(name, level) do
    {:ok, definition} = Catalog.by_name(name)
    Enum.at(definition.duration, level - 1)
  end

  defp current_hp(pid), do: get_player_state(pid).stats.current_state.hp
end
