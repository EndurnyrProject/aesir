defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.PassionateStudent do
  @moduledoc """
  Benkaistein studies while his friends quarrel at home.

  ## Behavior

  - Asks the player to find and deliver his journal to reconcile his friends.
  - Rewards the player with experience and a pass after the delivery.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 96,
        y: 106,
        dir: 5,
        sprite: 754,
        name: "Passionate Student",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 300 or checkweight(ctx, [{1201, 1}]) == 0 ->
        overweight(ctx)

      get_char_var(ctx, :friendship, 0) == 15 ->
        reward_delivery(ctx)

      get_char_var(ctx, :friendship, 0) == 11 and count_item(ctx, 7351) > 0 ->
        receive_journal(ctx)

      get_char_var(ctx, :friendship, 0) in [10, 11] ->
        search_for_journal(ctx)

      get_char_var(ctx, :friendship, 0) == 9 ->
        hear_about_friends(ctx)

      get_char_var(ctx, :friendship, 0) == 8 ->
        get_attention(ctx)

      true ->
        study(ctx)
    end
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

  defp reward_delivery(ctx) do
    ctx =
      ctx
      |> cutin("lhz_benkaistin01.bmp", 2)
      |> mes("[Benkaistein]")
      |> mes("Were you able to bring")
      |> mes("my journal to Digotz and")
      |> mes("Maku? I'm pretty sure it'd")
      |> mes("remind them of all the good")
      |> mes("times we had. I know they")
      |> mes("sure can be stubborn...")
      |> next()
      |> mes("[Benkaistein]")
      |> mes("Anyway, I really")
      |> mes("appreciate all your")
      |> mes("help. When I go back")
      |> mes("home, I look forward to")
      |> mes("seeing the two of them again.")
      |> next()
      |> mes("[Benkaistein]")
      |> mes("Until then, I need to research,")
      |> mes("finish my thesis and accomplish")
      |> mes("my academic goals. Oh, please")
      |> mes("take this pass which will let you")
      |> mes("go back and forth between the")
      |> mes("rich and poor areas as my thanks.")
      |> next()
      |> set_char_var(:friendship, 16)
      |> completequest(12_006)

    ctx = give_reward_exp(ctx)

    ctx
    |> give_item(7350, 1)
    |> mes("[Benkaistein]")
    |> mes("Anyway, I wish you")
    |> mes("safety in your travels,")
    |> mes("adventurer. When the three")
    |> mes("of us get together, I'll be")
    |> mes("sure to let you know~")
    |> close()
    |> cutin("", 255)
  end

  defp receive_journal(ctx) do
    ctx
    |> mes("[Benkaistein]")
    |> mes("Aw nuts, this is")
    |> mes("taking much longer")
    |> mes("than I had expected.")
    |> mes("Now where did I put")
    |> mes("that thing? Hmmmm...")
    |> next()
    |> cutin("lhz_benkaistin02.bmp", 2)
    |> mes("[Benkaistein]")
    |> mes("Oh, is that it?")
    |> mes("Did you find my")
    |> mes("journal? Quick, let")
    |> mes("me check. Yes, yes...")
    |> mes("This is it! Thank you")
    |> mes("for finding this for me!")
    |> next()
    |> cutin("", 255)
    |> mes("[Benkaistein]")
    |> mes("Would you mind doing")
    |> mes("a favor for me? It'd be")
    |> mes("better if I talk to them")
    |> mes("myself, but I'm too busy")
    |> mes("working on this thesis...")
    |> next()
    |> mes("[Benkaistein]")
    |> mes("Would you please give this")
    |> mes("journal to Digotz and Maku?")
    |> mes("I wrote in it when we were")
    |> mes("really young, so it should")
    |> mes("remind them of all the good")
    |> mes("times we used to share.")
    |> next()
    |> set_char_var(:friendship, 12)
    |> changequest(12_004, 12_005)
    |> cutin("lhz_benkaistin04.bmp", 2)
    |> mes("[Benkaistein]")
    |> mes("Anyway, this should at")
    |> mes("least help them realize")
    |> mes("how stupid they've been")
    |> mes("acting. Thanks in advance,")
    |> mes("and please take care of")
    |> mes("Maku and Digotz for me.")
    |> close()
    |> cutin("", 255)
  end

  defp search_for_journal(ctx) do
    ctx
    |> mes("[Benkaistein]")
    |> mes("Aw nuts, this is")
    |> mes("taking much longer")
    |> mes("than I had expected.")
    |> mes("Now where did I put")
    |> mes("that thing? Hmmmm...")
    |> next()
    |> mes("^3355FFPerhaps it would")
    |> mes("be best if you help")
    |> mes("Benkaistein look for")
    |> mes("he is searching for.^000000")
    |> close()
  end

  defp hear_about_friends(ctx) do
    {ctx, _} =
      ctx
      |> cutin("lhz_benkaistin03.bmp", 2)
      |> mes("[Passionate Student]")
      |> mes("Oh, you startled me!")
      |> mes("Still, I'm aware that it's")
      |> mes("hard to get my attention")
      |> mes("once I immerse myself")
      |> mes("in a book. So, how can")
      |> mes("I help you, adventurer?")
      |> next()
      |> select(["Tell him about Maku and Digotz."])

    ctx
    |> cutin("lhz_benkaistin02.bmp", 2)
    |> mes("[Benkaistein]")
    |> mes("Oh, how are my friends")
    |> mes("doing? Oh, what? They're")
    |> mes("having a huge fight just")
    |> mes("because one's rich and")
    |> mes("the other one's poor?")
    |> mes("That's pretty childish!")
    |> next()
    |> mes("[Benkaistein]")
    |> mes("But then again, that's just")
    |> mes("like them. *Sigh* I really want")
    |> mes("to go back home and get those")
    |> mes("two to make up, but I also need")
    |> mes("to finish this thesis. Let's see... What can I possibly do from here?")
    |> next()
    |> set_char_var(:friendship, 10)
    |> changequest(12_003, 12_004)
    |> mes("[Benkaistein]")
    |> mes("Oh, I know what I can do!")
    |> mes("Wait, but where did I put it?")
    |> mes("Oh, how could I lose something")
    |> mes("so important? Wait! Would you")
    |> mes("please wait a second while")
    |> mes("I look for something?")
    |> close()
    |> cutin("", 255)
  end

  defp get_attention(ctx) do
    {ctx, _} =
      ctx
      |> cutin("lhz_benkaistin04.bmp", 2)
      |> mes("[Passionate Student]")
      |> mes("Let's see, now.")
      |> mes("Wind Magic, Black Magic,")
      |> mes("Porings, ah, there it is.")
      |> mes("Monster race properties.")
      |> mes("Hopefully this contains")
      |> mes("the information I need...")
      |> next()
      |> mes("^3355FFUpon briefly glancing at")
      |> mes("this student's belongings,")
      |> mes("you notice that the name")
      |> mes("''Benkaistein'' is printed")
      |> mes("on them. This is the friend")
      |> mes("mentioned by Maku and Digotz!^000000")
      |> next()
      |> select(["Excuse me..."])

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me...")
      |> mes("Benkaistein?")
      |> next()
      |> mes("[Passionate Student]")
      |> mes("...The world of humans")
      |> mes("and the world of demons,")
      |> mes("yes, yes... No, what I'm")
      |> mes("looking for is a reference")
      |> mes("to the heavens or Asgard.")
      |> mes("Hmm, this here might help...")
      |> next()
      |> select(["Hey..."])

    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hey...")
      |> mes("Over here.")
      |> mes("Benkaistein!")
      |> next()
      |> mes("[Passionate Student]")
      |> mes("...Oh, now that's a very")
      |> mes("interesting observation.")
      |> mes("If I can incorporate that")
      |> mes("into my thesis without too")
      |> mes("much trouble, my standpoint")
      |> mes("would look much more solid...")
      |> next()
      |> select(["HEY YOU...!"])

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("HEY YOU...!")
    |> mes("BENKAISTEIN~!")
    |> cutin("", 255)
    |> next()
    |> cutin("lhz_benkaistin02.bmp", 2)
    |> mes("[Passionate Student]")
    |> mes("Oh, good heavens!")
    |> mes("C-can't you keep")
    |> mes("your voice down?")
    |> mes("I-I'm trying to study!")
    |> mes("No, wait. Have you been")
    |> mes("calling me all this time?")
    |> set_char_var(:friendship, 9)
    |> close()
    |> cutin("", 255)
  end

  defp study(ctx) do
    ctx
    |> mes("[Passionate Student]")
    |> mes("Let's see, now.")
    |> mes("Wind Magic, Black Magic,")
    |> mes("Porings, ah, there it is.")
    |> mes("Monster race properties.")
    |> mes("Hopefully this contains")
    |> mes("the information I need...")
    |> next()
    |> mes("^3355FFThis student seems to")
    |> mes("be dilligently conducting")
    |> mes("intensive research on some")
    |> mes("academic subject. For now,")
    |> mes("it would be best to leave him")
    |> mes("alone so that he can study.^000000")
    |> close()
  end

  defp give_reward_exp(ctx) do
    renewal = Rathena.truthy?(checkre(ctx, 3))

    experience =
      cond do
        base_level(ctx) > 90 -> 700_000
        base_level(ctx) > 75 -> 400_000
        true -> 200_000
      end

    experience = if renewal, do: div(experience, 10), else: experience
    getexp(ctx, experience, 0)
  end
end
