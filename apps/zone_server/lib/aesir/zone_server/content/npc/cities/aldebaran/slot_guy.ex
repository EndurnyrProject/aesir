defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.SlotGuy do
  @moduledoc """
  Explains equipment slots and how monster cards use them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 90,
        y: 170,
        dir: 4,
        sprite: 47,
        name: "Slot Guy",
        scope: :shared,
        unique_name: "Slot Guy#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Epthiel]")
      |> mes(
        "Some weapons or armor have Slots where you can insert Cards obtained from monsters."
      )
      |> next()
      |> select([
        "About the number of Slots",
        "Relation between Cards and Slots",
        "End Conversation"
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Epthiel]")
        |> mes(
          "Items dropped by monsters possess more Slots than ordinary weapons or armor sold in NPC shops."
        )
        |> next()
        |> mes("[Epthiel]")
        |> mes(
          "I guess you can assume that an item with more Slots is more valuable than the same item with fewer Slots."
        )
        |> close()

      2 ->
        ctx
        |> mes("[Epthiel]")
        |> mes(
          "Once a Card is inserted into a Slot, it is impossible to remove it. So please be careful when you insert Cards into weapons or armor."
        )
        |> next()
        |> mes("[Epthiel]")
        |> mes(
          "Also, when you mouse over equipment in the Item Window or Vending Window, the name of the item will be followed by the number of its Slots in brackets."
        )
        |> next()
        |> mes("[Epthiel]")
        |> mes(
          "For example, a Shield with 1 Slot, when moused over, would display the name 'Shield [1].'"
        )
        |> next()
        |> mes("[Epthiel]")
        |> mes(
          "You may also right-click an item, and check the Card Slot window below the item description window for the number of Slots."
        )
        |> close()

      3 ->
        ctx
        |> mes("[Epithiel]")
        |> mes("Have you ever obtained a card from a monster?")
        |> close()

      _ ->
        ctx
    end
  end
end
