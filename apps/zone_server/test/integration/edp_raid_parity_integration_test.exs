defmodule Aesir.ZoneServer.Integration.EdpRaidParityIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.GameMode
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Net.UnequipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @moduletag :capture_log

  test "EDP ingress spends the mode's bottle and SP, and right-hand removal ends only renewal EDP" do
    character = character(4013, %{"378" => 5})

    {:ok, _knife} =
      Persistence.insert_item(character.id, %{nameid: 1201, amount: 1, identify: 1, equip: 2})

    {:ok, _bottle} = Persistence.insert_item(character.id, %{nameid: 678, amount: 1, identify: 1})

    if GameMode.mode() == :renewal do
      {:ok, _bound_bottle} =
        Persistence.insert_item(character.id, %{nameid: 22_549, amount: 1, identify: 1})
    end

    player = start_player_session(character: character, position: {100, 100})
    on_exit(fn -> if Process.alive?(player.pid), do: end_player_session(player) end)
    before = PlayerSession.get_state(player.pid).game_state

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: 378,
      level: 5,
      target_id: character.id
    })

    assert_eventually(fn -> StatusStorage.has_status?(:player, character.id, :sc_edp) end)
    after_cast = PlayerSession.get_state(player.pid).game_state
    assert after_cast.stats.current_state.sp == before.stats.current_state.sp - 100
    spent_id = if GameMode.mode() == :renewal, do: 22_549, else: 678
    assert Inventory.held_amount(after_cast.inventory, spent_id) == 0

    if GameMode.mode() == :renewal,
      do: assert(Inventory.held_amount(after_cast.inventory, 678) == 1)

    aura = if GameMode.mode() == :renewal, do: :sc_sub_weaponproperty, else: :sc_watk_element
    assert StatusStorage.has_status?(:player, character.id, aura)

    {knife_index, _} = Enum.find(after_cast.inventory, fn {_, item} -> item.nameid == 1201 end)

    simulate_incoming_message(player.pid, %UnequipItem{
      index: PlayerState.client_index(knife_index)
    })

    assert_eventually(fn ->
      PlayerSession.get_state(player.pid).game_state.stats.equipment.right_hand == nil
    end)

    assert StatusStorage.has_status?(:player, character.id, :sc_edp) ==
             (GameMode.mode() == :pre_renewal)

    assert StatusStorage.has_status?(:player, character.id, aura)
  end

  test "a real Raid packet breaks Hiding and damages a real trap without a cross-session deadlock" do
    character = character(17, %{"214" => 1, "51" => 1})

    {:ok, _knife} =
      Persistence.insert_item(character.id, %{nameid: 1201, amount: 1, identify: 1, equip: 2})

    player = start_player_session(character: character, position: {100, 100})
    on_exit(fn -> if Process.alive?(player.pid), do: end_player_session(player) end)
    caster = PlayerSession.get_state(player.pid).game_state
    assert {:ok, group} = Unit.place(caster, :ht_landmine, 1, {101, 100})
    [cell] = Storage.get_cells_by_group(group.group_id)
    assert cell.hp == 3_500

    assert :ok =
             Interpreter.apply_status(:player, character.id, :sc_hiding,
               caster_id: character.id,
               val1: 1,
               duration: 60_000
             )

    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    allow(HitCalculations, self(), player.pid)

    simulate_incoming_message(player.pid, %SkillCast{
      skill_id: 214,
      level: 1,
      target_id: character.id
    })

    assert_eventually(fn ->
      case Storage.get_cell(cell.cell_id) do
        %{hp: hp} -> hp < 3_500
        nil -> false
      end
    end)

    refute StatusStorage.has_status?(:player, character.id, :sc_hiding)
  end

  defp character(class, skills) do
    suffix = System.unique_integer([:positive])
    name = "w37#{suffix}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: name,
        userid: name,
        user_pass: "password",
        email: "#{name}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: name,
        class: class,
        base_level: 99,
        job_level: 50,
        str: 50,
        agi: 10,
        vit: 10,
        int: 50,
        dex: 50,
        luk: 0,
        hp: 5_000,
        max_hp: 5_000,
        sp: 1_000,
        max_sp: 1_000,
        learned_skills: skills,
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        save_map: "prontera",
        save_x: 100,
        save_y: 100
      })
      |> Repo.insert()

    character
  end
end
