defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.MrShendar do
  @moduledoc """
  Bruspetti’s father worries about his missing daughter.

  ## Behavior

  - Discusses Bruspetti and helps the player investigate her disappearance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "ra_in01", x: 250, y: 19, dir: 3, sprite: 929, name: "Mr. Shendar", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rach_vice, 0) > 21 ->
        waiting(ctx)

      get_char_var(ctx, :rach_vice, 0) == 14 ->
        suspect(ctx)

      get_char_var(ctx, :rach_vice, 0) == 13 ->
        intruder(ctx)

      get_char_var(ctx, :rach_vice, 0) == 9 ->
        diary(ctx)

      get_char_var(ctx, :rach_vice, 0) == 8 ->
        news(ctx)

      get_char_var(ctx, :rach_vice, 0) == 4 or get_char_var(ctx, :rach_vice, 0) == 5 ->
        misses_daughter(ctx)

      get_char_var(ctx, :rach_vice, 0) == 2 ->
        worried(ctx)

      get_char_var(ctx, :rach_vice, 0) == 1 ->
        first_news(ctx)

      true ->
        greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp waiting(ctx) do
    ctx
    |> mes("[Mr. Shendar]")
    |> mes("When will my precious")
    |> mes("daughter Bruspetti be")
    |> mes("coming home? I'm sure that")
    |> mes("she can take care of herself,")
    |> mes("but a father can't help but")
    |> mes("worry himself to death.")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Ah, if you happen to")
    |> mes("see my daughter in your")
    |> mes("travels, please tell her")
    |> mes("that her daddy is waiting")
    |> mes("for her to come home.")
    |> mes("Thanks, adventurer.")
    |> close()
  end

  defp suspect(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Shendar]")
      |> mes("So you have a pretty")
      |> mes("good idea of who was")
      |> mes("sneaking around my house?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Well, I suspect this guy")
    |> mes("named Katinshuell because")
    |> mes("he might have been Bruspetti's")
    |> mes("boyfriend and he's been acting")
    |> mes("funny. Still, I don't have any")
    |> mes("real evidence of that.")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Bruspetti's boyfriend?!")
    |> mes("Hmpf! I don't like that")
    |> mes("boy already. I haven't")
    |> mes("met him yet, but its my")
    |> mes("solemn duty as a father")
    |> mes("to hate and distrust him!")
    |> close()
  end

  defp intruder(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Shendar]")
      |> mes("Hey! Hey! Are you")
      |> mes("the pervert that's been")
      |> mes("sneaking into my house")
      |> mes("to prey on my daughter?!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wha--?")
      |> mes("No, I'm just a--")
      |> next()
      |> percent_heal(hp: -50, sp: 0)
      |> mes("^3355FF*BAM!*^000000")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ow! What did")
      |> mes("you do that for?")
      |> next()
      |> mes("[Mr. Shendar]")
      |> mes("Still alive, eh? Hmpf!")
      |> mes("I'll finish you off! I'll...")
      |> mes("Er, huh?! Wait, I think")
      |> mes("I know you. You're that")
      |> mes("adventurer that's been")
      |> mes("here before, right?")
      |> next()
      |> mes("[Mr. Shendar]")
      |> mes("Oh... I think I've made")
      |> mes("a mistake. I thought you")
      |> mes("were that person that's")
      |> mes("been prowling around my")
      |> mes("house. I don't know who he,")
      |> mes("but I'm sure it's not you...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wait, wait...")
      |> mes("So someone has been")
      |> mes("sneaking around here?")
      |> mes("That's weird. Wait, that")
      |> mes("guy, the one that might")
      |> mes("be Bruspetti's boyfriend...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Right, his name was")
    |> mes("Katinshuell. That guy's")
    |> mes("been acting really funny.")
    |> mes("Maybe he was the one sneaking")
    |> mes("around here? I'd better go")
    |> mes("and ask him about this...")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Wait, where are")
    |> mes("you going? I... I'm")
    |> mes("sorry for hitting you?")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Curses! If that guy is my")
    |> mes("daughter's boyfriend, and he's")
    |> mes("trespassing into my home, then")
    |> mes("he could be really dangerous.")
    |> mes("It's too bad that I can't ask")
    |> mes("Bruspetti anything about him...")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Hm... Alright, adventurer.")
    |> mes("If you can find it, I'll allow")
    |> mes("you to take and read my")
    |> mes("daughter's diary. We need")
    |> mes("to learn more about this guy")
    |> mes("Katinshuell. If he's dangerous...")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("I'm sorry... I'm asking you")
    |> mes("for your help... But there's")
    |> mes("nothing else I can do as her")
    |> mes("father. Besides, adventurers")
    |> mes("like you can offer her the")
    |> mes("best protection...")
    |> set_char_var(:rach_vice, 14)
    |> changequest(8117, 8118)
    |> close()
  end

  defp diary(ctx) do
    ctx
    |> mes("[Mr. Shendar]")
    |> mes("Curses! I should have never")
    |> mes("mentioned my daughter's")
    |> mes("diary to an adventurer like")
    |> mes("you! I know that your kind")
    |> mes("is naturally too curious...!")
    |> close()
  end

  defp news(ctx) do
    ctx
    |> mes("[Mr. Shendar]")
    |> mes("What? My daughter went")
    |> mes("to Lighthalzen? She doesn't")
    |> mes("know anyone there. Hmm, maybe")
    |> mes("that's the place where she was")
    |> mes("planning to go to learn more")
    |> mes("about what was bothering her.")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Yes, she was very generic:")
    |> mes("''Dad, I need to go somewhere.''")
    |> mes("and ''There's something I need")
    |> mes("to make sure of.'' Leaving out")
    |> mes("all the details does not put")
    |> mes("a doting father at ease!")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Well, thank you for letting")
    |> mes("me know where she might be.")
    |> mes("Now, I wish I knew what she")
    |> mes("was planning on doing. Maybe")
    |> mes("she wrote something about it")
    |> mes("in her diary? Yes, perhaps...")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("No! I can't do it!")
    |> mes("As a loving father, I can't")
    |> mes("allow myself to invade my")
    |> mes("precious daughter's privacy.")
    |> mes("Even if she did carelessly leave")
    |> mes("her diary on top of her drawer.")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Oh, but how a father")
    |> mes("worries. Will my sweet,")
    |> mes("darling Bruspetti be alright?")
    |> set_char_var(:rach_vice, 9)
    |> changequest(8112, 8113)
    |> close()
  end

  defp misses_daughter(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Shendar]")
      |> mes("I miss my daughter. Yes,")
      |> mes("the house smells different")
      |> mes("without her around. It's a little")
      |> mes("weird to be talking about this,")
      |> mes("but Bruspetti always did smell")
      |> mes("nice, just like her mother.")
      |> next()
      |> mes("[Mr. Shendar]")
      |> mes("Even if they didn't wear")
      |> mes("perfume, they had this")
      |> mes("distinctively pleasant")
      |> mes("scent about them. I guess")
      |> mes("it must be pheremonal?")

    ctx =
      if get_char_var(ctx, :rach_vice, 0) == 4 do
        ctx |> set_char_var(:rach_vice, 5) |> changequest(8108, 8109)
      else
        ctx
      end

    close(ctx)
  end

  defp worried(ctx) do
    ctx
    |> mes("[Mr. Shendar]")
    |> mes("Take my advice: never")
    |> mes("have a daughter! You worry")
    |> mes("too much about them, and they")
    |> mes("neglect their parents once")
    |> mes("they grow up! I bet she's")
    |> mes("having a grand old time...")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Confound it...!")
    |> mes("Whoever that guy is,")
    |> mes("he better not try any funny")
    |> mes("business! As her father, I have")
    |> mes("the legal right to wring his")
    |> mes("little neck! At least, I should...")
    |> close()
  end

  defp first_news(ctx) do
    ctx
    |> mes("[Mr. Shendar]")
    |> mes("I just found out that")
    |> mes("my precious daughter has")
    |> mes("been going out with someone.")
    |> mes("She went to some other town")
    |> mes("for this boy, and I haven't")
    |> mes("heard a word from her since!")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Take my advice: never")
    |> mes("have a daughter! You worry")
    |> mes("too much about them, and they")
    |> mes("neglect their parents once")
    |> mes("they grow up! I bet she's")
    |> mes("having a grand old time...")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Probably on some lovey")
    |> mes("dovey trip with whoever that")
    |> mes("boy is. She's been gone an")
    |> mes("awful long time, but she's")
    |> mes("also an adult now. I... I guess")
    |> mes("she should be just fine.")
    |> set_char_var(:rach_vice, 2)
    |> setquest(8106)
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Mr. Shendar]")
    |> mes("I just found out that")
    |> mes("my precious daughter has")
    |> mes("been going out with someone.")
    |> mes("She went to some other town")
    |> mes("to see this boy, and I haven't")
    |> mes("heard a word from her since!")
    |> next()
    |> mes("[Mr. Shendar]")
    |> mes("Take my advice: never")
    |> mes("have a daughter! You worry")
    |> mes("too much about them, and they")
    |> mes("neglect their parents once")
    |> mes("they grow up! I bet she's")
    |> mes("having a grand old time...")
    |> close()
  end
end
