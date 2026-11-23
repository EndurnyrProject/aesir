defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.ElleCherno do
  @moduledoc """
  Elle sings and helps advance the airship ticket quest.

  ## Behavior

  - Asks the player to check on her mother and later delivers a letter for her grandfather.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 261,
        y: 241,
        dir: 3,
        sprite: 703,
        name: "Elle Cherno",
        scope: :shared,
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: talk(ctx)

  @impl true
  def on_talk(ctx), do: talk(ctx)

  defp talk(ctx) do
    ctx =
      ctx
      |> mes("[Elle Cherno]")
      |> mes("Let's get to work")
      |> mes("fear-less comraaades~!")
      |> mes("Do our best! Nothing")
      |> mes("can stop us, lads~!")

    case get_char_var(ctx, :kain_ticket, 0) do
      6 ->
        ask_about_song(ctx)

      7 ->
        ctx
        |> next()
        |> mes("[Elle Cherno]")
        |> mes("Our house is right")
        |> mes("behind of the Hotel.")
        |> mes("Will you go there and")
        |> mes("see my mommy for me,")
        |> mes("please? I'm worried...")
        |> close()

      13 ->
        give_letter(next(ctx))

      _ ->
        close(ctx)
    end
  end

  defp ask_about_song(ctx) do
    {ctx, choice} = ctx |> next() |> select(["Hello!", "What are you singing?"])

    case choice do
      1 ->
        ctx
        |> mes("[Elle Cherno]")
        |> mes("Let's get to work")
        |> mes("fear-less comraaades~!")
        |> mes("Do our best! Nothing")
        |> mes("can stop us, lads~!")
        |> next()
        |> mes("[Elle Cherno]")
        |> mes("I like this song lots!")
        |> mes("Especially when I yell out")
        |> mes("''comrades!'' COMRADES!")
        |> close()

      2 ->
        ctx
        |> changequest(2079, 2080)
        |> set_char_var(:kain_ticket, 7)
        |> mes("[Elle Cherno]")
        |> mes("This...?")
        |> mes("It's the ''Miner's Song!''")
        |> mes("My mommy taught it to me")
        |> mes("and she sings it a lot. Daddy")
        |> mes("says it's too noisy, though.")
        |> next()
        |> mes("[Elle Cherno]")
        |> mes("Mmm, when my mommy sings")
        |> mes("this song, sometimes she looks")
        |> mes(
          "a little sad. Jus' today she sang it a little and looked like she was gonna cry. ^666666*Gasp!*^000000 Wait, do you"
        )
        |> mes("think maybe Mommy's sick?")
        |> next()
        |> mes("[Elle Cherno]")
        |> mes("Oh no, oh no...")
        |> mes("Hey, will you go see")
        |> mes("if my mommy's okay for me?")
        |> mes("Please? Our house is behind")
        |> mes("the Hotel, so tell me if she's")
        |> mes("not feeling good, promise?")
        |> close()

      _ ->
        ctx
    end
  end

  defp give_letter(ctx) do
    if checkweight(ctx, [{7276, 1}]) == 0 do
      ctx
      |> mes("[Elle Cherno]")
      |> mes("Hey! I have something")
      |> mes("to give you, but you have")
      |> mes("tooooo much stuff! Hey,")
      |> mes("come back later so I can")
      |> mes("give it to you, okay?")
      |> close()
    else
      ctx
      |> mes("[Elle Cherno]")
      |> mes("You saw my grandpa?")
      |> mes("You're his friend, right?")
      |> mes("A-are you gonna see")
      |> mes("him later? 'Cuz... cuz...")
      |> next()
      |> mes("[Elle Cherno]")
      |> mes("I made this for him.")
      |> mes("I don't know how to write,")
      |> mes("but I made Grampa a letter")
      |> mes("as best as I can. Will you")
      |> mes("promise to give this to him")
      |> mes("for me, pleeeeeease?")
      |> next()
      |> mes("^3355FFElle put a big")
      |> mes("doodled message")
      |> mes("into your hands.^000000")
      |> changequest(2084, 2085)
      |> set_char_var(:kain_ticket, 14)
      |> give_item(7276, 1)
      |> close()
    end
  end
end
