defmodule Aesir.ZoneServer.Integration.CastAttemptParityTest do
  @moduledoc "Real player-session cast attempts and their timing status reactions."
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ItemSkillReady
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillCasting
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @memorize :sc_memorize
  @suffragium :sc_suffragium
  @fire_scroll 691
  @moon_cookie 11_702

  test "a preflight is inert, a failed attempt respects mode stage, and instant/timed attempts consume once" do
    player =
      start_player_session(
        name: "CastParity",
        sp: 100,
        max_sp: 100,
        learned_skills: %{"14" => 1, "28" => 1, "29" => 1}
      )

    char_id = player.character.id
    :ok = StatusInterpreter.apply_status(:player, char_id, @memorize, caster_id: char_id)

    :ok =
      StatusInterpreter.apply_status(:player, char_id, @suffragium,
        caster_id: char_id,
        val1: 3,
        duration: 10_000
      )

    {:error, _reason} =
      SkillInterpreter.preflight_cast(get_player_state(player.pid), 14, 1, {:unit, 99_999})

    assert charges(char_id) == 5
    simulate_incoming_message(player.pid, %SkillCast{skill_id: 14, level: 1, target_id: 99_999})

    expected = if GameMode.mode() == :pre_renewal, do: 4, else: 5
    assert eventually(fn -> charges(char_id) == expected end)
    assert StatusStorage.has_status?(:player, char_id, @suffragium)

    simulate_incoming_message(player.pid, %SkillCast{skill_id: 28, level: 1, target_id: char_id})
    assert eventually(fn -> charges(char_id) == expected - 1 end)

    if GameMode.mode() == :pre_renewal do
      refute StatusStorage.has_status?(:player, char_id, @suffragium)

      :ok =
        StatusInterpreter.apply_status(:player, char_id, @suffragium,
          caster_id: char_id,
          val1: 3,
          duration: 10_000
        )
    else
      assert StatusStorage.has_status?(:player, char_id, @suffragium)
    end

    assert eventually(fn ->
             get_player_state(player.pid).act_delay_until <= System.monotonic_time(:millisecond)
           end)

    simulate_incoming_message(player.pid, %SkillCast{skill_id: 29, level: 1, target_id: char_id})
    assert %SkillCasting{skill_id: 29} = assert_packet_sent(SkillCasting)
    assert eventually(fn -> charges(char_id) == expected - 2 end)
    assert eventually(fn -> get_player_state(player.pid).casting == nil end)
    assert charges(char_id) == expected - 2

    assert StatusStorage.has_status?(:player, char_id, @suffragium) ==
             (GameMode.mode() == :renewal)
  end

  test "an item stages one client-selected cast without learned or SP requirements" do
    player = start_item_player("ItemCast", @fire_scroll, 1)
    mob = start_mob_session(position: {151, 150}, awake: false)
    index = item_index(player, @fire_scroll)

    assert {:ok, _state} =
             PlayerSession.script_apply(
               player.pid,
               {:stage_item_skill, 19, 1, {index, @fire_scroll}}
             )

    assert %ItemSkillReady{skill_id: 19, level: 1, target_kind: :UNIT} =
             assert_packet_sent(ItemSkillReady)

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: 19,
      level: 1,
      target_id: mob.unit_id
    })

    assert %SkillCasting{skill_id: 19} = assert_packet_sent(SkillCasting)
    assert eventually(fn -> get_mob_state(mob.pid).hp < 100 end)
    assert get_player_state(player.pid).stats.current_state.sp == 100
    assert eventually(fn -> inventory_amount(player.pid, @fire_scroll) == 0 end)
  end

  test "an item skill used out of range spends its item and casts nothing" do
    player = start_item_player("ItemRange", @fire_scroll, 1)
    mob = start_mob_session(position: {190, 150}, awake: false)
    index = item_index(player, @fire_scroll)

    assert {:ok, _state} =
             PlayerSession.script_apply(
               player.pid,
               {:stage_item_skill, 19, 5, {index, @fire_scroll}}
             )

    assert %ItemSkillReady{skill_id: 19, level: 5} = assert_packet_sent(ItemSkillReady)

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: 19,
      level: 5,
      target_id: mob.unit_id
    })

    assert eventually(fn -> inventory_amount(player.pid, @fire_scroll) == 0 end)
    assert collect_packets_of_type(SkillCasting) == []
    assert collect_packets_of_type(SkillCastFailed) == []
    assert get_mob_state(mob.pid).hp == 100

    assert :sys.get_state(player.pid).pending_item_skill == %{
             skill_id: 19,
             level: 5,
             keep_requirement?: false
           }
  end

  test "silence does not stop a skill cast from an item, stun does" do
    player = start_item_player("Silenced", @fire_scroll, 2)
    mob = start_mob_session(position: {151, 150}, awake: false)
    id = player.character.id
    index = item_index(player, @fire_scroll)
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, id) end)

    cast_scroll = fn ->
      {:ok, _state} =
        PlayerSession.script_apply(player.pid, {:stage_item_skill, 19, 1, {index, @fire_scroll}})

      assert_packet_sent(ItemSkillReady)

      simulate_incoming_message(player.pid, %SkillCast{
        skill_id: 19,
        level: 1,
        target_id: mob.unit_id
      })
    end

    :ok = StatusStorage.apply_status(:player, id, :sc_stun, duration: 60_000)
    cast_scroll.()
    assert collect_packets_of_type(SkillCasting) == []
    assert inventory_amount(player.pid, @fire_scroll) == 2
    :ok = StatusStorage.remove_status(:player, id, :sc_stun)

    :ok = StatusStorage.apply_status(:player, id, :sc_silence, duration: 60_000)
    cast_scroll.()
    assert %SkillCasting{skill_id: 19} = assert_packet_sent(SkillCasting)
    assert eventually(fn -> get_mob_state(mob.pid).hp < 100 end)
    assert eventually(fn -> inventory_amount(player.pid, @fire_scroll) == 1 end)
  end

  test "a script starts a real cast of a skill the player never learned" do
    player = start_player_session(name: "ScriptCast", sp: 100, max_sp: 100)
    id = player.character.id
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, id) end)

    assert {:ok, _state} = PlayerSession.script_apply(player.pid, {:unitskilluseid, 34, 7})

    assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_blessing) end)
    assert get_player_state(player.pid).stats.current_state.sp == 100 - 52
  end

  @tag game_mode: :renewal, integration_pre_re: false
  test "a Moon Cookie's script casts Blessing on the player and is spent" do
    player = start_item_player("MoonCookie", @moon_cookie, 1)
    id = player.character.id
    index = item_index(player, @moon_cookie)
    on_exit(fn -> StatusStorage.clear_unit_statuses(:player, id) end)

    simulate_incoming_message(player.pid, %UseItem{index: PlayerState.client_index(index)})

    assert eventually(fn -> StatusStorage.has_status?(:player, id, :sc_blessing) end)
    assert eventually(fn -> inventory_amount(player.pid, @moon_cookie) == 0 end)
    assert get_player_state(player.pid).stats.current_state.sp == 100 - 52
  end

  # A character row of its own, because the consumed item's row is deleted
  # through the database and needs the foreign key.
  defp start_item_player(name, item_id, amount) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "item_#{unique}",
        user_pass: "password",
        sex: "M",
        email: "item_#{unique}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: 0,
        base_level: 1,
        job_level: 1,
        str: 5,
        agi: 5,
        vit: 5,
        int: 5,
        dex: 5,
        luk: 5,
        hp: 100,
        max_hp: 100,
        sp: 100,
        max_sp: 100,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    {:ok, _item} =
      InventoryPersistence.insert_item(character.id, %{
        nameid: item_id,
        amount: amount,
        identify: 1
      })

    start_player_session(character: character)
  end

  defp item_index(player, item_id) do
    player.pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Enum.find(fn {_index, item} -> item.nameid == item_id end)
    |> elem(0)
  end

  defp inventory_amount(pid, item_id) do
    pid
    |> get_player_state()
    |> Map.fetch!(:inventory)
    |> Map.values()
    |> Enum.filter(&(&1.nameid == item_id))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  defp charges(char_id) do
    case StatusStorage.get_status(:player, char_id, @memorize) do
      %{state: %{charges: n}} -> n
      _ -> 0
    end
  end
end
