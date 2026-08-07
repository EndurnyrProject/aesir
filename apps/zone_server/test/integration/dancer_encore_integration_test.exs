defmodule Aesir.ZoneServer.Integration.DancerEncoreIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "dancer_encore"
  @origin {150, 150}
  @adaptation 304
  @encore 305
  @gypsy_kiss 330
  @whip 1960
  @right_hand 2
  @garment 4
  @cooldown_garment 900_019

  setup do
    Mimic.copy(ItemManagement)

    stub(ItemManagement, :get_item_by_id, fn
      @cooldown_garment ->
        {:ok,
         %ItemDefinition{
           id: @cooldown_garment,
           aegis_name: "Dancer_Encore_Garment",
           name: "Dancer Encore Garment",
           type: :armor,
           locations: [:garment],
           on_equip: [{:bonus, {:skill_cooldown, @gypsy_kiss}, -20_000}]
         }}

      item_id ->
        call_original(ItemManagement, :get_item_by_id, [item_id])
    end)

    map_cache = EtsTable.table_for(:map_cache)
    :ets.insert(map_cache, {@map, MapData.new(@map, 200, 200)})

    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "Encore replays a Dancer dance after half-base, Gypsy's Kiss, and Adaptation costs" do
    dancer = start_dancer()

    cast(dancer, @gypsy_kiss, 10)

    assert eventually(fn ->
             state = get_player_state(dancer.pid)

             state.last_song == %{skill_id: @gypsy_kiss, level: 10} and
               StatusStorage.has_status?(:player, dancer.character.id, :sc_serviceforyou)
           end)

    first_expiry =
      StatusStorage.get_status(:player, dancer.character.id, :sc_serviceforyou).expires_at

    wait_for_act_ready(dancer.pid)
    cast(dancer, @adaptation, 1)

    assert eventually(fn ->
             StatusStorage.has_status?(:player, dancer.character.id, :sc_adaptation)
           end)

    wait_for_act_ready(dancer.pid)
    before_sp = player_sp(dancer.pid)
    cast(dancer, @encore, 1)
    assert wait_for_cast(dancer.pid, @encore)
    assert eventually(fn -> get_player_state(dancer.pid).casting == nil end)

    replayed = get_player_state(dancer.pid)
    assert before_sp - replayed.stats.current_state.sp == 29
    assert replayed.last_song == %{skill_id: @gypsy_kiss, level: 10}
    assert replayed.skill_cooldowns[@encore] > System.monotonic_time(:millisecond)

    replayed_status =
      StatusStorage.get_status(:player, dancer.character.id, :sc_serviceforyou)

    assert replayed_status.expires_at > first_expiry
  end

  defp start_dancer do
    character = insert_dancer()
    seed_inventory(character.id, @whip, @right_hand)
    seed_inventory(character.id, @cooldown_garment, @garment)
    session = start_player_session(character: character, map_name: @map, position: @origin)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_dancer do
    unique = System.unique_integer([:positive])
    userid = "dancer_encore#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "F",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "Encore#{unique}",
        class: 20,
        base_level: 99,
        job_level: 50,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills: %{
          Integer.to_string(@adaptation) => 1,
          Integer.to_string(@encore) => 1,
          Integer.to_string(@gypsy_kiss) => 10
        },
        last_map: @map,
        last_x: elem(@origin, 0),
        last_y: elem(@origin, 1),
        save_map: @map,
        save_x: elem(@origin, 0),
        save_y: elem(@origin, 1)
      }
      |> Character.new()
      |> Repo.insert()

    character
  end

  defp seed_inventory(character_id, nameid, equip) do
    {:ok, _item} =
      InventoryPersistence.insert_item(character_id, %{
        nameid: nameid,
        amount: 1,
        identify: 1,
        equip: equip
      })
  end

  defp cast(session, skill_id, level) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: session.character.id
    })
  end

  defp wait_for_cast(pid, skill_id) do
    assert eventually(fn ->
             match?(%{skill_id: ^skill_id}, get_player_state(pid).casting)
           end)

    get_player_state(pid).casting
  end

  defp wait_for_act_ready(pid) do
    assert eventually(fn ->
             PlayerState.act_ready?(get_player_state(pid), System.monotonic_time(:millisecond))
           end)
  end

  defp player_sp(pid), do: get_player_state(pid).stats.current_state.sp
end
