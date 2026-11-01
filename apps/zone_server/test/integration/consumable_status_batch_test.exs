defmodule Aesir.ZoneServer.Integration.ConsumableStatusBatchTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.CharacterStatus
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.UnequipItem
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipLocation
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @moduletag :capture_log
  @armor EquipLocation.location_bit(:armor)
  @scripts [
    {12274, "sc_start2 SC_INCREASE_MAXHP,3600000,5,10; percentheal 10,0;"},
    {12275, "sc_start2 SC_INCREASE_MAXSP,3600000,5,10; percentheal 0,10;"},
    {12375, "specialeffect2 EF_STEAL; sc_start2 SC_ACARAJE,1200000,10,5;"},
    {12279, "sc_start4 SC_ARMOR_RESIST,300000,20,20,20,20;"},
    {12299, "sc_start SC_COMMONSC_RESIST,3600000,10;"},
    {12342, "specialeffect2 EF_POTION_BERSERK; sc_start SC_MANU_ATK,600000,10;"},
    {12343, "specialeffect2 EF_GUARD; sc_start SC_MANU_DEF,600000,10;"},
    {12344, "specialeffect2 EF_POTION_BERSERK; sc_start SC_SPL_ATK,600000,10;"},
    {12345, "specialeffect2 EF_GUARD; sc_start SC_SPL_DEF,600000,10;"},
    {12348, "specialeffect2 EF_POTION_BERSERK; sc_start SC_MANU_MATK,600000,10;"},
    {12349, "specialeffect2 EF_POTION_BERSERK; sc_start SC_SPL_MATK,600000,10;"},
    {12436, "sc_start SC_VITATA_500,500000,0; itemheal 0,200;"},
    {14539, "specialeffect2 EF_CLOAKING; sc_start4 SC_ELEMENTALCHANGE,1800000,1,Ele_Dark,1,0;"},
    {14540, "specialeffect2 EF_BENEDICTIO; sc_start4 SC_ELEMENTALCHANGE,1800000,1,Ele_Holy,1,0;"},
    {14534, "specialeffect2 EF_HEAL3; sc_start4 SC_S_LIFEPOTION,600000,-5,5,0,0;"},
    {14535, "specialeffect2 EF_HEAL3; sc_start4 SC_L_LIFEPOTION,600000,-7,4,0,0;"}
  ]

  setup do
    if GameMode.mode() == :renewal do
      Mimic.copy(Items)

      fixtures =
        Map.new(@scripts, fn {id, script} ->
          script =
            case id do
              12436 -> "sc_start2 SC_VITATA_500,500000,20,5; itemheal 0,200;"
              14534 -> "specialeffect2 EF_HEAL3; sc_start2 SC_S_LIFEPOTION,600000,-5,5;"
              14535 -> "specialeffect2 EF_HEAL3; sc_start2 SC_L_LIFEPOTION,600000,-7,4;"
              _other -> script
            end

          {:ok, item} = Items.by_id(id)
          {:ok, source} = Transpiler.transpile(script)
          {id, %{item | on_use: source}}
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

  test "item ingress applies complete bonuses, armor removal clears resistance, and login restores values" do
    character = character()

    for {id, _script} <- @scripts do
      {:ok, _} = Persistence.insert_item(character.id, %{nameid: id, amount: 1, identify: 1})
    end

    {:ok, armor} =
      Persistence.insert_item(character.id, %{nameid: 2301, amount: 1, identify: 1, equip: @armor})

    session = start_player_session(character: character)
    on_exit(fn -> if Process.alive?(session.pid), do: GenServer.stop(session.pid, :normal) end)
    base = PlayerSession.get_state(session.pid).game_state.stats.derived_stats

    use_item(session, 12274)
    stats = PlayerSession.get_state(session.pid).game_state.stats
    assert stats.derived_stats.max_hp > base.max_hp
    assert stats.current_state.hp == 1 + div(stats.derived_stats.max_hp * 10, 100)
    assert stats.modifiers.status_effects.hp_regen == 10

    use_item(session, 12275)
    stats = PlayerSession.get_state(session.pid).game_state.stats
    assert stats.derived_stats.max_sp > base.max_sp
    assert stats.current_state.sp == 1 + div(stats.derived_stats.max_sp * 10, 100)
    assert stats.modifiers.status_effects.sp_regen == 10

    for {id, _script} <- Enum.drop(@scripts, 2), do: use_item(session, id)

    modifiers = ModifierCalculator.get_all_modifiers(:player, character.id)
    assert modifiers[{:addrace2, :manuk}] == 10
    assert modifiers[{:magic_addrace2, :splendide}] == 10
    assert modifiers[{:subrace2, :manuk}] == 10
    assert modifiers[{:res_eff, :sc_stun}] == 10
    assert modifiers.hp_regen == 10
    assert modifiers.sp_regen == 30
    assert modifiers.hit == 5
    assert modifiers.aspd_rate == 10
    assert modifiers.subele_water == 20
    assert modifiers.element_override == {:holy, 1}

    assert %{val1: 1, val2: 6, val3: 0} =
             StatusStorage.get_status(:player, character.id, :sc_elementalchange)

    armor_index = inventory_index(session, &(&1.id == armor.id))

    simulate_incoming_message(session.pid, %UnequipItem{
      index: PlayerState.client_index(armor_index)
    })

    PlayerSession.get_state(session.pid)
    refute StatusStorage.has_status?(:player, character.id, :sc_armor_resist)
    assert Enum.map(Persistence.load_inventory(character.id), & &1.nameid) == [2301]

    GenServer.stop(session.pid, :normal)
    saved = Repo.all(CharacterStatus)

    assert Enum.any?(
             saved,
             &(&1.status_type == "sc_s_lifepotion" and &1.val1 == -5 and &1.val2 == 5)
           )

    assert Enum.any?(saved, &(&1.status_type == "sc_increase_maxsp" and &1.val2 == 10))

    restored = start_player_session(character: Repo.get!(Character, character.id))
    on_exit(fn -> if Process.alive?(restored.pid), do: GenServer.stop(restored.pid, :normal) end)
    assert Repo.all(CharacterStatus) == []
    restored_modifiers = ModifierCalculator.get_all_modifiers(:player, character.id)
    assert restored_modifiers[{:percent_hp_regen_bonus, {:sc_s_lifepotion, 5_000}}] == 5
    assert restored_modifiers[{:percent_hp_regen_bonus, {:sc_l_lifepotion, 4_000}}] == 7
    assert restored_modifiers.element_override == {:holy, 1}
    assert restored_modifiers.sp_regen == 30
  end

  defp use_item(session, nameid) do
    index = inventory_index(session, &(&1.nameid == nameid))
    flush_packets()
    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})
    PlayerSession.get_state(session.pid)
    assert %ItemUseResult{ok: true} = assert_packet_sent(ItemUseResult)
  end

  defp inventory_index(session, matches?) do
    session.pid
    |> PlayerSession.get_state()
    |> Map.fetch!(:game_state)
    |> Map.fetch!(:inventory)
    |> Enum.find_value(fn {index, item} -> if matches?.(item), do: index end)
  end

  defp character do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "batch#{unique}",
        user_pass: "password",
        email: "batch#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Batch#{unique}",
      class: 0,
      base_level: 99,
      job_level: 1,
      hp: 1,
      sp: 1,
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
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
