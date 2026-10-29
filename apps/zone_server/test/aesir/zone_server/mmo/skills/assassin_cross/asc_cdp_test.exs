defmodule Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscCdpTest do
  use Aesir.DataCase, async: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AssassinCross.AscCdp
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @poison_bottle 678
  # Poison Bottle recipe: Immortal Heart, Bitter Herb, Poison Spore, Karvodailnirol,
  # Venom Canine, Poison Kit and Empty Bottle, one each.
  @materials [937, 952, 939, 7033, 972, 657, 713]

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
        username: "cdp#{suffix}",
        userid: "cdp#{suffix}",
        user_pass: "password",
        email: "cdp#{suffix}@test.com"
      })
      |> Repo.insert!()

    character =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Cdp#{suffix}",
        class: 4013,
        base_level: 99,
        job_level: 50,
        dex: 50,
        luk: 30
      })
      |> Repo.insert!()

    stats = Stats.from_character(character)
    stats = put_in(stats.progression.learned_skills, %{407 => 1})
    stats = %{stats | modifiers: %{stats.modifiers | job_bonuses: %{}}}
    {:ok, definition} = Catalog.by_id(407)

    %{
      caster: %PlayerState{character_id: character.id, stats: stats},
      definition: definition
    }
  end

  test "without the materials nothing is consumed and the stuff is insufficient", %{
    caster: caster,
    definition: definition
  } do
    caster = %{caster | inventory: inventory(List.delete(@materials, 713))}

    assert {:failed, ^caster, :stuff_insufficient} = AscCdp.cast(caster, :self, 1, definition)
  end

  test "another skill's open menu makes the recipe unavailable", %{
    caster: caster,
    definition: definition
  } do
    caster = %{caster | inventory: inventory(@materials), open_menu_skill_id: 279}

    assert {:failed, ^caster, :stuff_insufficient} = AscCdp.cast(caster, :self, 1, definition)
  end

  test "a successful roll makes one unsigned Poison Bottle", %{
    caster: caster,
    definition: definition
  } do
    # 2000 + 40 * 50 + 20 * 30 = 4600
    pin_roll(4600)
    caster = %{caster | inventory: inventory(@materials)}

    assert {:ok, made} = AscCdp.cast(caster, :self, 1, definition)
    assert Enum.all?(@materials, &(ItemContainer.held_amount(made.inventory, &1) == 0))
    assert made.pending_production_result == %{success: true, item_id: @poison_bottle}
    assert made.pending_hp_loss == nil

    bottle =
      Enum.find_value(made.inventory, fn {_i, item} -> item.nameid == @poison_bottle && item end)

    assert bottle.amount == 1
    assert ItemCraft.from_map(bottle.craft) == :error
  end

  test "a failed roll spends the materials and costs a quarter of max HP", %{
    caster: caster,
    definition: definition
  } do
    pin_roll(4601)
    caster = %{caster | inventory: inventory(@materials)}
    max_hp = caster.stats.derived_stats.max_hp

    assert {:failed, failed, :stuff_insufficient} = AscCdp.cast(caster, :self, 1, definition)
    assert Enum.all?(@materials, &(ItemContainer.held_amount(failed.inventory, &1) == 0))
    assert ItemContainer.held_amount(failed.inventory, @poison_bottle) == 0
    assert failed.pending_production_result == %{success: false, item_id: @poison_bottle}
    assert failed.pending_hp_loss == max(1, div(max_hp * 25, 100))
  end

  test "a success the caster cannot carry spends the materials and reports the add", %{
    caster: caster,
    definition: definition
  } do
    pin_roll(1)
    # 30,000 Jellopies far exceed any carrying capacity.
    caster = %{caster | inventory: inventory(@materials ++ [{909, 30_000}])}

    assert {:ok, made} = AscCdp.cast(caster, :self, 1, definition)
    assert Enum.all?(@materials, &(ItemContainer.held_amount(made.inventory, &1) == 0))
    assert ItemContainer.held_amount(made.inventory, @poison_bottle) == 0
    assert made.pending_item_add_failures == [:overweight]
    assert made.pending_production_result == %{success: true, item_id: @poison_bottle}
  end

  defp pin_roll(roll) do
    Application.put_env(:zone_server, :forge_rng, fn 10_000 -> roll end)
  end

  defp inventory(entries) do
    entries
    |> Enum.map(fn
      {id, amount} -> {id, amount}
      id -> {id, 1}
    end)
    |> Enum.with_index()
    |> Map.new(fn {{id, amount}, index} ->
      {index, %InventoryItem{nameid: id, amount: amount, identify: 1}}
    end)
  end
end
