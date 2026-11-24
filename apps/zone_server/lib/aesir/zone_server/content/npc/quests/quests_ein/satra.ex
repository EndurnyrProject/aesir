defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Satra do
  @moduledoc """
  Lady Satra Kappelthaine judges Klitzer's worth through gifts of Coal in the Lovers Quest.

  ## Behavior

  - Introduces herself and asks for Coal, advancing the quest log.
  - Accepts three deliveries of 10 Coal, sharing Einbroch's history with each.
  - On the fourth delivery, asks who gathered the Coal; naming Klitzer earns him an
    invitation to tea.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
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
        map: "ein_in01",
        x: 31,
        y: 151,
        dir: 3,
        sprite: 850,
        name: "Satra",
        scope: :shared,
        unique_name: "Satra#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @coal 1003

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :EIN_LOVERQ, 0)

    ctx =
      cond do
        progress > 12 -> invitation_sent(ctx)
        progress == 12 and coal?(ctx) -> ask_gatherer(ctx)
        progress == 12 -> ctx |> fourth_greeting() |> forgot_coal()
        progress == 11 and coal?(ctx) -> third_delivery(ctx)
        progress == 11 -> third_reminder(ctx)
        progress == 10 and coal?(ctx) -> second_delivery(ctx)
        progress == 10 -> second_reminder(ctx)
        progress == 9 and coal?(ctx) -> first_delivery(ctx)
        progress == 9 -> ctx |> request_coal() |> next() |> farewell()
        progress == 8 -> start_coal_request(ctx)
        true -> idle_chat(ctx)
      end

    close(ctx)
  end

  defp coal?(ctx), do: count_item(ctx, @coal) > 9

  defp invitation_sent(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("I understand that my")
    |> mes("home is extravagantly")
    |> mes("splendid and to approach")
    |> mes("any Kappelthaine is an")
    |> mes("honor to most commoners.")
    |> next()
    |> mes("[Satra]")
    |> mes("However, Klitzer")
    |> mes("has no reason to feel so")
    |> mes("intimidated. Tell the poor")
    |> mes("boy that he's earned the")
    |> mes("honor of speaking with me.")
  end

  defp fourth_greeting(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("Ho ho ho ho~")
    |> mes("Welcome adventurer,")
    |> mes("I so enjoy our little chats.")
    |> mes("Hors d'oeuvre?")
    |> next()
  end

  defp forgot_coal(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("Ah...")
    |> mes("It seems you've")
    |> mes("forgotten your ^FF0000Coals^000000.")
    |> mes("A silly mistake, but one")
    |> mes("I'm willing to overlook.")
  end

  defp ask_gatherer(ctx) do
    {ctx, gatherer} =
      ctx
      |> fourth_greeting()
      |> mes("[Satra]")
      |> mes("Oh! You can't enjoy")
      |> mes("any food in that state!")
      |> mes("Your hands are atrociously")
      |> mes("grimy! May I ask why?")
      |> next()
      |> mes("[Satra]")
      |> mes("Ah~")
      |> mes("In my excitement,")
      |> mes("I nearly forgot that")
      |> mes("I asked you to bring")
      |> mes("Coals to me again!")
      |> mes("My apologies~")
      |> next()
      |> mes("[Satra]")
      |> mes("You've brought so much Coal")
      |> mes("to me, I'm convinced that you're much more diligent than those")
      |> mes("languid peasants in Einbech.")
      |> mes("I appreciate that you've labored so much to win my favor.")
      |> next()
      |> mes("[Satra]")
      |> mes("Hm, what was that?")
      |> mes("Someone else provided")
      |> mes("these Coals and you were")
      |> mes("only delivering them? Then")
      |> mes("who actually gathered these?")
      |> next()
      |> input(:string)

    if gatherer == "Klitzer" do
      invite_klitzer(ctx)
    else
      ctx
      |> mes("[Satra]")
      |> mes("I beg your pardon?")
      |> mes(Rathena.concat(gatherer, "? Oh my..."))
      |> mes("I believe I may have")
      |> mes("misheard you. Ho ho ho ho~")
    end
  end

  defp invite_klitzer(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("Ah, Klitzer?")
    |> mes("I must say, that's")
    |> mes("a very humble name.")
    |> mes("Yet it's so familiar...")
    |> next()
    |> mes("[Satra]")
    |> mes("Ah, I recall there")
    |> mes("was a hooligan that")
    |> mes("has been pestering my")
    |> mes("daughter named Klitzer.")
    |> mes("Perhaps they are one")
    |> mes("and the same. Hmm...")
    |> next()
    |> mes("[Satra]")
    |> mes("I remember that he was")
    |> mes("rather shabby looking and")
    |> mes("lacked any semblance of")
    |> mes("etiquette whatsoever. Clearly,")
    |> mes("he is a fool and a coward, but now I see that he is sincere.")
    |> next()
    |> mes("[Satra]")
    |> mes("It might not be possible")
    |> mes("to let him go out with my")
    |> mes("daughter straight away, but")
    |> mes("I will invite him for a spot of")
    |> mes("tea. And if Calla likes him,")
    |> mes("well, he must be special.")
    |> next()
    |> mes("[Satra]")
    |> mes("For a humble peasant,")
    |> mes("this must be like a dream")
    |> mes("come true! And to have tea")
    |> mes("with Klitzer. Oh, what would")
    |> mes("the girls say? Ah, but I did")
    |> mes("marry that oafish Megass~")
    |> next()
    |> delitem(@coal, 10)
    |> set_char_var(:EIN_LOVERQ, 13)
    |> changequest(8084, 8085)
    |> mes("[Satra]")
    |> mes("Anyway, when you next")
    |> mes("meet Klitzer, please tell")
    |> mes("him to pay me a visit soon.")
    |> mes("Oh, and remind him to dress")
    |> mes("appropriately for this special")
    |> mes("occasion. Ho ho ho ho ho~")
  end

  defp third_greeting(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("Why hello~")
    |> mes("Your visits have")
    |> mes("recently been quite")
    |> mes("delightful, fair adventurer.")
    |> next()
  end

  defp third_delivery(ctx) do
    ctx
    |> third_greeting()
    |> mes("[Satra]")
    |> mes("Continue to show")
    |> mes("your appreciation")
    |> mes("and dedication to me")
    |> mes("and you'll soon be known")
    |> mes("to be my most favored")
    |> mes("commoner. Ho ho ho ho~")
    |> next()
    |> mes("[Satra]")
    |> mes("I'm sure you've noticed")
    |> mes("the strained relationship")
    |> mes("between Einbroch and Einbech")
    |> mes("by now. It's a shame, really.")
    |> next()
    |> mes("[Satra]")
    |> mes("As Einbroch grew wealthier")
    |> mes("and Einbech became more")
    |> mes("destitude, the affluent began")
    |> mes("despising the impoverished.")
    |> mes("I suppose it follows that the poor started to resent the rich.")
    |> next()
    |> mes("[Satra]")
    |> mes("It might be said that")
    |> mes("both towns have been")
    |> mes("trying to take advantage")
    |> mes("of each other, but it's")
    |> mes("clear that Einbroch has")
    |> mes("always had the upper hand.")
    |> next()
    |> mes("[Satra]")
    |> mes("In fact, because of")
    |> mes("this rift between our")
    |> mes("cities, our families are")
    |> mes("taught not to associate")
    |> mes("with the people of Einbech.")
    |> next()
    |> mes("[Satra]")
    |> mes("Now, I believe that most")
    |> mes("people who live in Einbech")
    |> mes("are peons, but that does not")
    |> mes("mean I will not give them a")
    |> mes("chance to prove their worth.")
    |> next()
    |> delitem(@coal, 10)
    |> set_char_var(:EIN_LOVERQ, 12)
    |> mes("[Satra]")
    |> mes("Why should I deprive")
    |> mes("the lowly of my gracious")
    |> mes("presense if they prove")
    |> mes("themselves meritable?")
    |> mes("Ho ho ho ho~")
    |> next()
    |> mes("[Satra]")
    |> mes("Oh, that was scrumptious!")
    |> mes("If you wish to pay me another")
    |> mes("visit, don't forget to bring some Coal with you. Tah tah~")
  end

  defp third_reminder(ctx) do
    ctx
    |> third_greeting()
    |> mes("[Satra]")
    |> mes("Oh, my apologies!")
    |> mes("I suppose you're just")
    |> mes("here for sight seeing,")
    |> mes("or perhaps you're running")
    |> mes("some sort of adventurer's")
    |> mes("errand. Am I right?")
    |> next()
    |> mes("[Satra]")
    |> mes("I know you well enough")
    |> mes("to know that you wouldn't")
    |> mes("be so rude as to stop by")
    |> mes("and chat without bringing")
    |> mes("any ^FF0000Coal^000000. Ho ho ho ho~")
  end

  defp second_greeting(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("^333333*Titter~*^000000")
    |> mes("Why, if it isn't my")
    |> mes("intrepid adventurer.")
    |> mes("Ho ho ho ho~")
    |> next()
  end

  defp second_delivery(ctx) do
    ctx
    |> second_greeting()
    |> mes("[Satra]")
    |> mes("My word!")
    |> mes("Why are you carrying")
    |> mes("all of that dirty Coal")
    |> mes("with you? You poor,")
    |> mes("impoverished thing.")
    |> next()
    |> mes("[Satra]")
    |> mes("Oh! Dear me,")
    |> mes("I've nearly forgotten~")
    |> mes("How divinely silly of me!")
    |> mes("Once again, I graciously")
    |> mes("accept your small gift on")
    |> mes("behalf of the Kappellthaines.")
    |> next()
    |> mes("[Satra]")
    |> mes("Let me share a little")
    |> mes("bit of history concerning")
    |> mes("our lovely Einbroch. At one")
    |> mes("time, there was only Einbech,")
    |> mes("the mining village. You can")
    |> mes("imagine how long ago that was.")
    |> next()
    |> mes("[Satra]")
    |> mes("However, the minerals")
    |> mes("and ores mined in Einbech")
    |> mes("need to be processed and")
    |> mes("refined in factories that were")
    |> mes("all built in a nearby industrial complex which became Einbroch.")
    |> next()
    |> mes("[Satra]")
    |> mes("Now every citizen in")
    |> mes("Einbroch is wealthy and")
    |> mes("it's well known that there")
    |> mes("is a higher standard of")
    |> mes("living here than in Einbech.")
    |> next()
    |> delitem(@coal, 10)
    |> set_char_var(:EIN_LOVERQ, 11)
    |> mes("[Satra]")
    |> mes("Goodness, I believe")
    |> mes("it's time for a spot of tea~")
    |> mes("The next time you wish to have")
    |> mes("an audience with me, it would")
    |> mes("behoove you to bring another")
    |> mes("gift of Coal. Toodles~")
  end

  defp second_reminder(ctx) do
    ctx
    |> second_greeting()
    |> mes("[Satra]")
    |> mes("My apologies, but you")
    |> mes("must first prove to me")
    |> mes("that you are worthy of")
    |> mes("conversation. Why don't")
    |> mes("you deliver more of those")
    |> mes("^FF0000Coals^000000, mmm?")
    |> next()
    |> mes("[Satra]")
    |> mes("After all, I have no other")
    |> mes("means of knowing whether")
    |> mes("or not you appreciate the time")
    |> mes("I sacrifice by socializing with")
    |> mes("someone of your status.")
    |> mes("Ho ho ho ho~")
  end

  defp first_delivery(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("My, you've already")
    |> mes("brought the Coal?")
    |> mes("How charmingly")
    |> mes("prompt you are~")
    |> next()
    |> mes("[Satra]")
    |> mes("On behalf of the")
    |> mes("Kappellthaine family,")
    |> mes("I shall ignore your lowly")
    |> mes("status and graciously")
    |> mes("accept your small gift.")
    |> mes("Ho ho ho ho~")
    |> next()
    |> mes("[Satra]")
    |> mes("Do you hail from")
    |> mes("Einbech, adventurer?")
    |> mes("Ah, the Rune-Midgarts")
    |> mes("kingdom! I've visited your")
    |> mes("country. It's quite quaint")
    |> mes("and Jawaii is very lovely.")
    |> next()
    |> delitem(@coal, 10)
    |> set_char_var(:EIN_LOVERQ, 10)
    |> changequest(8083, 8084)
    |> mes("[Satra]")
    |> mes("Well, I shall try to")
    |> mes("find some use for these.")
    |> mes("I'm afraid the gift I've asked")
    |> mes("from you isn't very practical.")
    |> mes("How is Coal usually used?")
    |> mes("Ah, I have a novel idea!")
    |> next()
    |> mes("[Satra]")
    |> mes("Wouldn't it be")
    |> mes("intoxicatingly wild if")
    |> mes("Megass were to hold one")
    |> mes("of those social functions that")
    |> mes("the lower classes are so fond")
    |> mes("of? A 'barbeque,' yes?")
    |> next()
    |> mes("[Satra]")
    |> mes("In any case, if you")
    |> mes("bring me more of that")
    |> mes("Coal, you would be even")
    |> mes("more favored by me and")
    |> mes("you'll become a recipient")
    |> mes("of my good graces. Ho ho~")
  end

  defp start_coal_request(ctx) do
    ctx
    |> request_coal()
    |> set_char_var(:EIN_LOVERQ, 9)
    |> log_coal_request()
    |> next()
    |> farewell()
  end

  defp log_coal_request(ctx) do
    if isbegin_quest(ctx, 8081) == 1 do
      changequest(ctx, 8081, 8083)
    else
      changequest(ctx, 8082, 8083)
    end
  end

  defp request_coal(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("A wandering adventurer...?")
    |> mes("How ravishingly delightful!")
    |> mes("You must have risked life and")
    |> mes("limb to sneak past my husband")
    |> mes("to enjoy the captivating sights")
    |> mes("of my home. Ho ho ho ho~")
    |> next()
    |> mes("[Satra]")
    |> mes("Since you're a very")
    |> mes("unique guest, I shall")
    |> mes("give you a unique honor")
    |> mes("and deign to converse")
    |> mes("with you, adventurer.")
    |> next()
    |> mes("[Satra]")
    |> mes("Einbech exists to provide")
    |> mes("my family with coal and")
    |> mes("materials from their mines.")
    |> mes("It's a natural law: workers")
    |> mes("must be led by a chosen few.")
    |> next()
    |> mes("[Satra]")
    |> mes("It's delightfully")
    |> mes("ludicrous to see those")
    |> mes("workers aspire to reach")
    |> mes("our heights of social")
    |> mes("prestige. Ho ho ho ho~")
    |> next()
    |> mes("[Satra]")
    |> mes("Oh, I haven't spoken to")
    |> mes("someone from a lower")
    |> mes("class in ages! It feels")
    |> mes("so forbiddenly exciting!")
    |> next()
    |> mes("[Satra]")
    |> mes("Well adventurer, that's ")
    |> mes("the end of our informal")
    |> mes("chat. I'll even grant you")
    |> mes("full permission to boast")
    |> mes("of the fact that you've")
    |> mes("spoken to Lady Satra.")
    |> next()
    |> mes("[Satra]")
    |> mes("If you do wish for")
    |> mes("me to share words with")
    |> mes("you once more, prove to")
    |> mes("me that you're worthier")
    |> mes("than the other peons of")
    |> mes("my graceful presense.")
    |> next()
    |> mes("[Satra]")
    |> mes("Oh, I have a marvelous")
    |> mes("idea! Why don't you bring")
    |> mes("me ^990000Coals^000000? It's not impossible")
    |> mes("for someone like yourself, but")
    |> mes("this kind of task will require")
    |> mes("some effort on your part.")
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("Tah tah,")
    |> mes("adventurer~")
  end

  defp idle_chat(ctx) do
    ctx
    |> mes("[Satra]")
    |> mes("A wandering")
    |> mes("adventurer...?")
    |> mes("How sinfully")
    |> mes("intriguing!")
    |> mes("Ho ho ho ho~")
    |> next()
    |> mes("[Satra]")
    |> mes("Oh, do not worry.")
    |> mes("I'm sure the beauty of")
    |> mes("my home has captured your")
    |> mes("curiosity. My brutish excuse")
    |> mes("for a husband would have you")
    |> mes("beat if he found you...")
    |> next()
    |> mes("[Satra]")
    |> mes("But I'm far more genteel")
    |> mes("than Megass. You're more")
    |> mes("than welcome to enjoy the")
    |> mes("furnishings. Ho ho ho ho~")
  end
end
