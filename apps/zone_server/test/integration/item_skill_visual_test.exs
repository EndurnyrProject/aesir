defmodule Aesir.ZoneServer.Integration.ItemSkillVisualTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.SkillEffect
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup do
    if GameMode.mode() == :renewal do
      Mimic.copy(Items)

      scripts = %{
        12216 =>
          ~s|if (Hp>15) { skilleffect "AL_INCAGI",0; sc_start SC_INCREASEAGI,240000,10; heal -15,0; }|,
        12217 =>
          ~s|if (countitem(523)>0) { skilleffect "PR_ASPERSIO",0; sc_start SC_ASPERSIO,180000,5; delitem 523,1; }|,
        12219 => ~s|skilleffect "SN_WINDWALK",0; sc_start SC_WINDWALK,250000,5;|,
        12414 =>
          ~s|sc_start SC_ASPDPOTION0,1800000,0; sc_start SC_INCREASEAGI,140000,5; skilleffect "AL_INCAGI",0;|
      }

      fixtures =
        Map.new(scripts, fn {id, script} ->
          {:ok, item} = Items.by_id(id)
          {:ok, source} = Transpiler.transpile(script)
          {id, %{item | on_use: source, no_use_sitting: id != 12414}}
        end)

      stub(Items, :by_id, fn id ->
        case Map.fetch(fixtures, id) do
          {:ok, item} -> {:ok, item}
          :error -> call_original(Items, :by_id, [id])
        end
      end)

      ScriptCompiler.compile_all!(Enum.map(Items.all(), &Map.get(fixtures, &1.id, &1)))
    else
      ScriptCompiler.compile_all!()
    end

    on_exit(fn -> ScriptCompiler.compile_all!() end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "scroll sitting refusal, HP cost and low-HP branch run through packet ingress" do
    character = character(16)
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 12216, amount: 2, identify: 1})
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 12219, amount: 1, identify: 1})
    session = start_player_session(character: character)
    on_exit(fn -> end_player_session(session) end)

    simulate_incoming_message(session.pid, %ActionRequest{action: 2})
    assert PlayerSession.get_state(session.pid).game_state.action_state == :sitting
    flush_packets()
    use_item(session, 12216)
    assert %ItemUseResult{ok: false} = assert_packet_sent(ItemUseResult)
    assert amount(session, 12216) == 2
    assert StatusStorage.get_status(:player, character.id, :sc_increaseagi) == nil

    simulate_incoming_message(session.pid, %ActionRequest{action: 3})
    assert PlayerSession.get_state(session.pid).game_state.action_state == :idle
    flush_packets()
    before = System.monotonic_time(:millisecond)
    use_item(session, 12216)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert %SkillEffect{skill_id: 29, level: 0} = assert_packet_sent(SkillEffect)
    assert PlayerSession.get_state(session.pid).game_state.stats.current_state.hp == 1
    status = StatusStorage.get_status(:player, character.id, :sc_increaseagi)
    assert status.val1 == 10
    assert status.expires_at >= before + 240_000
    assert status.expires_at <= System.monotonic_time(:millisecond) + 240_000

    flush_packets()
    use_item(session, 12216)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert amount(session, 12216) == 0
    assert PlayerSession.get_state(session.pid).game_state.stats.current_state.hp == 1
    assert collect_packets_of_type(SkillEffect) == []

    use_item(session, 12219)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert %SkillEffect{skill_id: 383} = assert_packet_sent(SkillEffect)
    assert %{val1: 5} = StatusStorage.get_status(:player, character.id, :sc_windwalk)
  end

  test "Aspersio deletes Holy Water inline and its empty-inventory branch still spends the scroll" do
    character = character(40)
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 12217, amount: 2, identify: 1})
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 523, amount: 1, identify: 1})
    session = start_player_session(character: character)
    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    use_item(session, 12217)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert %SkillEffect{skill_id: 68, level: 0} = assert_packet_sent(SkillEffect)
    assert amount(session, 523) == 0
    assert amount(session, 12217) == 1
    assert %{val1: 5} = StatusStorage.get_status(:player, character.id, :sc_aspersio)

    assert Persistence.load_inventory(character.id)
           |> Enum.all?(fn item -> item.nameid != 523 end)

    :ok = Interpreter.remove_status(:player, character.id, :sc_aspersio)
    flush_packets()
    use_item(session, 12217)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert amount(session, 12217) == 0
    assert StatusStorage.get_status(:player, character.id, :sc_aspersio) == nil
    assert collect_packets_of_type(SkillEffect) == []
  end

  test "an unrestricted consumable stands a seated player before its visual" do
    character = character(40)
    {:ok, _} = Persistence.insert_item(character.id, %{nameid: 12414, amount: 1, identify: 1})
    session = start_player_session(character: character)
    on_exit(fn -> end_player_session(session) end)
    simulate_incoming_message(session.pid, %ActionRequest{action: 2})
    assert PlayerSession.get_state(session.pid).game_state.action_state == :sitting
    flush_packets()

    use_item(session, 12414)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
    assert %SkillEffect{skill_id: 29} = assert_packet_sent(SkillEffect)
    assert PlayerSession.get_state(session.pid).game_state.action_state == :idle
    assert amount(session, 12414) == 0
    assert StatusStorage.get_status(:player, character.id, :sc_increaseagi)
    assert StatusStorage.get_status(:player, character.id, :sc_aspdpotion0)
  end

  defp use_item(session, nameid) do
    {index, _} =
      Enum.find(PlayerSession.get_state(session.pid).game_state.inventory, fn {_i, item} ->
        item.nameid == nameid
      end)

    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(session.pid)
  end

  defp amount(session, nameid) do
    session.pid
    |> PlayerSession.get_state()
    |> Map.fetch!(:game_state)
    |> Map.fetch!(:inventory)
    |> Enum.reduce(0, fn {_i, item}, sum ->
      if item.nameid == nameid, do: sum + item.amount, else: sum
    end)
  end

  defp character(hp) do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "visual#{unique}",
        user_pass: "password",
        email: "visual#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Visual#{unique}",
      class: 0,
      base_level: 10,
      job_level: 10,
      learned_skills: %{"1" => 3},
      hp: hp,
      max_hp: 100,
      sp: 11,
      max_sp: 11,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
