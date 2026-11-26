defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Historian do
  @moduledoc """
  A historian researching the history of Rune-Midgarts.

  ## Behavior

  - Receives his books and shares the history of the kingdom.
  - Sends a research report to his colleague and later recalls her visit.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 311,
        y: 195,
        dir: 3,
        sprite: 754,
        name: "Historian",
        scope: :shared,
        unique_name: "Historian#prt01"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        overweight(ctx)

      get_char_var(ctx, :prt_curse, 0) < 3 ->
        research(ctx)

      get_char_var(ctx, :prt_curse, 0) == 3 ->
        receive_books(ctx)

      get_char_var(ctx, :prt_curse, 0) == 4 ->
        history(ctx)

      get_char_var(ctx, :prt_curse, 0) == 5 ->
        request_delivery(ctx)

      get_char_var(ctx, :prt_curse, 0) == 6 ->
        delivery_reminder(ctx)

      get_char_var(ctx, :prt_curse, 0) > 55 ->
        reunion(ctx)

      true ->
        sleeping(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overweight(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp research(ctx) do
    ctx
    |> mes("[Historian]")
    |> mes("Juno's mysterious past")
    |> mes("holds some great secret.")
    |> mes("I'm sure of it! It excites me")
    |> mes("to know that my research")
    |> mes("brings me that much closer")
    |> mes("to finally unveiling it!")
    |> next()
    |> mes("[Historian]")
    |> mes("But I'll admit that even I don't know how much digging I'll")
    |> mes("have to do to learn what I want. It's our duty as historians to")
    |> mes("find out the truth of the past, but it definitely won't be easy.")
    |> next()
    |> mes("[Historian]")
    |> mes("To understand, to see the")
    |> mes("truth of the past with my")
    |> mes("own eyes... I'd even sell")
    |> mes("my soul for the opportunity.")
    |> close()
  end

  defp receive_books(ctx) do
    {ctx, _} =
      ctx
      |> mes("^3355FFAs you approached, this")
      |> mes("historian suddenly closed")
      |> mes("the book that he was reading,")
      |> mes("looked to the heavens and")
      |> mes("let out a deep breath in a vain")
      |> mes("attempt to relieve his tension.^000000")
      |> next()
      |> mes("[Historian]")
      |> mes("GRRRRRRRRR!")
      |> mes("Where are my books?!")
      |> emotion(:anger)
      |> next()
      |> select(["Are you alright?"])

    ctx =
      ctx
      |> mes("[Historian]")
      |> mes("Er? Oh. I'm sorry you")
      |> mes("had to see that. I'm just")
      |> mes("extremely upset. You see,")
      |> mes("I'm expecting a delivery of")
      |> mes("research books from Prontera,")
      |> mes("but they haven't arrived yet.")
      |> next()
      |> mes("[Historian]")
      |> mes("In fact, the delivery boy is")
      |> mes("very late. This will delay my")
      |> mes("research considerably since")
      |> mes("I cannot proceed without more")
      |> mes("new material to study.")
      |> next()

    if count_item(ctx, 7431) > 0 do
      {ctx, _} = select(ctx, ["Excuse me, but what's your name?"])

      ctx =
        ctx
        |> mes("[Historian]")
        |> mes("Hm? I'm Karlomoff, the")
        |> mes("1st scholar of the Rekenber")
        |> mes("Historical Research Group.")
        |> mes("Did you need something, or")
        |> mes("were you looking around here")
        |> mes("for somebody in particular?")
        |> next()

      {ctx, _} = select(ctx, ["Right, I brought your books."])

      ctx
      |> mes("[Historian]")
      |> mes("What? But you're not the")
      |> mes("delivery boy. Well, let me see")
      |> mes("the books you've brought. Hm...")
      |> mes("Just as I thought: the Rune-")
      |> mes("Midgarts Kingdom has a great")
      |> mes("wealth of ancient information.")
      |> next()
      |> mes("[Historian]")
      |> mes("Ah, thank you so much for")
      |> mes("bringing these. However, by")
      |> mes("your mode of dress, I can tell")
      |> mes("that you are an adventurer.")
      |> mes("What happened to the delivery boy that was supposed to bring these?")
      |> next()
      |> mes("[Historian]")
      |> mes("..........?")
      |> mes("Afraid to ride the Airship?")
      |> mes("Motion sickness? Well, that's")
      |> mes("quite understandable. The poor")
      |> mes("boy should have contacted me")
      |> mes("about that beforehand.")
      |> next()
      |> mes("[Historian]")
      |> mes("Goodness, it's been ")
      |> mes("a while since I've had")
      |> mes("a visitor. Would you like")
      |> mes("to stay and chat for a bit?")
      |> mes("Just give me a minute to get")
      |> mes("a cool drink of water first~")
      |> set_char_var(:prt_curse, 4)
      |> delitem(7431, 1)
      |> close()
    else
      {ctx, _} = select(ctx, ["Oh, I'm delivering the books for him."])

      ctx =
        ctx
        |> emotion(:question)
        |> mes("[Historian]")
        |> mes("Ah, really?")
        |> mes("Great, you're here!")
        |> mes("So, where are the books?")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I...")
      |> mes("I don't have")
      |> mes("them right now.")
      |> next()
      |> mes("[Historian]")
      |> mes("What...?")
      |> mes("Don't tell me that")
      |> mes("you lost them! Those")
      |> mes("books were priceless!")
      |> mes("Did you come all this")
      |> mes("way just to tell me that?")
      |> next()
      |> mes("[Historian]")
      |> mes("Well, I suppose you'll")
      |> mes("have to report the loss of")
      |> mes("the books and get some new")
      |> mes("copies of those books that")
      |> mes("you were supposed to deliver.")
      |> mes("Now hurry, I need to research!")
      |> close()
    end
  end

  defp history(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Historian]")
      |> mes("Ah, that glass of")
      |> mes("water was just what")
      |> mes("I needed to refresh")
      |> mes("myself. Let me tell you")
      |> mes("a little bit about my work.")
      |> next()
      |> mes("[Historian]")
      |> mes("I might have it mentioned before, but my name is Karlomoff and")
      |> mes("I work in the Rekenber Historical Research as its 1st scholar. We")
      |> mes("recently finished our project on the Schwarzwald Republic.")
      |> next()
      |> mes("[Historian]")
      |> mes("Now, we're trying to learn")
      |> mes("more about the Rune-Midgarts")
      |> mes("Kingdom's history. We believe")
      |> mes("it's linked to our Schwarzwald")
      |> mes("Republic because they share the")
      |> mes("continent. Makes sense, right?")
      |> next()
      |> mes("[Historian]")
      |> mes("Ultimately, we hope that")
      |> mes("new information from our")
      |> mes("research of Rune-Midgarts will")
      |> mes("shed some new light on our")
      |> mes("current understanding of the")
      |> mes("Schwarzwald Republic's past.")
      |> next()
      |> mes("[Historian]")
      |> mes("Including myself, there are")
      |> mes("^3131FF3 members of the Rekenber")
      |> mes("Historical Research Group^000000")
      |> mes("that are studying the Rune-")
      |> mes("Midgarts Kingdom's history.")
      |> next()
      |> select(["Rekenber Historical Research Group?"])

    {ctx, _} =
      ctx
      |> mes("[Historian]")
      |> mes("You adventurers from Rune-")
      |> mes("Midgarts may not know it, but")
      |> mes("the Rekenber Corporation has")
      |> mes("unofficial control over our")
      |> mes("Schwarzwald Republic. Some")
      |> mes("hate it, others don't care.")
      |> next()
      |> mes("[Historian]")
      |> mes("Anyway, Rekenber has its own")
      |> mes("Historical Research Group since")
      |> mes("rediscovering ancient technologies has been key to its success, well,")
      |> mes("so far as I can tell. Personally, I enjoy the pursuit of knowledge.")
      |> next()
      |> mes("[Historian]")
      |> mes("Oh, here's an interesting")
      |> mes("fact! Did you know that the")
      |> mes("title of ruler of Rune-Midgarts")
      |> mes("isn't always passed down")
      |> mes("through the same family?")
      |> next()
      |> mes("[Historian]")
      |> mes("Actually, there are several")
      |> mes("royal families that hold a")
      |> mes("special competition to decide")
      |> mes("which prince becomes the")
      |> mes("next king. Fascinating...")
      |> next()
      |> select(["Several royal families?"])

    ctx
    |> mes("[Historian]")
    |> mes("Yes, I'll try to explain it")
    |> mes("briefly. There are a total")
    |> mes("of 7 royal families. Each")
    |> mes("family is descended from one")
    |> mes("of the 7 warriors that founded")
    |> mes("the Rune-Midgarts Kingdom.")
    |> next()
    |> mes("[Historian]")
    |> mes("According to the records,")
    |> mes("Jormungand, the snake of the")
    |> mes("earth, appeared and brought")
    |> mes("chaos to the entire continent.")
    |> mes("7 warriors appeared and drove the serpent away, saving the world.")
    |> next()
    |> mes("[Historian]")
    |> mes("With the return of peace,")
    |> mes("the 7 warriors established")
    |> mes("the Rune-Midgarts Kingdom,")
    |> mes("choosing Tristram Geoborg III")
    |> mes("as the kingdom's first ruler. ")
    |> next()
    |> mes("[Historian]")
    |> mes("Knowing that their descendents")
    |> mes("may not always be deserving of")
    |> mes("ruling the kingdom, the 7 warriors agreed to hold a contest amongst")
    |> mes("their families each generation to prevent royal corruption.")
    |> next()
    |> emotion(:profusely_sweat)
    |> mes("[Historian]")
    |> mes("Oh... Not too excited")
    |> mes("about history, huh? Well,")
    |> mes("maybe if I sing the ancient")
    |> mes("song of this myth, you'd be")
    |> mes("better able to understand...")
    |> next()
    |> mes("[Historian]")
    |> mes("^FF0000*The great serpent*^000000")
    |> mes("^FF0000*swallowed the sea.*^000000")
    |> mes("^FF0000*The eagle of the rainbow*^000000")
    |> mes("^FF0000*swallowed the serpent.*^000000")
    |> mes("^FF0000*Then the eagle built its nest.*^000000")
    |> mes("^FF0000*A nest upon the swallowed sea.*^000000")
    |> next()
    |> mes("[Historian]")
    |> mes("^333333*Ahem*^000000 As you see, I'm")
    |> mes("quite tone deaf. But the")
    |> mes("point is that people still")
    |> mes("praise the 7 warriors' exploits")
    |> mes("through this song. Isn't that")
    |> mes("interesting to know about?")
    |> set_char_var(:prt_curse, 5)
    |> close()
  end

  defp request_delivery(ctx) do
    ctx
    |> mes("[Historian]")
    |> mes("I'm sorry that I let my")
    |> mes("mouth run while talking at")
    |> mes("great length about Rune-")
    |> mes("Midgart's history. Still,")
    |> mes("I hope you found that tale")
    |> mes("at least a little enjoyable.")
    |> next()
    |> mes("[Historian]")
    |> mes("Oh! Will you be returning to")
    |> mes("the Rune-Midgarts Kingdom?")
    |> mes("If so, then I have a favor to")
    |> mes("ask you. Would you please")
    |> mes("deliver this report I've written to my colleague in Morocc?")
    |> next()
    |> mes("[Historian]")
    |> mes("It would be a great help")
    |> mes("to me if you could get this")
    |> mes("report to her right away.")
    |> mes("Ah, her name is Rodafrian.")
    |> mes("I'm certain you can find her")
    |> mes("somewhere in that desert town.")
    |> set_char_var(:prt_curse, 6)
    |> give_item(7342, 1)
    |> close()
  end

  defp delivery_reminder(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Historian]")
      |> mes("Please find my colleague,")
      |> mes("Rodafrian, in Morocc and")
      |> mes("deliver my report to her.")
      |> mes("You should be able to find")
      |> mes("her there doing research.")
      |> next()
      |> select(["I will", "Can I listen to that song again?"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Historian]")
        |> mes("Once again, thank")
        |> mes("you for your help.")
        |> mes("It will really speed the")
        |> mes("progress of my research,")
        |> mes("especially since those books")
        |> mes("were delivered fairly late...")
      else
        ctx
        |> mes("[Historian]")
        |> mes("Song? Oh, you mean the")
        |> mes("one praising the 7 who")
        |> mes("founded the Rune-Midgarts")
        |> mes("Kingdom? Sure, let's see now...")
        |> next()
        |> mes("[Historian]")
        |> mes("^FF0000*The great serpent*^000000")
        |> mes("^FF0000*swallowed the sea.*^000000")
        |> mes("^FF0000*The eagle of the rainbow*^000000")
        |> mes("^FF0000*swallowed the serpent.*^000000")
        |> mes("^FF0000*Then the eagle built its nest.*^000000")
        |> mes("^FF0000*A nest upon the swallowed sea.*^000000")
        |> next()
        |> mes("[Historian]")
        |> mes("You must be more interested")
        |> mes("in history than I suspected.")
        |> mes("If you'd like, I'll write you a")
        |> mes("letter or recommendation")
        |> mes("for the Rekenber Historical")
        |> mes("Research Group. Ha ha ha~")
      end

    close(ctx)
  end

  defp reunion(ctx) do
    ctx
    |> mes("[Historian]")
    |> mes("Ah, it's been a while")
    |> mes("since the last time I saw")
    |> mes("you. Rodafrian actually came")
    |> mes("to visit me a few days ago.")
    |> mes("I believe she came here")
    |> mes("to gloat or threaten me...")
    |> next()
    |> mes("[Historian]")
    |> mes("It was very surreal.")
    |> mes("She kept raving about")
    |> mes("some incredible revelation,")
    |> mes("and about finally putting me")
    |> mes("in my place. I didn't know she")
    |> mes("could be so competitive!")
    |> close()
  end

  defp sleeping(ctx) do
    ctx
    |> mes("[Historian]")
    |> mes("ZzzzZZz....")
    |> mes("ZzzzZZz....ZZZzzzz...")
    |> close()
  end
end
