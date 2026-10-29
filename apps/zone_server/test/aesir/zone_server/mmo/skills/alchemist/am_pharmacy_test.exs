defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPharmacyTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPharmacy
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Red Potion (501): Medicine Bowl guide 7144 held, Red Herb 507 and an Empty
  # Potion Bottle 1093 consumed.
  @red_potion_materials [{7144, 1}, {507, 1}, {1093, 1}]

  test "stages the Pharmacy recipes the caster can make now" do
    assert {:ok, definition} = Catalog.by_id(228)

    caster = player(@red_potion_materials)

    assert {:ok, %{pending_menu_offer: offer}} = AmPharmacy.cast(caster, :self, 3, definition)
    assert offer == %{skill_id: 228, kind: :ITEMS, entry_ids: [501], level: 3}
  end

  # The reference sends the recipe list after the requirement is paid, empty or
  # not, so an empty list keeps the cost and reports the failure.
  test "nothing makeable is a failure after the payment" do
    assert {:ok, definition} = Catalog.by_id(228)

    caster = player([])

    assert {:failed, ^caster, :no_materials} = AmPharmacy.cast(caster, :self, 1, definition)
  end

  test "another skill's open menu hides the Pharmacy recipes" do
    assert {:ok, definition} = Catalog.by_id(228)

    caster = %{player(@red_potion_materials) | open_menu_skill_id: 34}

    assert {:failed, _caster, :no_materials} = AmPharmacy.cast(caster, :self, 1, definition)
  end

  test "a reply for a recipe no longer makeable does nothing" do
    caster = player([{7144, 1}, {1093, 1}])

    assert {:silent, ^caster} = AmPharmacy.on_menu_reply(caster, %{id: 501, extras: []}, 1)
  end

  test "a reply for a makeable recipe brews it" do
    # A failed roll still brews (the materials are spent) without adding a product.
    previous = Application.get_env(:zone_server, :forge_rng)
    Application.put_env(:zone_server, :forge_rng, fn upper -> upper end)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:zone_server, :forge_rng, previous),
        else: Application.delete_env(:zone_server, :forge_rng)
    end)

    caster = player(@red_potion_materials)

    assert {:ok, brewed} = AmPharmacy.on_menu_reply(caster, %{id: 501, extras: []}, 1)
    assert brewed.pending_production_result == %{success: false, item_id: 501}
  end

  test "a reply while trading fails the skill" do
    caster = player(@red_potion_materials)

    assert {:error, :skill_failed} =
             AmPharmacy.on_menu_reply(caster, %{id: 501, extras: []}, 1, %{
               homunculus: nil,
               trading?: true
             })
  end

  defp player(items) do
    base =
      PlayerState.new(%Character{
        id: 1,
        account_id: 1,
        name: "Alchemist",
        class: 18,
        sex: "M",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 90,
        hp: 1_000,
        sp: 1_000
      })

    base = put_in(base.stats.progression.learned_skills, %{228 => 3})

    inventory =
      items
      |> Enum.with_index()
      |> Map.new(fn {{id, amount}, index} ->
        {index, %InventoryItem{nameid: id, amount: amount, identify: 1}}
      end)

    %{base | inventory: inventory}
  end
end
