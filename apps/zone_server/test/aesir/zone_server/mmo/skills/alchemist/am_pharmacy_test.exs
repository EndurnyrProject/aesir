defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPharmacyTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.Recipes
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Alchemist.AmPharmacy
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    Mimic.copy(Recipes)
    :ok
  end

  test "stages the recipes offerable at the cast level" do
    assert {:ok, definition} = Catalog.by_id(228)

    stub(Recipes, :offerable, fn 228, 3 -> [%{product_id: 501}] end)

    caster = player()

    assert {:ok, %{pending_menu_offer: offer}} = AmPharmacy.cast(caster, :self, 3, definition)
    assert offer == %{skill_id: 228, kind: :ITEMS, entry_ids: [501], level: 3}
  end

  # The reference sends the recipe list after the requirement is paid, empty or
  # not, so an empty list keeps the cost and reports the failure.
  test "no offerable recipe is a failure after the payment" do
    assert {:ok, definition} = Catalog.by_id(228)

    stub(Recipes, :offerable, fn 228, _level -> [] end)

    caster = player()

    assert {:failed, ^caster, :no_materials} = AmPharmacy.cast(caster, :self, 1, definition)
  end

  defp player do
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
  end
end
