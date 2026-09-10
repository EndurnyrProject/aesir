defmodule Aesir.ZoneServer.Mmo.Woe.RevivalEndureTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AllResurrection
  alias Aesir.ZoneServer.Mmo.Skills.Priest.PrRedemptio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "Resurrection rejects its corpse branch on castle ground" do
    caster = start_player_session(id: 11_001, name: "ReviveCaster", position: {150, 150})
    target = start_player_session(id: 11_002, name: "ReviveTarget", position: {151, 150})

    PlayerSession.apply_damage(target.pid, 1_000_000, caster.character.id)
    assert_eventually(fn -> get_player_state(target.pid).action_state == :dead end)
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)

    assert {:ok, definition} = Catalog.by_id(54)
    caster_state = get_player_state(caster.pid)

    assert {:error, :invalid_target} =
             AllResurrection.validate(
               caster_state,
               {:unit, target.character.id},
               4,
               definition
             )

    assert {:error, :invalid_target} =
             AllResurrection.cast(caster_state, {:unit, target.character.id}, 4, definition)

    assert get_player_state(target.pid).action_state == :dead
  end

  test "Resurrection still attacks a living undead target on castle ground" do
    caster = start_player_session(id: 11_005, name: "UndeadCaster", position: {150, 150})

    undead =
      start_mob_session(
        unit_id: 11_006,
        race: :undead,
        element: {:undead, 1},
        max_hp: 10_000,
        position: {151, 150}
      )

    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    assert {:ok, definition} = Catalog.by_id(54)
    caster_state = get_player_state(caster.pid)

    assert :ok =
             AllResurrection.validate(caster_state, {:unit, undead.unit_id}, 4, definition)

    assert {:ok, ^caster_state} =
             AllResurrection.cast(caster_state, {:unit, undead.unit_id}, 4, definition)
  end

  test "Endure admission follows siege-ground status rules for new and loaded effects" do
    player = start_player_session(id: 11_003, name: "EndureTarget")
    target_id = player.character.id

    assert :ok =
             StatusInterpreter.apply_status(:player, target_id, :sc_endure,
               duration: 30_000,
               bypass_resistance: true
             )

    assert StatusStorage.has_status?(:player, target_id, :sc_endure)
    assert :ok = StatusInterpreter.remove_status(:player, target_id, :sc_endure)
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)

    assert {:error, _reason} =
             StatusInterpreter.apply_status(:player, target_id, :sc_endure,
               duration: 30_000,
               bypass_resistance: true
             )

    assert {:error, _reason} =
             StatusInterpreter.apply_status(:player, target_id, :sc_endure,
               duration: 30_000,
               loaded: true
             )

    refute StatusStorage.has_status?(:player, target_id, :sc_endure)

    assert :ok =
             StatusInterpreter.apply_status(:player, target_id, :sc_provoke,
               duration: 30_000,
               loaded: true
             )

    assert StatusStorage.has_status?(:player, target_id, :sc_provoke)
  end

  test "entering siege ground removes an existing Endure through normal cleanup" do
    player = start_player_session(id: 11_004, name: "WarpEndure")
    target_id = player.character.id

    assert :ok =
             StatusInterpreter.apply_status(:player, target_id, :sc_endure,
               duration: 30_000,
               bypass_resistance: true
             )

    assert StatusStorage.has_status?(:player, target_id, :sc_endure)
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)
    :ok = PlayerSession.warp(player.pid, "prontera", 151, 150)

    assert_eventually(fn -> get_player_state(player.pid).x == 151 end)
    refute StatusStorage.has_status?(:player, target_id, :sc_endure)
  end

  test "Redemptio rejects castle ground before revival and its self-cost" do
    caster_character =
      character("redcaster", "RedCaster", %{
        class: 8,
        learned_skills: %{"1014" => 1},
        hp: 1_000,
        max_hp: 1_000,
        sp: 1_000,
        max_sp: 1_000
      })

    target_character = character("redtarget", "RedTarget")
    assert {:ok, party} = PartyManager.create("Redemptio", caster_character)
    assert {:ok, _party} = PartyManager.add_member(party.party_id, target_character)

    caster = start_player_session(character: Repo.reload!(caster_character), position: {150, 150})
    target = start_player_session(character: Repo.reload!(target_character), position: {151, 150})

    PlayerSession.apply_damage(target.pid, 1_000_000, caster.character.id)
    assert_eventually(fn -> get_player_state(target.pid).action_state == :dead end)
    :ok = MapFlags.set_runtime("prontera", :gvg_castle, true)

    caster_state = get_player_state(caster.pid)
    caster_vitals = caster_state.stats.current_state

    assert {:error, :invalid_target} =
             PrRedemptio.validate(caster_state, :self, 1, PrRedemptio.definition())

    assert {:error, :invalid_target} =
             SkillInterpreter.complete_cast(caster_state, 1014, 1, :self)

    assert get_player_state(caster.pid).stats.current_state == caster_vitals
    assert get_player_state(target.pid).action_state == :dead
  end

  defp character(userid, name, attrs \\ %{}) do
    account =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@example.com"
      })
      |> Repo.insert!()

    %{
      account_id: account.id,
      char_num: 0,
      name: name,
      class: 0,
      base_level: 99,
      last_map: "prontera",
      last_x: 150,
      last_y: 150
    }
    |> Map.merge(attrs)
    |> Character.new()
    |> Repo.insert!()
  end
end
