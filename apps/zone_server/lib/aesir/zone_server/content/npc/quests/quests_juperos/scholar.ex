defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Scholar do
  @moduledoc """
  Fayruz, a Juno Library scholar who runs the Juperos Ruins History quest.

  ## Behavior

  - Brushes the player off until they have read her thesis on the fall of Juperos, then asks
    for ancient Juperos documents and starts the quest log.
  - Asks the player to read the stone statue at the Juperos dungeon entrance and translates
    the message they recite.
  - Accepts each of the four Transparent Plates once, telling a story and granting 100,000
    base EXP (10,000 in renewal) for every new plate and advancing the quest log.
  - Trades a Gift Box for a plate from an era she already covered, and keeps trading extra
    plates for Gift Boxes once the quest is complete.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Fixed the upstream first-plate hand-in for a player holding only plate 7355: it called
    `Func_JupHist(7352,8)`, deleting a plate the player lacks; it now takes plate 7355, the
    plate its history bit 8 records.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "yuno_in04", x: 190, y: 125, dir: 4, sprite: 700, name: "Scholar", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @plates [7352, 7353, 7354, 7355]

  @second_plate_orders %{
    1 => [7353, 7354, 7355, 7352],
    2 => [7352, 7354, 7355, 7353],
    4 => [7352, 7353, 7355, 7354],
    8 => [7352, 7353, 7354, 7355]
  }

  @third_plate_orders %{
    3 => [7354, 7355, 7352, 7353],
    5 => [7353, 7355, 7352, 7354],
    6 => [7352, 7355, 7353, 7354],
    9 => [7353, 7354, 7352, 7355],
    10 => [7352, 7354, 7353, 7355],
    12 => [7352, 7353, 7354, 7355]
  }

  @last_plate_orders %{
    7 => [7355, 7352, 7353, 7354],
    11 => [7354, 7352, 7353, 7355],
    13 => [7353, 7352, 7354, 7355],
    14 => [7352, 7353, 7354, 7355]
  }

  @impl true
  def on_talk(ctx) do
    name = char_name(ctx, 0)

    case get_char_var(ctx, :yuno_hist, 0) do
      0 -> stranger(ctx, name)
      1 -> thesis_reader(ctx, name)
      2 -> statue_request(ctx)
      3 -> statue_report(ctx, name)
      4 -> first_plate_offer(ctx, name)
      5 -> second_plate_offer(ctx, name)
      6 -> research_progress(ctx, name)
      7 -> third_plate_offer(ctx, name)
      8 -> ctx |> translation_breakthrough(name) |> last_plate_offer(name)
      9 -> last_plate_offer(ctx, name)
      10 -> extra_plate_offer(ctx, name)
      _ -> ctx
    end
  end

  defp stranger(ctx, name) do
    case scholar_greeting(ctx, "Excuse me...") do
      {ctx, 1} ->
        brush_off(ctx)

      {ctx, 2} ->
        ctx
        |> mes("[Scholar]")
        |> mes("...")
        |> mes("......")
        |> mes("Hmm?")
        |> mes("...........")
        |> mes("Hmmm...")
        |> next()
        |> mes("[Scholar]")
        |> mes("You must be lost.")
        |> mes("This is the scholarly")
        |> mes("research section, you know,")
        |> mes("content you couldn't possibly")
        |> mes("fathom. The popular novels and picture books are someplace else.")
        |> next()
        |> mes("[#{name}]")
        |> mes("...")
        |> mes("......")
        |> next()
        |> mes("[Scholar]")
        |> mes("Why don't you rummage")
        |> mes("through the bookshelves?")
        |> mes("I'm sure you can find some")
        |> mes("book there that can hold your")
        |> mes("interest. Well, depending on")
        |> mes("your actual attention span...")
        |> next()
        |> mes("[#{name}]")
        |> mes("(What's her damage?!")
        |> mes("Does she have an attitude problem or is she just stuck-up?)")
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp thesis_reader(ctx, name) do
    case scholar_greeting(ctx, "By any chance...") do
      {ctx, 1} -> brush_off(ctx)
      {ctx, 2} -> discuss_thesis(ctx, name)
      {ctx, _} -> ctx
    end
  end

  defp scholar_greeting(ctx, second_option) do
    ctx
    |> mes("[Scholar]")
    |> mes("...Mm? ")
    |> mes("...Yes?")
    |> next()
    |> mes("[Scholar]")
    |> mes("...")
    |> mes("......")
    |> mes("May I help you?")
    |> next()
    |> select(["Oh! N-Nothing!", second_option])
  end

  defp brush_off(ctx) do
    ctx
    |> mes("[Scholar]")
    |> mes("...")
    |> mes("......")
    |> mes("Hmm?")
    |> mes("...........")
    |> mes("Hmpf.")
    |> close()
  end

  defp discuss_thesis(ctx, name) do
    ctx
    |> mes("[#{name}]")
    |> mes("By any chance...")
    |> mes("Are you conducting")
    |> mes("research about Juperos?")
    |> next()
    |> mes("[Scholar]")
    |> mes("Why yes, that is")
    |> mes("correct. But how did")
    |> mes("you come to learn about")
    |> mes("my current research project?")
    |> next()
    |> mes("[#{name}]")
    |> mes("Oh, I managed to read")
    |> mes("a thesis paper entitled,")
    |> mes("''The Fall of Juperos,'' and")
    |> mes("I just thought that the writing")
    |> mes("style and your personality")
    |> mes("seem to match for some reason.")
    |> next()
    |> mes("[Scholar]")
    |> mes("Oh...! You read my")
    |> mes("thesis? So what did")
    |> mes("you think about it?")
    |> next()
    |> mes("[#{name}]")
    |> mes("So far, it's alright, but")
    |> mes("quite frankly it's incomplete.")
    |> mes("I mean, you don't have much in")
    |> mes("in the way of conjecture, much")
    |> mes("less any evidence to back up")
    |> mes("any of your statements.")
    |> next()
    |> mes("[Scholar]")
    |> mes("....")
    |> mes("Let me apologize for")
    |> mes("being rude to you earlier.")
    |> mes("As you know, my name is")
    |> mes("Fayruz Khrhiyha. May I ask")
    |> mes("what your name might be?")
    |> next()
    |> mes("[#{name}]")
    |> mes("I'm #{name},")
    |> mes("a brave adventurer in the")
    |> mes("service of his royal majesty,")
    |> mes("the wise and benevolent")
    |> mes("King Tristram III.")
    |> set_char_var(:yuno_hist, 2)
    |> setquest(11_017)
    |> next()
    |> mes("[Fayruz]")
    |> mes("Well, #{name},")
    |> mes("I understand that my thesis")
    |> mes("still requires more evidence.")
    |> mes("But I'd need some ancient")
    |> mes("documents from Juperos")
    |> mes("to complete my research...")
    |> next()
    |> mes("[Fayruz]")
    |> mes("If you happen to travel")
    |> mes("through Juperos and find")
    |> mes("any ancient documents, would")
    |> mes("you bring them to me? Having")
    |> mes("those would help my research")
    |> mes("efforts immensely. Thank you...")
    |> close()
  end

  defp statue_request(ctx) do
    if holds_any_plate?(ctx) do
      ctx
      |> mes("[Fayruz]")
      |> mes("Ah, it's you! Listen,")
      |> mes("I just found a record of")
      |> mes("an adventurer who explored")
      |> mes("Juperos. There's mention")
      |> mes("of a stone statue here that")
      |> mes("just might be noteworthy...")
      |> next()
      |> mes("[Fayruz]")
      |> mes("If you happen to find")
      |> mes("yourself in Juperos,")
      |> mes("would you find the stone")
      |> mes("statue at the entrance of")
      |> mes("its dungeon and read the")
      |> mes("engraved message for me?")
      |> next()
      |> mes("[Fayruz]")
      |> mes("According to my notes,")
      |> mes("there's a spell that will")
      |> mes("make its reader memorize")
      |> mes("its message, even if they don't")
      |> mes("know the language. So come")
      |> mes("to me if you manage to read it.")
      |> close()
    else
      ctx
      |> mes("[Fayruz]")
      |> mes("If you ever chance to")
      |> mes("travel through Juperos,")
      |> mes("would you let me know if you")
      |> mes("find anything that might help")
      |> mes("my research there? I'd be")
      |> mes("very grateful for your help.")
      |> close()
    end
  end

  defp statue_report(ctx, name) do
    {ctx, choice} =
      ctx
      |> mes("[Fayruz]")
      |> mes("Well, you look")
      |> mes("quite pleased.")
      |> mes("May I ask what")
      |> mes("happened to put that")
      |> mes("expression on your face?")
      |> next()
      |> select(["I found something in Juperos.", "Nothing much."])

    case choice do
      1 ->
        translate_statue(ctx, name)

      2 ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Nothing, huh?")
        |> mes("My life is also fairly")
        |> mes("uneventful, but somehow,")
        |> mes("I'm don't think I'm content.")
        |> close()

      _ ->
        ctx
    end
  end

  defp translate_statue(ctx, name) do
    ctx
    |> mes("[#{name}]")
    |> mes("I went to Juperos like")
    |> mes("you asked and found that")
    |> mes("stone statue you were talking")
    |> mes("about. Just like you said, there was an engraved message on it.")
    |> next()
    |> mes("[Fayruz]")
    |> mes("Fascinating!")
    |> mes("So is it really enchanted")
    |> mes("so anyone can memorize it?")
    |> mes("Wh-what does the message say?")
    |> next()
    |> mes("^3355FFYou recite the message")
    |> mes("engraved on the stone")
    |> mes("statue, unable to interpret")
    |> mes("the sounds you're uttering,")
    |> mes("but weirdly enough, you can")
    |> mes("easily recall them from memory.^000000")
    |> next()
    |> mes("[Fayruz]")
    |> mes("Ah, I see! Wait,")
    |> mes("give me a moment to")
    |> mes("properly translate this...")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("[Fayruz]")
    |> mes("It means, ''Do you wish to")
    |> mes("see the end of the madness?")
    |> mes("He is waiting where the three")
    |> mes("columns were destroyed, where")
    |> mes("two hundred illusions wander.''")
    |> next()
    |> mes("[Fayruz]")
    |> mes("''You will see him, the one")
    |> mes("who was vain and extravagant,")
    |> mes("with your own eyes at the place where the light passes through.")
    |> set_char_var(:yuno_hist, 4)
    |> changequest(11_018, 11_019)
    |> next()
    |> mes("[Fayruz]")
    |> mes("Ah, usually, descriptions")
    |> mes("of the ''vain and extravagant")
    |> mes("one'' refer to the mad scientist rumored to have lived in that")
    |> mes("ancient era. But if this is true, I may have to rework my thesis...")
    |> next()
    |> mes("[Fayruz]")
    |> mes("I have another favor to")
    |> mes("ask of you. If you find any")
    |> mes("object of historical significance in Juperos, would you bring it to")
    |> mes("me? I'll reward you, of course.")
    |> next()
    |> mes("[Fayruz]")
    |> mes("It would be most helpful")
    |> mes("if you could manage to find")
    |> mes("documents that existed from that era. Fortunately, back then,")
    |> mes("they made all their records on material more durable than paper.")
    |> close()
  end

  defp first_plate_offer(ctx, name) do
    {ctx, choice} =
      ctx
      |> mes("[Fayruz]")
      |> mes("Oh hello, #{name}.")
      |> mes("So what brings you to")
      |> mes("the Juno Library today?")
      |> next()
      |> select([
        "Nice weather today, isn't it?",
        "I found something in Juperos.",
        "Nothing much."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Well, I wouldn't know.")
        |> mes("It's late whenever I go")
        |> mes("out, so I always happen to")
        |> mes("miss the sunlight. I guess")
        |> mes("I really miss nice weather")
        |> mes("sometimes, you know?")
        |> close()

      2 ->
        if holds_any_plate?(ctx),
          do: request_first_plate(ctx),
          else: ctx |> rummage_belongings() |> nothing_useful()

      3 ->
        suggest_reading(ctx, ["interesting topics, like the", "Schwarzwald economy..."])

      _ ->
        ctx
    end
  end

  defp request_first_plate(ctx) do
    {ctx, choice} =
      ctx
      |> rummage_belongings()
      |> mes("[Fayruz]")
      |> mes("Oh, this must be it!")
      |> mes("Would you mind if I keep")
      |> mes("this Transparent Plate for")
      |> mes("my research? In return, I'll")
      |> mes("tell you some tales about")
      |> mes("Juperos that I've learned.")
      |> next()
      |> select(["Please, be my guest.", "No way, you can't have it."])

    case choice do
      1 ->
        case held_plate(ctx, @plates, nil) do
          nil -> keep_plate(ctx)
          plate -> first_plate_story(ctx, plate)
        end

      2 ->
        keep_plate(ctx)

      _ ->
        ctx
    end
  end

  defp rummage_belongings(ctx) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Oh, really?!")
    |> mes("That's great news!")
    |> mes("W-what did you find?")
    |> next()
    |> mes("^3355FFIn her excitement,")
    |> mes("Fayruz begins to")
    |> mes("rummage through your")
    |> mes("things before you get")
    |> mes("the chance to answer her.^000000")
    |> next()
  end

  defp keep_plate(ctx) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Mm? Are you serious?")
    |> mes("This object is very valuable")
    |> mes("to a researcher like me, but")
    |> mes("I have no idea what use it")
    |> mes("would be for an adventurer.")
    |> mes("Well, you have your reasons...")
    |> close()
  end

  defp first_plate_story(ctx, plate) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Thank you so much,")
    |> mes("you don't know what")
    |> mes("this means to me! Okay,")
    |> mes("please relax and take a")
    |> mes("seat. Close your eyes while")
    |> mes("I tell you this ancient story.")
    |> next()
    |> mes("^3355FFFayruz begins to")
    |> mes("relate an ancient tale")
    |> mes("about Juperos that seems")
    |> mes("typical for a classic story, but her way of storytelling subtly")
    |> mes("draws you into a vicarious, yet extremely vivid experience.")
    |> next()
    |> mes("^3355FFYou feel the protagonist's")
    |> mes("glories and tragedies as if")
    |> mes("you were actually there with")
    |> mes("the hero on his journeys. The")
    |> mes("tale eventually comes to an end")
    |> mes("and you awaken from the trance,")
    |> mes("gently brought back to reality.^000000")
    |> delitem(plate, 1)
    |> set_char_var(:yuno_hist, 5)
    |> set_char_var(:jupe_hist, plate_bit(plate))
    |> getexp(story_exp(ctx), 0)
    |> changequest(11_019, 11_020)
    |> next()
    |> mes("[Fayruz]")
    |> mes("Everyone can relate")
    |> mes("to these old, classic")
    |> mes("stories. I hope this tale had")
    |> mes("as meaning for you as it did")
    |> mes("for me when I first heard it.")
    |> next()
    |> mes("[Fayruz]")
    |> mes("If you can find me")
    |> mes("another artifact from")
    |> mes("Juperos, I'll share another")
    |> mes("tale like that with you. Now")
    |> mes("how does that sound? Okay")
    |> mes("then, I'll see you, adventurer~")
    |> close()
  end

  defp second_plate_offer(ctx, name) do
    reading = ["interesting topics, like...", "like... Self-Honesty (?)."]

    {ctx, choice} =
      ctx
      |> mes("[Fayruz]")
      |> mes("Oh, #{name}!")
      |> mes("Have you come back with")
      |> mes("something from Juperos?")
      |> mes("I've been hoping you'd come")
      |> mes("back with something that'd")
      |> mes("help me in my research!")
      |> next()
      |> select(["Take a look at this.", "Oh, I'm sorry..."])

    case choice do
      1 ->
        case Map.fetch(@second_plate_orders, get_char_var(ctx, :jupe_hist, 0)) do
          {:ok, plates} -> second_plate_story(ctx, plates, name)
          :error -> suggest_reading(ctx, reading)
        end

      2 ->
        suggest_reading(ctx, reading)

      _ ->
        ctx
    end
  end

  defp second_plate_story(ctx, [first, second, third, same_era], name) do
    cond do
      held?(ctx, first) or held?(ctx, second) or held?(ctx, third) ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Oh, that's unexpected.")
        |> mes("This Transparent Plate")
        |> mes("seems to have been made")
        |> mes("in a different era than the")
        |> mes("one you gave me earlier.")
        |> mes("How intriguing...")
        |> next()
        |> mes("[Fayruz]")
        |> mes("*Sigh* I really wish")
        |> mes("that I could explore")
        |> mes("Juperos on my own, but")
        |> mes("I'm just not strong enough.")
        |> mes("In a way, I'm quite jealous of you. But it can't be helped...")
        |> next()
        |> mes("[Fayruz]")
        |> mes("You know, that reminds")
        |> mes("me of this great story of")
        |> mes("a tragic hero that I'd like to")
        |> mes("share with you. Let your")
        |> mes("mind wander as I relate this ageless, yet bittersweet tale...")
        |> next()
        |> mes("^3355FFFayruz tells you a story")
        |> mes("with a bright beginning, full")
        |> mes("of hope that fills you with the")
        |> mes("bliss of the heavens, but then")
        |> mes("suddenly plummets you into all the despair and torment of hell.^000000")
        |> next()
        |> mes("^3355FFThe story finally")
        |> mes("reaches its ending")
        |> mes("and you're surprised")
        |> mes("to find yourself sitting")
        |> mes("in the Juno Library.^000000")
        |> next()
        |> mes("[Fayruz]")
        |> mes("I know it's a very")
        |> mes("depressing story, but")
        |> mes("I hope you enjoyed it.")
        |> mes("I think you'd agree that")
        |> mes("it contains a truth about")
        |> mes("mankind that can't be ignored.")
        |> donate_held_plate([first, second], third)
        |> set_char_var(:yuno_hist, 6)
        |> changequest(11_020, 11_021)
        |> getexp(story_exp(ctx), 0)
        |> next()
        |> mes("[Fayruz]")
        |> mes("By now I'm sure you've")
        |> mes("figured that these classic")
        |> mes("tales are like condensed")
        |> mes("experiences, refined and")
        |> mes("immutable truths that we")
        |> mes("can see in our own reality.")
        |> next()
        |> mes("[Fayruz]")
        |> mes("If you find more of")
        |> mes("these Transparent")
        |> mes("Plates in Juperos, I'd be")
        |> mes("very happy to share another")
        |> mes("story with you, #{name}.")
        |> close()

      held?(ctx, same_era) ->
        ctx
        |> similar_era_thanks()
        |> delitem(same_era, 1)
        |> give_item(644, 1)
        |> next()
        |> back_to_research(name)

      true ->
        nothing_useful(ctx)
    end
  end

  defp research_progress(ctx, name) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Oh, #{name}!")
    |> mes("The Transparent Plate")
    |> mes("that you brought for me")
    |> mes("last time is really helping me")
    |> mes("in my research. If you get the")
    |> mes("chance, please bring me more!")
    |> set_char_var(:yuno_hist, 7)
    |> next()
    |> mes("[Fayruz]")
    |> mes("This new data is adding")
    |> mes("a lot more credibility to my")
    |> mes("thesis. Oh, I'll be with you")
    |> mes("in a moment, let me finish")
    |> mes("translating this one last")
    |> mes("passage really quickly...")
    |> close()
  end

  defp third_plate_offer(ctx, name) do
    {ctx, choice} =
      ctx
      |> mes("[Fayruz]")
      |> mes("Hello, #{name}~")
      |> mes("Oh, were you able to look")
      |> mes("in Juperos for anything that")
      |> mes("might help me in my research?")
      |> next()
      |> select(["Yeah, take a look at this.", "No, I'm sorry..."])

    case choice do
      1 ->
        case Map.fetch(@third_plate_orders, get_char_var(ctx, :jupe_hist, 0)) do
          {:ok, plates} -> third_plate_story(ctx, plates, name)
          :error -> no_deadline(ctx)
        end

      2 ->
        no_deadline(ctx)

      _ ->
        ctx
    end
  end

  defp no_deadline(ctx) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Oh, that's fine.")
    |> mes("Besides, I don't really")
    |> mes("have a deadline to complete")
    |> mes("this research project. Still,")
    |> mes("I just want you to know that")
    |> mes("I really appreciate your help.")
    |> close()
  end

  defp third_plate_story(ctx, [first, second, same_era, other_same_era], name) do
    cond do
      held?(ctx, first) or held?(ctx, second) ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Is this another")
        |> mes("Transparent Plate?")
        |> mes("Yes, it's quite different")
        |> mes("than the last one you")
        |> mes("brought over to me...")
        |> mes("This is so exciting!")
        |> next()
        |> mes("[Fayruz]")
        |> mes("Oh. You must be thinking")
        |> mes("that I'm a complete academia")
        |> mes("addict. Well, my life might be")
        |> mes("a little uneventful, but there")
        |> mes("are other things I think about!")
        |> mes("Like, well... It's weird but...")
        |> next()
        |> mes("[Fayruz]")
        |> mes("You see, there's this")
        |> mes("guy that I like. I'm not sure")
        |> mes("where he might be now, but")
        |> mes("his name is Nadim Amal. He's")
        |> mes("my friend's brother who I first")
        |> mes("met 10 years ago. ^333333*Sigh...*^000000")
        |> next()
        |> mes("[Fayruz]")
        |> mes("Just recently, I saw")
        |> mes("him with his sister, my")
        |> mes("friend from Morocc. It's")
        |> mes("weird to think that I'd have")
        |> mes("these feelings for him after")
        |> mes("all this time, isn't it? Oh...!")
        |> next()
        |> mes("[Fayruz]")
        |> mes("I really should repay")
        |> mes("you for this Transparent")
        |> mes("Plate. Why don't I tell you")
        |> mes("the scariest story that I know?")
        |> next()
        |> mes("^3355FFFayruz tells you a")
        |> mes("creepy horror story that")
        |> mes("makes you shiver with fear.")
        |> mes("You've heard other ghost")
        |> mes("stories, but you've never been")
        |> mes("so deeply immersed in one before.^000000")
        |> next()
        |> mes("It is only when the")
        |> mes("story ends and you return")
        |> mes("to your senses that you notice that you're soaked in cold sweat.^000000")
        |> next()
        |> mes("[Fayruz]")
        |> mes("It may be a natural")
        |> mes("response, but all people")
        |> mes("fear the unknown in one way")
        |> mes("or another. Scary stories are")
        |> mes("appealing because we actually")
        |> mes("like the strange and grotesque.")
        |> donate_held_plate([first, second], nil)
        |> set_char_var(:yuno_hist, 8)
        |> changequest(11_021, 11_022)
        |> getexp(story_exp(ctx), 0)
        |> next()
        |> mes("[Fayruz]")
        |> mes("Well... That's just my")
        |> mes("opinion. Anyway, if you")
        |> mes("find anything else in Juperos")
        |> mes("that may help in my research,")
        |> mes("please come back and show it")
        |> mes("to me, alright? See you later~")
        |> close()

      held?(ctx, same_era) or held?(ctx, other_same_era) ->
        ctx
        |> similar_era_thanks()
        |> next()
        |> back_to_research_without_close(name)
        |> trade_held_plate([same_era, other_same_era], nil)
        |> give_item(644, 1)
        |> close()

      true ->
        nothing_useful(ctx)
    end
  end

  defp translation_breakthrough(ctx, name) do
    ctx
    |> mes("[Fayruz]")
    |> mes("#{name}...")
    |> mes("I'm having great difficulty in")
    |> mes("translating that Transparent")
    |> mes("Plate you brought for me that")
    |> mes("last time. I'm so frustrated...")
    |> next()
    |> mes("[Fayruz]")
    |> mes("Wait a minute...")
    |> mes("This here means...")
    |> mes("Alright. Okay. Yes.")
    |> mes("Yes! Of course, how")
    |> mes("could I not see it before!")
    |> set_char_var(:yuno_hist, 9)
    |> next()
    |> mes("[Fayruz]")
    |> mes("I'll be with you")
    |> mes("in just a second!")
    |> mes("I think I just made")
    |> mes("a real through...!")
    |> next()
  end

  defp last_plate_offer(ctx, name) do
    reading = ["interesting topics, like", "modern adventure history."]

    {ctx, choice} =
      ctx
      |> mes("[Fayruz]")
      |> mes("Ah, I've been")
      |> mes("expecting you, #{name}.")
      |> mes("So did you have been to Juperos again? I'm really hoping that you")
      |> mes("were able to find something new that would help in my research...")
      |> next()
      |> select(["Actually, I did find this...", "I'm sorry, I haven't..."])

    case choice do
      1 ->
        case Map.fetch(@last_plate_orders, get_char_var(ctx, :jupe_hist, 0)) do
          {:ok, plates} -> last_plate_story(ctx, plates)
          :error -> suggest_reading(ctx, reading)
        end

      2 ->
        suggest_reading(ctx, reading)

      _ ->
        ctx
    end
  end

  defp last_plate_story(ctx, [last, same_era, other_same_era, final_same_era]) do
    cond do
      held?(ctx, last) ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Oooh...! This one is")
        |> mes("much different than the")
        |> mes("other ones you gave me")
        |> mes("before. This should provide")
        |> mes("a wealth of brand new insights")
        |> mes("into the Juperos civilization!")
        |> next()
        |> mes("[Fayruz]")
        |> mes("All the Transparent")
        |> mes("Plates you've given me")
        |> mes("should contain more than")
        |> mes("enough data for me to fully")
        |> mes("complete my research thesis.")
        |> mes("Once again, thank you so much~")
        |> next()
        |> mes("[Fayruz]")
        |> mes("Still, that doesn't mean that")
        |> mes("I will stop collecting data for")
        |> mes("my research. Anyway, I have one last story to tell you, about")
        |> mes("a man of pure heart chosen by the gods to serve and protect mankind.")
        |> next()
        |> mes("[Fayruz]")
        |> mes("For this purpose he was given")
        |> mes("gaudy armor which contained")
        |> mes("amazing powers, as well as a")
        |> mes("book detailing the instructions")
        |> mes("for its use. However, he promptly")
        |> mes("lost these instructions...")
        |> next()
        |> mes("^3355FFThe story about the")
        |> mes("greatest Juperosian hero")
        |> mes("that Fayruz tells you is very")
        |> mes("humorous at first, but then it")
        |> mes("covers the entire spectrum")
        |> mes("of emotion and humanity...")
        |> next()
        |> mes("^3355FFThe story ends and you")
        |> mes("are left with a swelling")
        |> mes("feeling of indefatigable")
        |> mes("hope and inspiration...")
        |> mes("You can make it if you try!^000000")
        |> record_plate(last)
        |> set_char_var(:yuno_hist, 10)
        |> completequest(11_022)
        |> delitem(last, 1)
        |> getexp(story_exp(ctx), 0)
        |> next()
        |> mes("[Fayruz]")
        |> mes("Well, that is the")
        |> mes("last and the best story")
        |> mes("that I have to share")
        |> mes("with you. Perhaps next")
        |> mes("time, I'll fill you in on my")
        |> mes("research progress~")
        |> close()

      held?(ctx, same_era) or held?(ctx, other_same_era) or held?(ctx, final_same_era) ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Hmm...")
        |> mes("This one seems to be created in a similar time")
        |> mes("as the previous one.")
        |> next()
        |> mes("[Fayruz]")
        |> mes("Don't you worry.")
        |> mes("This will help my research of course,")
        |> mes("although I do not think this will")
        |> mes("help me in advancing my research")
        |> mes("with a great speed unlike this other one.")
        |> next()
        |> mes("[Fayruz]")
        |> mes("Please take this as a token of my gratitude.")
        |> next()
        |> mes("[Fayruz]")
        |> mes("Now, excuse me. I need to go back to my research.")
        |> trade_held_plate([same_era, other_same_era], final_same_era)
        |> give_item(644, 1)
        |> close()

      true ->
        nothing_useful(ctx)
    end
  end

  defp extra_plate_offer(ctx, name) do
    {ctx, choice} =
      ctx
      |> mes("[Fayruz]")
      |> mes("Oh hello, #{name}...")
      |> mes("So what exactly brings you")
      |> mes("to the Juno Library this time?")
      |> next()
      |> select(["I found another Transparent Plate.", "Just visiting, really."])

    case choice do
      1 ->
        if holds_any_plate?(ctx), do: trade_extra_plate(ctx, name), else: no_plate_found(ctx)

      2 ->
        ctx
        |> mes("[Fayruz]")
        |> mes("Ah, I see. Well,")
        |> mes("thanks to your help,")
        |> mes("I've made a great deal")
        |> mes("of progress on my thesis.")
        |> mes("I really appreciate what you")
        |> mes("have done for me, adventurer.")
        |> close()

      _ ->
        ctx
    end
  end

  defp trade_extra_plate(ctx, name) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Hmm, well, we've made as")
    |> mes("much headway as we can")
    |> mes("with the Transparent Plates")
    |> mes("you've already given me, but")
    |> mes("it can't hurt to have too much")
    |> mes("evidence to back my theories.")
    |> next()
    |> mes("[Fayruz]")
    |> mes("I really appreciate")
    |> mes("your continuing efforts")
    |> mes("to help me. Please, would")
    |> mes("you take this as my way")
    |> mes("saying ''Thanks?'' You've been")
    |> mes("great, #{name}...")
    |> trade_held_plate([7352, 7353, 7354], 7355)
    |> give_item(644, 1)
    |> close()
  end

  defp no_plate_found(ctx) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Mmm...?")
    |> mes("It doesn't look like")
    |> mes("you brought another")
    |> mes("Transparent Plate.")
    |> mes("Are you sure that you")
    |> mes("didn't misplace it?")
    |> close()
  end

  defp similar_era_thanks(ctx) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Oh, this one seems")
    |> mes("to have been created")
    |> mes("in a similar era as the")
    |> mes("one you gave me earlier.")
    |> mes("I'm not sure how much new")
    |> mes("information this may provide...")
    |> next()
    |> mes("[Fayruz]")
    |> mes("Still, I'm sure this will")
    |> mes("helpful in my research. I just")
    |> mes("won't be as making progress")
    |> mes("as quickly as I had projected.")
    |> mes("Please, I'd like you to take this as a token of my gratitude.")
  end

  defp back_to_research(ctx, name) do
    ctx
    |> back_to_research_without_close(name)
    |> close()
  end

  defp back_to_research_without_close(ctx, name) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Now if you'll excuse")
    |> mes("me, I need to go back")
    |> mes("to compiling my research...")
    |> mes("Thank you so much for")
    |> mes("your help, #{name}.")
  end

  defp nothing_useful(ctx) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Oh. There isn't anything")
    |> mes("here that would help in my")
    |> mes("research, but thank you anyway.")
    |> mes("If you find anything else while")
    |> mes("you're in Juperos, please come back and show it to me, alright?")
    |> close()
  end

  defp suggest_reading(ctx, topic_lines) do
    ctx
    |> mes("[Fayruz]")
    |> mes("Ah, I see. Well, while")
    |> mes("you're here, why don't you")
    |> mes("read something? There are")
    |> mes("many books that cover some")
    |> mes_lines(topic_lines)
    |> next()
    |> mes("[Fayruz]")
    |> mes("Oh, in any case, please")
    |> mes("don't forget the favor I asked")
    |> mes("of you. If you find anything")
    |> mes("in Juperos that's historically")
    |> mes("significant, I'd appreciate it")
    |> mes("if you bring it right away.")
    |> close()
  end

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))

  defp holds_any_plate?(ctx), do: Enum.any?(@plates, &held?(ctx, &1))

  defp held?(ctx, item_id), do: Rathena.truthy?(count_item(ctx, item_id))

  defp held_plate(ctx, candidates, fallback),
    do: Enum.find(candidates, fallback, &held?(ctx, &1))

  defp trade_held_plate(ctx, candidates, fallback),
    do: delete_plate(ctx, held_plate(ctx, candidates, fallback))

  defp donate_held_plate(ctx, candidates, fallback) do
    plate = held_plate(ctx, candidates, fallback)
    ctx |> delete_plate(plate) |> record_plate(plate)
  end

  defp delete_plate(ctx, nil), do: ctx
  defp delete_plate(ctx, plate), do: delitem(ctx, plate, 1)

  defp record_plate(ctx, nil), do: ctx

  defp record_plate(ctx, plate),
    do: set_char_var(ctx, :jupe_hist, get_char_var(ctx, :jupe_hist, 0) + plate_bit(plate))

  defp plate_bit(7352), do: 1
  defp plate_bit(7353), do: 2
  defp plate_bit(7354), do: 4
  defp plate_bit(7355), do: 8

  defp story_exp(ctx), do: if(Rathena.truthy?(checkre(ctx, 3)), do: 10_000, else: 100_000)
end
