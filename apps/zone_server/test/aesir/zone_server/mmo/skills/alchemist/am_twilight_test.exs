defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmTwilightTest do
  use Aesir.DataCase, async: false
  use Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmTwilight1
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmTwilight2
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  @white_potion 504
  @white_slim 547
  @white_potion_materials [{7144, 1}, {509, 200}, {1093, 200}]
  @white_slim_materials [{7133, 1}, {504, 200}, {1092, 200}, {1061, 200}]

  setup :set_mimic_private

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
        username: "twi#{suffix}",
        userid: "twi#{suffix}",
        user_pass: "password",
        email: "twi#{suffix}@test.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Twi#{suffix}",
        class: 4019,
        base_level: 99,
        job_level: 50
      })
      |> Repo.insert!()

    stats = Stats.from_character(character)
    stats = put_in(stats.progression.learned_skills, %{228 => 10})
    {:ok, t1} = Catalog.by_id(496)
    {:ok, t2} = Catalog.by_id(497)

    %{
      caster: %PlayerState{character_id: character.id, stats: stats, party_id: 0},
      t1: t1,
      t2: t2
    }
  end

  describe "Twilight Alchemy 1" do
    test "brews 200 White Potions, each copy rolled, every material spent", %{
      caster: caster,
      t1: t1
    } do
      unit_rolls(List.duplicate(1, 150) ++ List.duplicate(10_000, 50))
      caster = holding(caster, @white_potion_materials)

      assert {:ok, made} = AmTwilight1.cast(caster, :self, 1, t1)
      assert ItemContainer.held_amount(made.inventory, @white_potion) == 150

      for {id, _amount} <- [{509, 0}, {1093, 0}],
          do: assert(ItemContainer.held_amount(made.inventory, id) == 0)

      assert ItemContainer.held_amount(made.inventory, 7144) == 1
      assert made.pending_production_result == %{success: true, item_id: @white_potion}
    end

    test "fails after showing itself when the batch cannot be made or nothing comes of it", %{
      caster: caster,
      t1: t1
    } do
      short = holding(caster, [{7144, 1}, {509, 199}, {1093, 200}])

      assert {:failed, ^short, :skill_failed, :after_effect} =
               AmTwilight1.cast(short, :self, 1, t1)

      unit_rolls(List.duplicate(10_000, 200))

      assert {:failed, failed, :skill_failed, :after_effect} =
               AmTwilight1.cast(holding(caster, @white_potion_materials), :self, 1, t1)

      assert ItemContainer.held_amount(failed.inventory, 509) == 0
      assert [%{success: true}, %{success: false}] = failed.pending_production_result
    end

    test "a batch that cannot be carried still spends its materials and reports success", %{
      caster: caster,
      t1: t1
    } do
      unit_rolls(List.duplicate(1, 200))

      # One copy of each material stays behind, so brewing frees no slot, and
      # light cards fill every other slot: only the missing slot refuses the add.
      filler =
        for slot <- 3..(Inventory.capacity() - 1), into: %{}, do: {slot, card(4_001 + slot)}

      caster = holding(caster, [{7144, 1}, {509, 201}, {1093, 201}])
      caster = %{caster | inventory: Map.merge(caster.inventory, filler)}
      caster = put_in(caster.stats.base_stats.str, 300)

      assert {:ok, made} = AmTwilight1.cast(caster, :self, 1, t1)
      assert ItemContainer.held_amount(made.inventory, @white_potion) == 0
      assert ItemContainer.held_amount(made.inventory, 509) == 1
      assert made.pending_production_result == %{success: true, item_id: @white_potion}
      assert made.pending_item_add_failures == [:inventory_full]
    end
  end

  describe "Twilight Alchemy 2" do
    test "brews 200 White Slim Potions, failing after showing itself when it cannot", %{
      caster: caster,
      t2: t2
    } do
      unit_rolls(List.duplicate(1, 200))

      assert {:ok, made} = AmTwilight2.cast(holding(caster, @white_slim_materials), :self, 1, t2)
      assert ItemContainer.held_amount(made.inventory, @white_slim) == 200

      short = holding(caster, [{7133, 1}, {504, 200}, {1092, 200}])

      assert {:failed, ^short, :skill_failed, :after_effect} =
               AmTwilight2.cast(short, :self, 1, t2)
    end

    test "needs an online Super Novice of any kind in the caster's party", %{
      caster: caster,
      t2: t2
    } do
      caster = %{caster | party_id: 77}
      party = fn members -> {:ok, %PartyState{party(members) | party_id: 77}} end

      for {job_id, online, expected} <- [
            {23, true, :ok},
            {4307, true, :ok},
            {4190, true, :ok},
            {23, false, :error},
            {4019, true, :error}
          ] do
        stub(PartyManager, :get, fn 77 -> party.([member(2, job_id, online)]) end)
        assert elem(AmTwilight2.begin_attempt(caster, :self, 1, t2), 0) == expected
      end

      assert {:error, :skill_failed} =
               AmTwilight2.begin_attempt(%{caster | party_id: 0}, :self, 1, t2)
    end
  end

  test "Twilight Alchemy is never learned with points, only granted" do
    progression = %PlayerProgression{
      job_id: 4019,
      base_level: 99,
      job_level: 50,
      skill_point: 10,
      learned_skills: %{228 => 10}
    }

    for skill_id <- [496, 497],
        do: assert({:error, _} = SkillTree.can_learn(progression, skill_id))

    granted = %{progression | learned_skills: %{228 => 10, 496 => 1}}
    listed = SkillTree.available_for(granted) |> Enum.map(& &1.skill_id)
    assert 496 in listed
    refute 497 in listed
  end

  defp unit_rolls(rolls) do
    {:ok, agent} = Agent.start_link(fn -> rolls end)

    Application.put_env(:zone_server, :forge_rng, fn
      10_000 -> Agent.get_and_update(agent, fn [roll | rest] -> {roll, rest} end)
      _upper -> 1
    end)
  end

  defp holding(caster, items) do
    inventory =
      items
      |> Enum.with_index()
      |> Map.new(fn {{id, amount}, slot} ->
        {slot, %InventoryItem{nameid: id, amount: amount, identify: 1}}
      end)

    %{caster | inventory: inventory, pending_inventory_persist: []}
  end

  defp card(id), do: %InventoryItem{nameid: id, amount: 1, identify: 1}

  defp party(members),
    do: %PartyState{
      party_id: 0,
      name: "Twilight",
      leader_char_id: 1,
      exp_share: false,
      item_pickup_share: false,
      members: Map.new(members, &{&1.char_id, &1})
    }

  defp member(char_id, job_id, online),
    do: %Member{
      char_id: char_id,
      name: "M#{char_id}",
      job_id: job_id,
      online: online,
      base_level: 99
    }
end
