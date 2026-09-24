defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesLouyang.Soldier do
  @moduledoc """
  Luoyang soldier who directs visitors to city landmarks.

  ## Behavior

  - Describes and marks a chosen building on the mini-map.
  - Removes all building marks on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena/Tsuyuki
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "louyang",
        x: 213,
        y: 213,
        dir: 3,
        sprite: 825,
        name: "Soldier",
        scope: :pre_renewal,
        unique_name: "LouGuide"
      },
      %{
        map: "louyang",
        x: 160,
        y: 175,
        dir: 3,
        sprite: 825,
        name: "Soldier",
        scope: :pre_renewal,
        unique_name: "Soldier#BB"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Soldier]")
      |> mes("Welcome to Luoyang,")
      |> mes("a city with a long")
      |> mes("and colorful history.")
      |> next()
      |> mes("[Soldier]")
      |> mes("Recently we've developed")
      |> mes("an ocean lane to accomodate")
      |> mes("positive exchange with")
      |> mes("foreign nations.")
      |> next()
      |> mes("[Soldier]")
      |> mes(
        "Luoyang is well-known for various specialties in addition to its rich history. Here you can find many things unique to our land."
      )
      |> next()
      |> mes("[Soldier]")
      |> mes("Please take your time")
      |> mes("and we invite you to enjoy")
      |> mes("your trip here in Luoyang.")
      |> next()
      |> select(["Ask Building Locations.", "Remove all marks from mini-map.", "Cancel."])

    ctx =
      case choice do
        1 ->
          {ctx, location} =
            ctx
            |> mes("[Soldier]")
            |> mes("Where would you like to go?")
            |> next()
            |> select([
              "Dragon Castle",
              "Doctor's Office",
              "City Hall",
              "Weapon Shop",
              "Tool Shop",
              "Tavern",
              "Cancel"
            ])

          case location do
            1 ->
              ctx
              |> mes("[Soldier]")
              |> mes(
                "The Dragon Castle is located at ^FF3355+^000000. It is where all the nobles reside, including our lord."
              )
              |> next()
              |> mes("[Soldier]")
              |> mes(
                "Since you're an outsider, I guess it would be appropriate for you to visit our lord first."
              )
              |> viewpoint(1, 218, 255, 2, 0xFF3355)

            2 ->
              ctx
              |> mes("[Soldier]")
              |> mes("We have a very skillful doctor.")
              |> mes("You can find her office at ^CE6300+^000000.")
              |> next()
              |> mes("[Soldier]")
              |> mes("It is said that there")
              |> mes(
                "is no disease she cannot cure. Well, I can't guarantee if that's true or not."
              )
              |> viewpoint(1, 263, 94, 3, 0xCE6300)

            3 ->
              ctx
              |> mes("[Soldier]")
              |> mes("We have a City Hall where the federal government operates.")
              |> mes("It is located at ^A5BAAD+^000000.")
              |> next()
              |> mes("[Soldier]")
              |> mes("If you have any problems,")
              |> mes("you should talk with the")
              |> mes("employees in City Hall.")
              |> viewpoint(1, 309, 80, 4, 0xA5BAAD)

            4 ->
              ctx
              |> mes("[Soldier]")
              |> mes("The Weapon Shop is located at ^55FF33+^000000.")
              |> next()
              |> mes("[Soldier]")
              |> mes("You will see")
              |> mes("marvelous weapons forged")
              |> mes("by the well-experienced")
              |> mes("blacksmiths of Luoyang.")
              |> viewpoint(1, 145, 174, 5, 0x55FF33)

            5 ->
              ctx
              |> mes("[Soldier]")
              |> mes("The Tool Shop is located at ^3355FF+^000000.")
              |> next()
              |> mes("[Soldier]")
              |> mes("Knowing your enemy")
              |> mes("is half the battle!")
              |> mes(
                "It's also safer to prepare yourself than to be sorry later. Why don't you go check their supplies?"
              )
              |> viewpoint(1, 135, 98, 6, 0x3355FF)

            6 ->
              ctx
              |> mes("[Soldier]")
              |> mes(
                "When you get tired during your trip, I suggest that you visit the Tavern. It's located at ^00FF00+^000000."
              )
              |> next()
              |> mes("[Soldier]")
              |> mes("The Tavern is a good place")
              |> mes(
                "to meet other tourists, as well as to hear of any news that may be helpful to know."
              )
              |> viewpoint(1, 280, 167, 7, 0x00FF00)

            7 ->
              ctx
              |> mes("[Soldier]")
              |> mes("If you wish to remove all marks")
              |> mes(
                "on your mini-map, please choose 'Remove all marks from mini-map.' from the menu."
              )

            _ ->
              ctx
          end

        2 ->
          ctx
          |> viewpoint(2, 218, 255, 2, 0xFF00FF)
          |> viewpoint(2, 263, 94, 3, 0xFF00FF)
          |> viewpoint(2, 309, 80, 4, 0xFF00FF)
          |> viewpoint(2, 145, 174, 5, 0xFF00FF)
          |> viewpoint(2, 135, 98, 6, 0xFF00FF)
          |> viewpoint(2, 280, 167, 7, 0xFF00FF)
          |> mes("[Soldier]")
          |> mes(
            "There, I've erased all the marks on your mini-map. Feel free to ask me about building locations whenever you need to."
          )

        3 ->
          ctx
          |> mes("[Soldier]")
          |> mes("I guess it's fun")
          |> mes("sometimes to go exploring")
          |> mes("on your own. Take care.")

        _ ->
          ctx
      end

    close(ctx)
  end
end
