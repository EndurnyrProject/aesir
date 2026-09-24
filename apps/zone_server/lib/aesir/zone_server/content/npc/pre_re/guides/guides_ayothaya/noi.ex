defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesAyothaya.Noi do
  @moduledoc """
  Ayothaya guide who welcomes visitors and points out attractions.

  ## Behavior

  - Describes local destinations and marks them on the mini-map.
  - Removes all location marks on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "ayothaya",
        x: 203,
        y: 169,
        dir: 3,
        sprite: 839,
        name: "Noi",
        scope: :pre_renewal,
        unique_name: "Noi#ayo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Noi]")
      |> mes("Welcome to Ayothaya.")
      |> mes("Our beautiful village is built")
      |> mes("above the water, surrounded")
      |> mes("by a dense forest.")
      |> next()
      |> mes("[Noi]")
      |> mes(
        "There are many tourist attractions in this village that you won't be able to find anywhere else. Our fish markets and the unique architecture of our buildings are enough reason to visit Ayotaya."
      )
      |> next()
      |> mes("[Noi]")
      |> mes("Please feel free")
      |> mes("to take a look around.")
      |> next()
      |> select(["Building Locations.", "Remove marks from mini-map.", "Cancel."])

    case choice do
      1 ->
        {ctx, location} =
          ctx
          |> mes("[Noi]")
          |> mes("Where would")
          |> mes("you like to visit?")
          |> next()
          |> select(["Weapon Shop", "Tool Shop", "Tavern", "Shrine", "Fishing Spot", "Cancel"])

        case location do
          1 ->
            ctx
            |> mes("[Noi]")
            |> mes("At our Weapon Shop,")
            |> mes("you will find great weapons")
            |> mes("favored by brave Ayothayan seafarers.")
            |> next()
            |> mes("[Noi]")
            |> mes("Our Weapon Shop")
            |> mes("is located at ^55FF33+^000000.")
            |> viewpoint(1, 165, 90, 2, 0x55FF33)
            |> close()

          2 ->
            ctx
            |> mes("[Noi]")
            |> mes(
              "We Ayothayans always make sure we have everything we need before we go traveling. It never hurts to be prepared, doesn't it?"
            )
            |> next()
            |> mes("[Noi]")
            |> mes("Our Tool Shop")
            |> mes("is located at ^3355FF+^000000.")
            |> viewpoint(1, 129, 86, 3, 0x3355FF)
            |> close()

          3 ->
            ctx
            |> mes("[Noi]")
            |> mes(
              "One of the basics of adventuring is gathering information, or at least that's what they say. You can meet people from all sorts of places in the Tavern. I'm sure you can learn something useful there."
            )
            |> next()
            |> mes("[Noi]")
            |> mes("Of course, you must")
            |> mes("drop by our Tavern.")
            |> mes("It is located at ^00FF00+^000000.")
            |> viewpoint(1, 232, 76, 4, 0x00FF00)
            |> close()

          4 ->
            ctx
            |> mes("[Noi]")
            |> mes(
              "If you wish to pray to God, or achieve a state of peace in your mind, why don't you visit our Shrine? Even if it's just for sight-seeing, everyone is"
            )
            |> mes("welcome there.")
            |> next()
            |> mes("[Noi]")
            |> mes("Our Shrine")
            |> mes("is located at ^00FF00+^000000.")
            |> viewpoint(1, 208, 283, 5, 0x00FF00)
            |> close()

          5 ->
            ctx
            |> mes("[Noi]")
            |> mes(
              "Since Ayothaya was built above the surface of the water and close to a beach, it's been a favorite spot for fishermen. Why don't you catch some fish for dinner at the Fishing Spot?"
            )
            |> next()
            |> mes("[Noi]")
            |> mes("Our famous")
            |> mes("Fishing Spot")
            |> mes("is located at ^00FF00+^000000")
            |> viewpoint(1, 253, 99, 6, 0x00FF00)
            |> close()

          6 ->
            ctx
            |> mes("[Noi]")
            |> mes(
              "If you wish to remove location marks on your mini-map, please select the 'Remove marks from mini-map' command from the menu."
            )
            |> close()

          _ ->
            clear_marks(ctx)
        end

      2 ->
        clear_marks(ctx)

      3 ->
        ctx |> mes("[Noi]") |> mes("Please enjoy") |> mes("your travels.") |> close()

      _ ->
        ctx
    end
  end

  defp clear_marks(ctx) do
    ctx
    |> viewpoint(2, 165, 90, 2, 0x55FF33)
    |> viewpoint(2, 129, 86, 3, 0x3355FF)
    |> viewpoint(2, 232, 76, 4, 0x00FF00)
    |> viewpoint(2, 208, 283, 5, 0x00FF00)
    |> viewpoint(2, 253, 99, 6, 0x00FF00)
    |> mes("[Noi]")
    |> mes("Alright...")
    |> mes("I've removed all the")
    |> mes("location marks from")
    |> mes("your mini-map.")
    |> mes("Thank you.")
    |> close()
  end
end
