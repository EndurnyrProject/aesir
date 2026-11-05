defmodule Aesir.ZoneServer.Content.Npc.Quests.EyeOfHellion.Enoz do
  @moduledoc """
  Enoz is Welshyun's student searching for his missing reference book.

  ## Behavior

  - Responds to the exact title of Welshyun's report and reveals his prank.
  - Accepts the reference book and sends the player back to Welshyun.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gef_tower",
        x: 116,
        y: 37,
        dir: 0,
        sprite: 748,
        name: "Enoz",
        scope: :shared,
        unique_name: "Enoz#hellion"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :HELLIONQ, 0) do
      step when step in [59, 62] -> ask_about_report(ctx)
      63 -> missing_book(ctx)
      64 -> return_book(ctx)
      _ -> distressed(ctx)
    end
  end

  defp ask_about_report(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Enoz]")
      |> mes("It's gone, it's gone!")
      |> mes("Where the hell did it go?!")
      |> mes("Oh man, who could have")
      |> mes("taken it? Wait, was it... You?!")
      |> next()
      |> select(["Actually, Welshyun sent me.", "No way man, don't go nuts."])

    if choice == 1 do
      report_title(ctx)
    else
      ctx
      |> mes("[Enoz]")
      |> mes("Nuts?! Oh, you wanna")
      |> mes("see crazy, is that it?! You")
      |> mes("wanna see insaaaane?!")
      |> mes("Cuz I'll go freakin' medieval")
      |> mes("if you keep bothering me!!")
      |> close()
    end
  end

  defp report_title(ctx) do
    {ctx, title} =
      ctx
      |> mes("[Enoz]")
      |> mes("My mentor, Welshyun?")
      |> mes("Huh. Is there a report")
      |> mes("I haven't submitted to him")
      |> mes("yet? So what was it called?")
      |> next()
      |> input(:string)

    if title == "Monster Life in the Geffen Area" do
      ctx
      |> mes("[Enoz]")
      |> mes("''Monster Life in")
      |> mes("the Geffen Area?''")
      |> mes("Oh no. My mentor took")
      |> mes("that three days ago!")
      |> mes("Is he still up to his")
      |> mes("old tricks again?")
      |> next()
      |> mes("[Enoz]")
      |> mes("Awww nuts!")
      |> mes("Where the heck is")
      |> mes("my Master Science")
      |> mes("Reference Book? ")
      |> mes("It was right here")
      |> mes("three days ago...")
      |> set_char_var(:HELLIONQ, 63)
      |> close()
    else
      ctx = mes(ctx, "[Enoz]")

      ctx
      |> mes("#{title}?")
      |> mes("I haven't completed")
      |> mes("any research related")
      |> mes("to that subject. Or did I?")
      |> mes("Anyway, I need the exact")
      |> mes("name of the report you want!")
      |> close()
    end
  end

  defp missing_book(ctx) do
    ctx
    |> mes("[Enoz]")
    |> mes("My mentor Welshyun's")
    |> mes("been playing jokes again,")
    |> mes("so you better go talk to him.")
    |> mes("Damn. Where is that Master")
    |> mes("Science Reference Book?")
    |> close()
  end

  defp return_book(ctx) do
    ctx
    |> mes("[Enoz]")
    |> mes("Oh hey, I remember you~")
    |> mes("So did my mentor send you")
    |> mes("to me again for some reason?")
    |> next()
    |> mes("^3355FFYou cautiously hand Enoz the")
    |> mes("Master Science Reference Book.^000000")
    |> next()
    |> mes("[Enoz]")
    |> mes("Yes! Oh yes!")
    |> mes("This is the book")
    |> mes("I lost three days")
    |> mes("ago! Thanks so much!")
    |> mes("Now I can finally finish")
    |> mes("this research project that--")
    |> next()
    |> mes("[Enoz]")
    |> mes("Wait, the page I really")
    |> mes("need is missing! And there's")
    |> mes("some sort of note... Umm...")
    |> mes("^333333''Enoz, I think this page")
    |> mes("is worth at least one Apple")
    |> mes("Juice. Right? --Welshyun.''^000000")
    |> next()
    |> mes("[Enoz]")
    |> mes("NOooOOoOo!")
    |> mes("Not agaaaaain!")
    |> mes("Why is he always")
    |> mes("playing these pranks?!")
    |> mes("Apple Juice! I need")
    |> mes("some Apple Juice!")
    |> set_char_var(:HELLIONQ, 65)
    |> next()
    |> mes("^3355FFIt looks like it's time")
    |> mes("to get 1 Blue Gemstone,")
    |> mes("and then bring it back")
    |> mes("to Welshyun the Sage.^000000")
    |> close()
  end

  defp distressed(ctx) do
    ctx
    |> mes("[Enoz]")
    |> mes("Gone! It's gone!")
    |> mes("Where did the book")
    |> mes("I really need go to?")
    |> mes("Oh no oh no oh no oh no!")
    |> mes("Waaaaaah, I'm gonna cry!")
    |> close()
  end
end
