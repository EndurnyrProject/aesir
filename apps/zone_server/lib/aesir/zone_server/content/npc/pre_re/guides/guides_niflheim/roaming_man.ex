defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesNiflheim.RoamingMan do
  @moduledoc """
  Niflheim wanderer who reluctantly guides visitors around town.

  ## Behavior

  - Describes and marks a chosen destination on the mini-map.
  - Removes location marks on request.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Lupus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "niflheim",
        x: 107,
        y: 156,
        dir: 6,
        sprite: 798,
        name: "Roaming Man",
        scope: :pre_renewal,
        unique_name: "Roaming Man#nif"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Ricael]")
      |> mes("You must be lost...")
      |> mes("Why would anyone come")
      |> mes("to this horrid, dreadful")
      |> mes("place on purpose...??")
      |> next()
      |> mes("[Ricael]")
      |> mes(
        "Ever since I stumbled fell down into this giant tree, I've suffered endlessly here. I've wasted years in sadness, being unable to escape Niflheim."
      )
      |> next()
      |> mes("[Ricael]")
      |> mes("But in searching for an")
      |> mes("escape route, I probably know")
      |> mes("this town better than anyone")
      |> mes("else. I guess knowing the")
      |> mes("layout might help you escape")
      |> mes("if it weren't so futile.")
      |> next()
      |> select(["Ask building locations.", "Remove marks on the mini-map.", "Cancel."])

    ctx =
      case choice do
        1 ->
          {ctx, location} =
            ctx
            |> mes("[Ricael]")
            |> mes("So, um, which place do you want to know about?")
            |> next()
            |> select(["Witch's castle", "Tool shop", "Weapon shop", "Pub", "Cancel"])

          case location do
            1 ->
              ctx
              |> mes("[Ricael]")
              |> mes("There. I made a ^FF3355+^000000 mark")
              |> mes("on your mini-map so that you can")
              |> mes("go to the castle where that")
              |> mes("creepy witch lives.")
              |> next()
              |> mes("[Ricael]")
              |> mes("I went there once, but then I")
              |> mes("ran away and decided that I")
              |> mes("should try to not die as much")
              |> mes("as possible. That's pretty")
              |> mes("much my life goal here in")
              |> mes("Niflheim.")
              |> viewpoint(1, 253, 191, 2, 0xFF3355)

            2 ->
              ctx
              |> mes("[Ricael]")
              |> mes("The Tool shop is located")
              |> mes("at the ^CE6300+^000000 mark I made")
              |> mes("on your mini-map.")
              |> next()
              |> mes("[Ricael]")
              |> mes("They sell some unique items that")
              |> mes("you cannot find outside of this")
              |> mes("town. Of course, they weren't so")
              |> mes("special once I realized no")
              |> mes("Potion can ease the pain I feel.")
              |> mes("...I wish I was in prison.")
              |> emotion(:kek)
              |> viewpoint(1, 217, 196, 3, 0xCE6300)

            3 ->
              ctx
              |> mes("[Ricael]")
              |> mes("The Weapon shop is located")
              |> mes("at the ^55FF33+^000000 mark I made")
              |> mes("on your mini-map.")
              |> next()
              |> mes("[Ricael]")
              |> mes("They sell some unique items which")
              |> mes("you cannot find outside of this")
              |> mes("town... Of course, fighting")
              |> mes("the monsters here will just")
              |> mes("make them angrier. You may as")
              |> mes("well let them eat you.")
              |> emotion(:kek)
              |> viewpoint(1, 216, 171, 4, 0x55FF33)

            4 ->
              ctx
              |> mes("[Ricael]")
              |> mes("The Pub is located at")
              |> mes("the ^3355FF+^000000 mark I've made")
              |> mes("on your mini-map.")
              |> next()
              |> mes("[Ricael]")
              |> mes("Sometimes I see dead people in the")
              |> mes("Pub enjoying themselves, having a")
              |> mes("good time. I used to be able to")
              |> mes("have fun once, but now all I feel")
              |> mes("is the cold tingle of loneliness")
              |> mes("and despair...every waking moment.")
              |> viewpoint(1, 189, 207, 5, 0x3355FF)

            5 ->
              ctx
              |> mes("[Ricael]")
              |> mes("If you want to remove the location")
              |> mes("marks from your mini-map, please")
              |> mes("choose 'Remove marks on the")
              |> mes("mini-map' from the menu.")

            _ ->
              ctx
          end

        2 ->
          ctx
          |> viewpoint(2, 253, 191, 2, 0xFF3355)
          |> viewpoint(2, 217, 196, 3, 0xCE6300)
          |> viewpoint(2, 216, 171, 4, 0x55FF33)
          |> viewpoint(2, 189, 207, 5, 0x3355FF)
          |> mes("[Ricael]")
          |> mes("I removed the location marks from")
          |> mes("your mini-map. Go ahead and ask")
          |> mes("me if you want to mark the")
          |> mes("building locations again. It")
          |> mes("helps me ignore the depression")
          |> mes("that gnaws at me constantly.")

        3 ->
          ctx
          |> mes("[Ricael]")
          |> mes("It's not a good idea to search")
          |> mes("Niflheim by yourself...")
          |> mes("At least try to be careful.")

        _ ->
          ctx
      end

    close(ctx)
  end
end
