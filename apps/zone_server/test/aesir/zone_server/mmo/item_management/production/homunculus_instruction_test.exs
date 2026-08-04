defmodule Aesir.ZoneServer.Mmo.ItemManagement.Production.HomunculusInstructionTest do
  use Aesir.DataCase, async: false
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Mmo.Homunculus.Stats, as: HomunculusStats
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Forge
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes.Recipe
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.SuccessRate
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :verify_on_exit!

  setup do
    previous_rng = Application.get_env(:zone_server, :forge_rng)

    on_exit(fn ->
      if previous_rng,
        do: Application.put_env(:zone_server, :forge_rng, previous_rng),
        else: Application.delete_env(:zone_server, :forge_rng)
    end)

    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "instruction#{suffix}",
        userid: "instruction#{suffix}",
        user_pass: "password",
        email: "instruction#{suffix}@test.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Instruction#{suffix}",
        class: 18,
        base_level: 99,
        job_level: 1,
        str: 1,
        int: 1,
        dex: 1,
        luk: 1
      })
      |> Repo.insert!()

    stats =
      character
      |> Stats.from_character()
      |> put_in([Access.key!(:base_stats), Access.key!(:int)], 0)
      |> put_in([Access.key!(:base_stats), Access.key!(:dex)], 0)
      |> put_in([Access.key!(:base_stats), Access.key!(:luk)], 0)
      |> put_in([Access.key!(:progression), Access.key!(:job_level)], 0)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{228 => 1})

    %{caster: %PlayerState{character_id: character.id, stats: stats}, character: character}
  end

  test "pharmacy adds exactly one percentage point per Instruction Change rank and clamps" do
    params = pharmacy_params()

    assert SuccessRate.pharmacy(999, params) == 300
    assert SuccessRate.pharmacy(999, %{params | instruction_change_rank: 3}) == 600

    assert SuccessRate.pharmacy(7139, %{
             params
             | skill_level: 0,
               instruction_change_rank: 0,
               random_term: -1000
           }) == 1

    assert SuccessRate.pharmacy(999, %{params | instruction_change_rank: 200}) == 10_000
  end

  test "Instruction Change rank is limited to original and evolved Vanilmirth" do
    assert HomunculusStats.instruction_change_rank(nil) == 0
    assert HomunculusStats.instruction_change_rank(homunculus(6_004, %{})) == 0
    assert HomunculusStats.instruction_change_rank(homunculus(6_001, %{8_015 => 5})) == 0
    assert HomunculusStats.instruction_change_rank(homunculus(6_004, %{8_015 => 3})) == 3
    assert HomunculusStats.instruction_change_rank(homunculus(6_012, %{8_015 => 5})) == 5
    assert HomunculusStats.instruction_change_rank(homunculus(6_004, %{8_015 => "5"})) == 0
    assert HomunculusStats.instruction_change_rank(homunculus(6_004, %{8_015 => -1})) == 0
  end

  test "seeded Forge rank changes only the pharmacy result threshold", %{caster: caster} do
    seed_boundary_rng()
    caster = %{caster | inventory: %{0 => material()}}

    assert {:ok, failed} = Forge.run(caster, pharmacy_recipe(), [], 0)
    assert {:ok, brewed} = Forge.run(caster, pharmacy_recipe(), [], 1)

    assert ItemContainer.held_amount(failed.inventory, 1002) == 0
    assert ItemContainer.held_amount(brewed.inventory, 1002) == 0
    assert ItemContainer.held_amount(failed.inventory, 501) == 0
    assert ItemContainer.held_amount(brewed.inventory, 501) == 1
    assert failed.pending_production_result == %{success: false, item_id: 501}
    assert brewed.pending_production_result == %{success: true, item_id: 501}
    assert length(failed.pending_inventory_persist) == 1
    assert length(brewed.pending_inventory_persist) == 1
  end

  test "real Pharmacy menu only applies an active living Vanilmirth's rank",
       %{caster: caster, character: character} do
    seed_boundary_rng()

    active = homunculus(6_004, %{8_015 => 1})
    rested = %{active | lifecycle: :rested}
    dead = %{active | lifecycle: :dead, action_state: :dead, hp: 0}

    assert menu_result(caster, character, active) == :success
    assert menu_result(caster, character, nil) == :failure
    assert menu_result(caster, character, rested) == :failure
    assert menu_result(caster, character, dead) == :failure
    assert menu_result(caster, character, homunculus(6_001, %{8_015 => 5})) == :failure
  end

  test "a representative three-arity menu skill still routes unchanged" do
    expect(StatusInterpreter, :apply_status, fn :player, 1, :sc_autospell, _params -> :ok end)

    state = %SessionState{
      game_state: %PlayerState{
        character_id: 1,
        map_name: "prontera",
        stats: %{progression: %{learned_skills: %{14 => 10}}}
      },
      connection_pid: self(),
      pending_skill_menu: %{skill_id: 279, kind: :SKILLS, entry_ids: [14], level: 3}
    }

    assert {:noreply, routed} =
             SkillMenuHandler.handle_reply(
               %SkillMenuReply{src_skill_id: 279, selected_id: 14},
               state
             )

    assert routed.pending_skill_menu == nil
  end

  defp menu_result(caster, character, homunculus) do
    inventory =
      [7144, 507, 1093]
      |> Enum.with_index()
      |> Map.new(fn {item_id, index} ->
        row =
          %InventoryItem{}
          |> InventoryItem.changeset(%{
            char_id: character.id,
            nameid: item_id,
            amount: 1,
            identify: 1
          })
          |> Repo.insert!()

        {index, row}
      end)

    state = %SessionState{
      game_state: %{caster | inventory: inventory},
      connection_pid: self(),
      homunculus: homunculus,
      pending_skill_menu: %{skill_id: 228, kind: :ITEMS, entry_ids: [501], level: 1}
    }

    assert {:noreply, routed} =
             SkillMenuHandler.handle_reply(
               %SkillMenuReply{src_skill_id: 228, selected_id: 501},
               state
             )

    assert routed.pending_skill_menu == nil
    assert routed.game_state.pending_inventory_persist == []
    assert routed.game_state.pending_inventory_notify == []
    assert ItemContainer.held_amount(routed.game_state.inventory, 7144) == 1
    assert ItemContainer.held_amount(routed.game_state.inventory, 507) == 0
    assert ItemContainer.held_amount(routed.game_state.inventory, 1093) == 0

    if ItemContainer.held_amount(routed.game_state.inventory, 501) == 1,
      do: :success,
      else: :failure
  end

  defp seed_boundary_rng do
    Application.put_env(:zone_server, :forge_rng, fn
      991 -> 1
      10_000 -> 2_350
    end)
  end

  defp pharmacy_params do
    %{
      job_level: 0,
      int: 0,
      dex: 0,
      luk: 0,
      skill_level: 1,
      learned_skills: %{},
      instruction_change_rank: 0,
      random_term: 0
    }
  end

  defp homunculus(class_id, learned_skills) do
    %HomunculusState{
      id: 1,
      owner_character_id: 1,
      class_id: class_id,
      name: "Homunculus",
      lifecycle: :active,
      hp: 1,
      learned_skills: learned_skills
    }
  end

  defp pharmacy_recipe do
    %Recipe{
      id: 119,
      product_id: 501,
      item_level: 22,
      skill_id: 228,
      skill_level: 1,
      materials: [%{item_id: 1002, amount: 1}]
    }
  end

  defp material, do: %InventoryItem{nameid: 1002, amount: 1, identify: 1}
end
