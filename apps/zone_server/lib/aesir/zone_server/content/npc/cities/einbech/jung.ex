defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Jung do
  @moduledoc """
  Teaches travelers about monsters found in the Einbech mine dungeon.

  ## Behavior

  - Offers information about Noxious and Venomous, Pollcellio, or Obsidian.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 148,
        y: 242,
        dir: 5,
        sprite: 855,
        name: "Jung",
        scope: :shared,
        unique_name: "Jung#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jung]")
      |> mes("I'm one of the few")
      |> mes("people who's lived")
      |> mes("in both Einbech and")
      |> mes("Einbroch for a long time.")
      |> mes("So I guess I'm one of the")
      |> mes("best guides of this area.")
      |> next()
      |> mes("[Jung]")
      |> mes("Say, if you're thinking of")
      |> mes("entering the Mine Dungeon,")
      |> mes("I can tell you all I know about")
      |> mes("the monsters in that place so")
      |> mes("that you'll be better prepared.")
      |> next()
      |> select(["Sure, why not?", "No, thanks."])

    case choice do
      1 ->
        {ctx, topic} =
          ctx
          |> mes("[Jung]")
          |> mes("Let's see. Ah, the monsters that are unique to the Mine Dungeon")
          |> mes("are Noxious, Venomous, Pollcellio and Obsidian. Which one do you")
          |> mes("want to know more about?")
          |> next()
          |> select(["Noxious and Venomous", "Pollcellio", "Obsidian"])

        case topic do
          1 ->
            ctx
            |> mes("[Jung]")
            |> mes("You know, no one seems")
            |> mes("to know where Noxious and")
            |> mes("Venomous have come from.")
            |> mes("It's like they appeared out of")
            |> mes("nowhere when Einbroch")
            |> mes("started to industrialize.")
            |> next()
            |> mes("[Jung]")
            |> mes("Now that I think about it,")
            |> mes("I don't think they're naturally created monsters. They have")
            |> mes("this fixed look of despair and")
            |> mes("suffering and tend to act like they want their enemies to kill them.")
            |> next()
            |> mes("[Jung]")
            |> mes("Still, you'd better be careful!")
            |> mes("careful! Noxious and Venomous")
            |> mes("are stealthy monsters that can")
            |> mes("glide quietly through the air")
            |> mes("and attack you before")
            |> mes("you even notice...")
            |> next()
            |> mes("[Jung]")
            |> mes("You should know that")
            |> mes("Noxious is Ghost property")
            |> mes("and Venomous is Poison.")
            |> mes("Both are medium sized,")
            |> mes("formless monsters.")
            |> next()
            |> mes("[Jung]")
            |> mes("Both of them drop Apple,")
            |> mes("Dust Pollutant, Toxic Gas,")
            |> mes("Poisonous Powder, Bacillus,")
            |> mes("Mold Powder and Anodyne.")
            |> next()
            |> mes("[Jung]")
            |> mes("That's all for now.")
            |> mes("Feel free to ask me")
            |> mes("if you have any questions")
            |> mes("about monsters in the Mine")
            |> mes("Dungeon. Be safe, adventurer.")
            |> close()

          2 ->
            ctx
            |> mes("[Jung]")
            |> mes("Pollcellio is an insect that")
            |> mes("lives in caves and drinks water")
            |> mes("dripped from stalactites. It's")
            |> mes("different from Ungoliant since")
            |> mes("it likes to be near different")
            |> mes("kinds of minerals and ores.")
            |> next()
            |> mes("[Jung]")
            |> mes("Pollcellio drops Jubilee,")
            |> mes("Insect Antenna, Single Cell,")
            |> mes("Moss of Morning Dew, Neon")
            |> mes("Liquid and a few other things")
            |> mes("I can't quite remember.")
            |> next()
            |> mes("[Jung]")
            |> mes("Lastly, Pollcellio is an")
            |> mes("Earth property monster.")
            |> mes("That's all I know about it.")
            |> mes("But if you want to know more")
            |> mes("about some other monster in the")
            |> mes("Mine Dungeon, feel free to ask.")
            |> close()

          3 ->
            ctx
            |> mes("[Jung]")
            |> mes("Do you know about the")
            |> mes("belief that underground")
            |> mes("minerals that contain huge")
            |> mes("amounts of energy actually")
            |> mes("have souls? Obsidian is")
            |> mes("one of these living rocks.")
            |> next()
            |> mes("[Jung]")
            |> mes(
              "Supposedly, just a piece of an Obsidian in a Jung Processor has enough energy to light up the night sky. Unfortunately, it's impossible to capture one alive and hunting them isn't so easy."
            )
            |> next()
            |> mes("[Jung]")
            |> mes("Obsidian is a small,")
            |> mes("shapeless monster that")
            |> mes("drops Clear Jewel, Piece of")
            |> mes("Black Crystal, Coal, Elunium,")
            |> mes("Iron and Steel.")
            |> next()
            |> mes("[Jung]")
            |> mes("That's all for Obsidian.")
            |> mes("If you have any questions")
            |> mes("about other monsters living")
            |> mes("in the Mine Dungeon, feel")
            |> mes("free to ask me.")
            |> close()

          _ ->
            decline_conversation(ctx)
        end

      2 ->
        decline_conversation(ctx)

      _ ->
        ctx
    end
  end

  defp decline_conversation(ctx) do
    ctx
    |> mes("[Jung]")
    |> mes("I understand if you're")
    |> mes("kind of in a hurry. Still,")
    |> mes("if you're pretty new around")
    |> mes("here, you should learn as")
    |> mes("much as you can before")
    |> mes("entering any dungeons.")
    |> next()
    |> mes("[Jung]")
    |> mes("Alright then,")
    |> mes("be safe on your")
    |> mes("adventures, alright?")
    |> close()
  end
end
