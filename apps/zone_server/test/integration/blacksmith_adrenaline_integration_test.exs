defmodule Aesir.ZoneServer.Integration.BlacksmithAdrenalineIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @map "blacksmith_adrenaline"
  @axe 1301
  @dagger 1201
  @right_hand 2
  @skill_id 111

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 200, 200)})
    :ok
  end

  test "a real party cast buffs only axe and mace users" do
    caster_character = insert_character("Caster", %{"111" => 5})
    eligible_character = insert_character("Eligible", %{})
    ineligible_character = insert_character("Ineligible", %{})

    equip(caster_character.id, @axe)
    equip(eligible_character.id, @axe)
    equip(ineligible_character.id, @dagger)

    {:ok, _party} = PartyManager.create("Smiths#{caster_character.id}", caster_character)
    party_id = Repo.get!(Character, caster_character.id).party_id
    {:ok, _party} = PartyManager.add_member(party_id, eligible_character)
    {:ok, _party} = PartyManager.add_member(party_id, ineligible_character)

    caster =
      start_player_session(character: Repo.get!(Character, caster_character.id), map_name: @map)

    eligible =
      start_player_session(
        character: Repo.get!(Character, eligible_character.id),
        map_name: @map,
        position: {160, 150}
      )

    ineligible =
      start_player_session(
        character: Repo.get!(Character, ineligible_character.id),
        map_name: @map,
        position: {161, 150}
      )

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: @skill_id,
      level: 5,
      target_id: caster.character.id
    })

    assert eventually(fn ->
             StatusStorage.has_status?(:player, caster.character.id, :sc_adrenaline) and
               StatusStorage.has_status?(:player, eligible.character.id, :sc_adrenaline)
           end)

    refute StatusStorage.has_status?(:player, ineligible.character.id, :sc_adrenaline)
  end

  defp equip(char_id, nameid) do
    {:ok, _item} =
      InventoryPersistence.insert_item(char_id, %{
        nameid: nameid,
        amount: 1,
        identify: 1,
        equip: @right_hand
      })
  end

  defp insert_character(name, learned_skills) do
    unique = System.unique_integer([:positive])
    userid = "adrenaline#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{unique}",
        class: 10,
        base_level: 99,
        job_level: 50,
        hp: 500,
        max_hp: 500,
        sp: 500,
        max_sp: 500,
        learned_skills: learned_skills,
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150
      }
      |> Character.new()
      |> Repo.insert()

    character
  end
end
