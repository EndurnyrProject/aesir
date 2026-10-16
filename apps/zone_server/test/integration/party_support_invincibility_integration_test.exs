defmodule Aesir.ZoneServer.Integration.PartySupportInvincibilityIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.Invincibility

  @map "prontera"
  @angelus 33

  setup {Aesir.MimicMode, :global}

  # Long enough that only a request of the member's own could end it.
  setup do
    stub(Invincibility, :default_time, fn -> 60_000 end)
    :ok
  end

  test "a party buff cast through the session skips an invincible member" do
    caster_character = insert_character("Caster", %{"#{@angelus}" => 1})
    ally_character = insert_character("Ally", %{})
    loaded_character = insert_character("Loaded", %{})

    {:ok, _party} = PartyManager.create("Angels#{caster_character.id}", caster_character)
    party_id = Repo.get!(Character, caster_character.id).party_id
    {:ok, _party} = PartyManager.add_member(party_id, ally_character)
    {:ok, _party} = PartyManager.add_member(party_id, loaded_character)

    caster = start_member(caster_character, {150, 150})
    ally = start_member(ally_character, {152, 150})
    loaded = start_member(loaded_character, {153, 150})

    simulate_incoming_message(loaded.pid, %MapLoaded{})
    assert_eventually(fn -> Invincibility.active?({:player, loaded.character.id}) end)

    simulate_incoming_message(caster.pid, %SkillCast{
      skill_id: @angelus,
      level: 1,
      target_id: caster.character.id
    })

    assert eventually(fn ->
             StatusStorage.has_status?(:player, caster.character.id, :sc_angelus) and
               StatusStorage.has_status?(:player, ally.character.id, :sc_angelus)
           end)

    refute StatusStorage.has_status?(:player, loaded.character.id, :sc_angelus)
  end

  defp start_member(character, position) do
    start_player_session(
      character: Repo.get!(Character, character.id),
      map_name: @map,
      position: position
    )
  end

  defp insert_character(name, learned_skills) do
    unique = System.unique_integer([:positive])
    userid = "invsup#{unique}"

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
        class: 4,
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
