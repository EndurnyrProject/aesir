defmodule Aesir.ZoneServer.Mmo.Skills.Shared.ItemEnchantarmsTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Shared.ItemEnchantarms
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.WatkElement
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :verify_on_exit!

  # The level selects the element, not the strength: element id = level - 1.
  @elements [
    {1, :neutral},
    {2, :water},
    {3, :earth},
    {4, :fire},
    {5, :wind},
    {6, :poison},
    {7, :holy},
    {8, :shadow},
    {9, :ghost},
    {10, :undead}
  ]

  defp definition do
    {:ok, definition} = Catalog.by_id(492)
    definition
  end

  test "Catalog.active_module_for/1 resolves item_enchantarms" do
    assert {:ok, ItemEnchantarms} = Catalog.active_module_for(:item_enchantarms)
  end

  for {level, element} <- @elements do
    test "level #{level} endows the #{element} element" do
      caster = %{character_id: 42}

      expect(StatusInterpreter, :apply_status, fn :player, 42, :sc_watk_element, params ->
        send(self(), {:val1, params[:val1]})
        :ok
      end)

      assert {:ok, ^caster} = ItemEnchantarms.cast(caster, :self, unquote(level), definition())

      assert_received {:val1, val1}
      assert val1 == unquote(level) - 1

      assert %{attack_element: unquote(element)} =
               WatkElement.modifiers(%StatusEntry{val1: val1}, %{})
    end
  end

  test "the endow lasts 20 minutes at every level" do
    caster = %{character_id: 42}

    expect(StatusInterpreter, :apply_status, 10, fn :player, 42, :sc_watk_element, params ->
      send(self(), {:duration, params[:duration]})
      :ok
    end)

    for level <- 1..10 do
      assert {:ok, ^caster} = ItemEnchantarms.cast(caster, :self, level, definition())
      assert_received {:duration, 1_200_000}
    end
  end

  test "a failed status application fails the cast" do
    stub(StatusInterpreter, :apply_status, fn _, _, _, _ -> {:error, :immune} end)

    assert {:error, :immune} = ItemEnchantarms.cast(%{character_id: 42}, :self, 4, definition())
  end
end
