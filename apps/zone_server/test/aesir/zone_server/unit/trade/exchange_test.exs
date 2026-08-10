defmodule Aesir.ZoneServer.Unit.Trade.ExchangeTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Trade.Exchange
  alias Aesir.ZoneServer.Unit.Trade.Offer
  alias Aesir.ZoneServer.Unit.Zeny

  @potion 501
  @sword 1101

  setup :setup_ets_tables

  setup do
    a = insert_character("TradeA", 1_000)
    b = insert_character("TradeB", 2_000)
    %{a: a, b: b}
  end

  test "atomically swaps items with their instance attributes and zeny", %{a: a, b: b} do
    a_item =
      seed_item(a.id, @sword, 1, %{
        identify: 1,
        refine: 7,
        card0: 4001,
        card1: 4002,
        craft: %{"creator_id" => a.id, "stars" => 2},
        random_options: %{"1" => %{"val" => 5, "parm" => 1}},
        unique_id: 12_345,
        enchant_grade: 2
      })

    b_item = seed_item(b.id, @potion, 5, %{identify: 1})

    assert {:ok, deltas} =
             Exchange.run(
               side(a, offer(a_item, 1, 100)),
               side(b, offer(b_item, 3, 250))
             )

    assert [%InventoryItem{nameid: @potion, amount: 3}] = Persistence.load_inventory(a.id)

    assert [
             %InventoryItem{nameid: @potion, amount: 2},
             %InventoryItem{
               nameid: @sword,
               amount: 1,
               refine: 7,
               card0: 4001,
               card1: 4002,
               craft: %{"creator_id" => creator_id, "stars" => 2},
               random_options: %{"1" => %{"val" => 5, "parm" => 1}},
               unique_id: 12_345,
               enchant_grade: 2
             }
           ] = Persistence.load_inventory(b.id)

    assert creator_id == a.id
    assert Repo.get!(Character, a.id).zeny == 1_150
    assert Repo.get!(Character, b.id).zeny == 1_850
    assert deltas.a.zeny == 1_150
    assert deltas.b.zeny == 1_850

    assert Enum.sort(Enum.map(Map.values(deltas.a.inventory), &{&1.nameid, &1.amount})) == [
             {@potion, 3}
           ]

    assert Enum.sort(Enum.map(Map.values(deltas.b.inventory), &{&1.nameid, &1.amount})) == [
             {@potion, 2},
             {@sword, 1}
           ]

    assert length(deltas.a.item_changes) == 2
    assert length(deltas.b.item_changes) == 2
  end

  for scenario <- [
        :missing_row,
        :wrong_owner,
        :short_amount,
        :bound,
        :rented,
        :no_trade,
        :equipped,
        :weight_overflow,
        :slot_overflow,
        :zeny_overflow,
        :giver_zeny_short
      ] do
    test "rolls back both sides for #{scenario}", %{a: a, b: b} do
      {side_a, side_b, expected_reason} = failure_case(unquote(scenario), a, b)
      before = database_state(a.id, b.id)

      assert {:error, ^expected_reason} = Exchange.run(side_a, side_b)
      assert database_state(a.id, b.id) == before
    end
  end

  test "receiver's outgoing weight offsets incoming weight", %{a: a, b: b} do
    a_item = seed_item(a.id, @potion, 1, %{})
    b_item = seed_item(b.id, @potion, 1_000, %{})

    side_a = with_str(side(a, offer(a_item, 1, 0)), 400)
    side_b = with_str(side(b, offer(b_item, 1_000, 0)), 1)

    assert {:ok, _} = Exchange.run(side_a, side_b)
  end

  test "empty offers succeed without changing either side", %{a: a, b: b} do
    side_a = side(a, Offer.new())
    side_b = side(b, Offer.new())
    before = database_state(a.id, b.id)

    assert {:ok, %{a: delta_a, b: delta_b}} = Exchange.run(side_a, side_b)
    assert delta_a.inventory == %{}
    assert delta_b.inventory == %{}
    assert delta_a.item_changes == []
    assert delta_b.item_changes == []
    assert delta_a.zeny == 1_000
    assert delta_b.zeny == 2_000
    assert database_state(a.id, b.id) == before
  end

  defp failure_case(:missing_row, a, b) do
    item = seed_item(a.id, @potion, 5, %{})
    side_a = side(a, offer(item, 1, 0))
    {:ok, _} = Persistence.delete_item(item)
    {side_a, side(b, Offer.new()), :item_not_found}
  end

  defp failure_case(:wrong_owner, a, b) do
    item = seed_item(b.id, @potion, 5, %{})
    {side(a, offer(item, 1, 0)), side(b, Offer.new()), :item_not_owned}
  end

  defp failure_case(:short_amount, a, b) do
    item = seed_item(a.id, @potion, 5, %{})
    side_a = side(a, offer(item, 5, 0))
    {:ok, _} = Persistence.update_item(item, %{amount: 4})
    {side_a, side(b, Offer.new()), :insufficient_amount}
  end

  defp failure_case(:bound, a, b) do
    failure_with_item(a, b, @potion, %{bound: 1}, :bound)
  end

  defp failure_case(:rented, a, b) do
    expire_time = NaiveDateTime.add(NaiveDateTime.utc_now(), 3_600, :second)
    failure_with_item(a, b, @sword, %{expire_time: expire_time}, :rented)
  end

  defp failure_case(:no_trade, a, b) do
    failure_with_item(a, b, 766, %{}, :no_trade)
  end

  defp failure_case(:equipped, a, b) do
    failure_with_item(a, b, @sword, %{equip: 2}, :equipped)
  end

  defp failure_case(:weight_overflow, a, b) do
    item = seed_item(a.id, @potion, 1_000, %{})

    {side(a, offer(item, 1_000, 0)), with_str(side(b, Offer.new()), 1), :overweight}
  end

  defp failure_case(:slot_overflow, a, b) do
    item = seed_item(a.id, @sword, 1, %{})

    for _ <- 1..100 do
      seed_item(b.id, @potion, 1, %{})
    end

    {side(a, offer(item, 1, 0)), side(b, Offer.new()), :inventory_full}
  end

  defp failure_case(:zeny_overflow, a, b) do
    item = seed_item(a.id, @potion, 1, %{})

    {:ok, _} =
      Aesir.ZoneServer.CharacterPersistence.update_character(b.id, %{zeny: Zeny.max_zeny()})

    {side(a, offer(item, 1, 1)), side(b, Offer.new()), :zeny_overflow}
  end

  defp failure_case(:giver_zeny_short, a, b) do
    item = seed_item(a.id, @potion, 1, %{})
    side_a = side(a, offer(item, 1, 100))
    {:ok, _} = Aesir.ZoneServer.CharacterPersistence.update_character(a.id, %{zeny: 99})

    {side_a, side(b, Offer.new()), :not_enough_zeny}
  end

  defp failure_with_item(a, b, nameid, attrs, expected_reason) do
    item = seed_item(a.id, nameid, 1, attrs)
    {side(a, offer(item, 1, 0)), side(b, Offer.new()), expected_reason}
  end

  defp database_state(a_id, b_id) do
    %{
      a_inventory: inventory_rows(a_id),
      b_inventory: inventory_rows(b_id),
      a_zeny: Repo.get!(Character, a_id).zeny,
      b_zeny: Repo.get!(Character, b_id).zeny
    }
  end

  defp inventory_rows(char_id) do
    Enum.map(Persistence.load_inventory(char_id), fn item ->
      Map.take(item, [
        :id,
        :char_id,
        :nameid,
        :amount,
        :equip,
        :identify,
        :refine,
        :attribute,
        :card0,
        :card1,
        :card2,
        :card3,
        :random_options,
        :craft,
        :expire_time,
        :favorite,
        :bound,
        :unique_id,
        :equip_switch,
        :enchant_grade
      ])
    end)
  end

  defp side(character, offer) do
    %{
      char_id: character.id,
      offer: offer,
      inventory: load_inventory(character.id),
      stats: Stats.from_character(character)
    }
  end

  defp offer(item, amount, zeny) do
    {:ok, offer} = Offer.add(Offer.new(), item, amount)
    {:ok, offer} = Offer.set_zeny(offer, zeny)
    offer
  end

  defp seed_item(char_id, nameid, amount, attrs) do
    {:ok, item} =
      Persistence.insert_item(
        char_id,
        Map.merge(%{nameid: nameid, amount: amount, identify: 1}, attrs)
      )

    item
  end

  defp with_str(side, str), do: put_in(side.stats.base_stats.str, str)

  defp load_inventory(char_id) do
    char_id
    |> Persistence.load_inventory()
    |> PlayerState.from_list()
  end

  defp insert_character(name, zeny) do
    suffix = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "trade#{suffix}",
        userid: "trade#{suffix}",
        user_pass: "password",
        email: "#{suffix}@test.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "#{name}#{suffix}",
        class: 1,
        base_level: 99,
        zeny: zeny,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10
      })
      |> Repo.insert()

    character
  end
end
