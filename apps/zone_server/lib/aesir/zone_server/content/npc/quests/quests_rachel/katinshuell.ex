defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Katinshuell do
  @moduledoc """
  A guilt-ridden Rachel townsman whose secret drives the Bruspetti quest.

  ## Behavior

  - Before the quest he talks about wanting a quiet life; after the friendship quest he starts
    the Bruspetti quest.
  - Early on he mentions his break-up and answers typed questions about Lighthalzen,
    Bruspetti and Freya's Spring, advancing the quest log.
  - Presenting Bruspetti's Diary takes it and opens an interrogation menu; only the right line
    of questioning advances the quest.
  - Reading the diary and pressing him about Freya's Spring moves him toward a confession, and
    bringing a Knife breaks him: he confesses his past and finally takes the Knife.
  - Once the quest is past him he only voices his regret.

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
      %{map: "ra_in01", x: 235, y: 194, dir: 5, sprite: 931, name: "Katinshuell", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @knife 1201
  @diary_of_blue 7571

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rach_vice, 0) > 21 -> regret(ctx)
      get_char_var(ctx, :rach_vice, 0) == 21 and count_item(ctx, @knife) > 0 -> give_up(ctx)
      get_char_var(ctx, :rach_vice, 0) == 21 -> bear_guilt(ctx)
      get_char_var(ctx, :rach_vice, 0) == 20 and count_item(ctx, @knife) > 0 -> confess(ctx)
      get_char_var(ctx, :rach_vice, 0) == 21 -> haunted(ctx)
      get_char_var(ctx, :rach_vice, 0) == 20 and count_item(ctx, @knife) > 0 -> crack(ctx)
      get_char_var(ctx, :rach_vice, 0) in [19, 20] -> resist(ctx)
      get_char_var(ctx, :rach_vice, 0) == 18 -> read_diary(ctx)
      get_char_var(ctx, :rach_vice, 0) == 17 -> outburst(ctx)
      get_char_var(ctx, :rach_vice, 0) == 16 -> interrogate(ctx)
      diary_ready?(ctx) -> show_diary(ctx)
      get_char_var(ctx, :rach_vice, 0) in [10, 11] -> answer_question(ctx)
      get_char_var(ctx, :rach_vice, 0) == 4 -> leave_alone(ctx)
      get_char_var(ctx, :rach_vice, 0) == 3 -> break_up(ctx)
      get_char_var(ctx, :rach_vice, 0) == 2 -> haunting_thoughts(ctx)
      get_char_var(ctx, :rach_vice, 0) == 1 -> haunting_thoughts_run_on(ctx)
      get_char_var(ctx, :rach_vice, 0) == 0 -> want_peace(ctx)
      true -> karma(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp diary_ready?(ctx) do
    get_char_var(ctx, :rach_vice, 0) == 15 and Rathena.truthy?(count_item(ctx, @diary_of_blue))
  end

  defp player(ctx), do: mes(ctx, "[#{char_name(ctx, 0)}]")

  defp player_silence(ctx) do
    ctx
    |> player()
    |> mes("......")
    |> mes(".........")
    |> next()
  end

  defp regret(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("If I had only turned")
    |> mes("myself in... Maybe if I had")
    |> mes("made an effort to pay for")
    |> mes("my crime, me and Bruspetti")
    |> mes("could have had a chance...")
    |> close()
  end

  defp give_up(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Please... Please just")
    |> mes("leave me alone. I've lost")
    |> mes("the woman I love because")
    |> mes("of something stupid I did")
    |> mes("in the past. If you want to")
    |> mes("turn me in, go ahead...")
    |> delitem(@knife, 1)
    |> set_char_var(:rach_vice, 22)
    |> changequest(8121, 8122)
    |> close()
  end

  defp bear_guilt(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("I suppose it's my")
    |> mes("fate to bear this guilt.")
    |> mes("It's already destroyed my")
    |> mes("best chance of ever being")
    |> mes("truly happy. Bruspetti...")
    |> close()
  end

  defp confess(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("I suppose there's")
    |> mes("no reason to hide")
    |> mes("anything anymore...")
    |> mes("You've probably figured")
    |> mes("the important stuff by now...")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("I used to work as one")
    |> mes("of the security guards in")
    |> mes("Lighthalzen. We basically")
    |> mes("watched the border between")
    |> mes("the rich area and the slums.")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("I actually was ordered")
    |> mes("to kill someone that was")
    |> mes("repeatedly moving between")
    |> mes("the slums and the rich area.")
    |> mes("He was a wealthy kid...")
    |> mes("Didn't really deserve it.")
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("I was paid a lot of money")
    |> mes("to do it. At first, I thought")
    |> mes("I was just doing my job. You")
    |> mes("know, I mean, the law was on")
    |> mes("my side. But the boy's blood")
    |> mes("wouldn't wash off my hands...")
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("I was scared to kill him,")
    |> mes("but once I did it, the guilt")
    |> mes("and the torment has been")
    |> mes("unbearable! I haven't been")
    |> mes("able to sleep... That's why")
    |> mes("I had to leave Lighthalzen.")
    |> set_char_var(:rach_vice, 21)
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("Bruspetti shocked me when")
    |> mes("she had learned about what")
    |> mes("I did back then. My one true")
    |> mes("love... She couldn't bear the")
    |> mes("truth. When she heard it from")
    |> mes("my own lips, she went mad...")
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("I couldn't stop her...")
    |> mes("I struggled, and tried to")
    |> mes("save her, but she managed")
    |> mes("to drown herself in Freya's")
    |> mes("Spring. She's gone from my")
    |> mes("life. Just like that. Forever.")
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("I came here after")
    |> mes("killing a man to start")
    |> mes("a new life, maybe get")
    |> mes("a clean slate, but I end up")
    |> mes("indirectly killing the woman")
    |> mes("I love. Why God?! Why?!")
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("Are you happy now?")
    |> mes("Are you happy now that?")
    |> mes("I've told you the truth?")
    |> mes("Doesn't that make me and")
    |> mes("you feel so much better?!")
    |> next()
    |> player_silence()
    |> mes("[Katinshuell]")
    |> mes("...............................")
    |> mes("God! My life sucks!")
    |> close()
  end

  defp haunted(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("^333333*Pant pant*^000000")
    |> mes("After all this")
    |> mes("time... I thought")
    |> mes("I could run away...")
    |> mes("But the voices still")
    |> mes("h-haunt me... Ha ha ha...")
    |> close()
  end

  defp crack(ctx) do
    ctx
    |> pressed_about_spring()
    |> next()
    |> player()
    |> mes("How can you say that?!")
    |> mes("I just read in Bruspetti's")
    |> mes("diary that she learned")
    |> mes("something horrible about")
    |> mes("you, and it involved a")
    |> mes("Knife... just like this one.")
    |> next()
    |> mes("[Katinshuell]")
    |> mes(".........!")
    |> mes(".............")
    |> mes("NOoo! I'm sorry, it's")
    |> mes("my fault! I was desperate!")
    |> mes("You don't understand how")
    |> mes("I used to live, you d-don't--!")
    |> set_char_var(:rach_vice, 21)
    |> next()
    |> player()
    |> mes("Huh...?")
    |> mes("Mr. Katinshuell?")
    |> close()
  end

  defp resist(ctx) do
    ctx
    |> pressed_about_spring()
    |> set_char_var(:rach_vice, 20)
    |> changequest(8120, 8121)
    |> next()
    |> player()
    |> mes("(^333333He's still resisting")
    |> mes("me... How can I get")
    |> mes("him to reveal the truth?^000000)")
    |> close()
  end

  defp pressed_about_spring(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("I...")
    |> mes("I don't deserve this!")
    |> mes("Why do you keep hounding")
    |> mes("me with these questions?")
    |> next()
    |> player()
    |> mes("Did... Did something")
    |> mes("happen when Bruspetti")
    |> mes("confronted you at Freya's")
    |> mes("Spring? What did exactly")
    |> mes("did she learn about")
    |> mes("you in Lighthalzen?")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("I... I don't have")
    |> mes("to tell you anything!")
  end

  defp read_diary(ctx) do
    ctx
    |> player()
    |> mes("Let's see...")
    |> mes("Oh this entry looks")
    |> mes("interesting. It's all")
    |> mes("about you, Katinshuell.")
    |> next()
    |> mes("- Date: OOXX -")
    |> mes("I'm so in love with him,")
    |> mes("but he always changes the")
    |> mes("subject whenever I ask him")
    |> mes("personal questions about his")
    |> mes("past. Could it be that he's")
    |> mes("hiding something from me?")
    |> next()
    |> mes("- Date: OOXX -")
    |> mes("Is it another woman?")
    |> mes("I can't help but feel")
    |> mes("jealous! I need to know.")
    |> mes("That's why I've decided to")
    |> mes("go to Lighthalzen and see")
    |> mes("what I can find out.")
    |> next()
    |> mes("- Date: OOXO -")
    |> mes("Dear Diary,")
    |> mes("Today I just learned")
    |> mes("the horrible truth... I need")
    |> mes("to make him confess it to")
    |> mes("me. I hope we can still be")
    |> mes("together after all of this...")
    |> next()
    |> mes("- Date: OOXO -")
    |> mes("But I don't know if")
    |> mes("I can live with this!")
    |> mes("The man I love... It's")
    |> mes("unthinkable that he'd")
    |> mes("use a Knife t-to... I just")
    |> mes("want to throw up.")
    |> next()
    |> mes("- Date: OOXO -")
    |> mes("I'm planning to meet him")
    |> mes("tomorrow at Freya's Spring.")
    |> mes("I can't help but look at him")
    |> mes("differently now, but still...")
    |> mes("He's the man I truly love.")
    |> next()
    |> mes("- Date: OOXO -")
    |> mes("I hope that I have")
    |> mes("good news the next")
    |> mes("time I write in this diary...")
    |> mes("Well, here's hoping.")
    |> next()
    |> player()
    |> mes("Well, that was")
    |> mes("the very last page...")
    |> mes("What happened when")
    |> mes("Bruspetti confronted")
    |> mes("you at Freya's Spring?")
    |> set_char_var(:rach_vice, 19)
    |> next()
    |> mes("[Katinshuell]")
    |> mes(".........")
    |> mes("I... I...")
    |> mes(".........")
    |> close()
  end

  defp outburst(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Damn it! I don't want to")
    |> mes("think about her anymore!")
    |> mes("Get away from me, and take")
    |> mes("Bruspetti's diary with you!")
    |> next()
    |> player()
    |> mes("What?! No way, not after")
    |> mes("that little outburst about")
    |> mes("killing or not killing Bruspetti!")
    |> mes("Fine, if you're not going to")
    |> mes("talk, then I'm going to flip")
    |> mes("through this diary for answers.")
    |> set_char_var(:rach_vice, 18)
    |> close()
  end

  defp interrogate(ctx) do
    {ctx, topic} =
      ctx
      |> mes("[Katinshuell]")
      |> mes("Ha ha ha...")
      |> mes("Is this some sort")
      |> mes("of interrogation?")
      |> mes("I-I've done nothing")
      |> mes("wrong! Go ahead,")
      |> mes("ask me anything!")
      |> next()
      |> player()
      |> mes("Alright then, why")
      |> mes("don't you explain this?")
      |> next()
      |> select(["Mr. Shendar's House", "Lighthalzen", "Freya's Spring", "Bruspetti"])

    case topic do
      1 -> ask_about_shendar(ctx)
      2 -> ask_about_lighthalzen(ctx)
      3 -> ask_about_spring(ctx)
      4 -> ask_about_bruspetti(ctx)
      _ -> ctx
    end
  end

  defp ask_about_shendar(ctx) do
    ctx
    |> player()
    |> mes("Mr. Shendar, Bruspetti's")
    |> mes("father, says that someone")
    |> mes("has been sneaking into his")
    |> mes("house for some reason.")
    |> mes("Now, why would you do that?")
    |> next()
    |> player()
    |> mes("You recognized")
    |> mes("Bruspetti's diary")
    |> mes("pretty quickly...")
    |> mes("And you did mention")
    |> mes("you were looking for it.")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("Hmpf! S-stop")
    |> mes("talking crazy talk!")
    |> mes("I don't know what")
    |> mes("you're talking about!")
    |> close()
  end

  defp ask_about_lighthalzen(ctx) do
    {ctx, topic} =
      ctx
      |> player()
      |> mes("You know, I found out")
      |> mes("that Bruspetti was planning")
      |> mes("on going to Lighthalzen.")
      |> mes("It seems that she needed")
      |> mes("to learn something really")
      |> mes("important over there...")
      |> next()
      |> mes("[Katinshuell]")
      |> mes("No...!")
      |> mes("She couldn't have...!")
      |> next()
      |> player()
      |> mes("Alright. It's no use")
      |> mes("pretending that you don't")
      |> mes("know her. You were her")
      |> mes("boyfriend, weren't you?")
      |> mes("What would she be trying")
      |> mes("to find in Lighthalzen?")
      |> next()
      |> mes("[Katinshuell]")
      |> mes("No! No no no!")
      |> mes("Shut up! Shut up!")
      |> mes("Please! Just leave")
      |> mes("me alone! Get away")
      |> mes("from me right now!")
      |> next()
      |> select(["Mr. Shendar's House", "Freya's Spring", "Recent Break-up"])

    case topic do
      1 -> accuse_of_sneaking(ctx)
      2 -> accuse_of_spring_visit(ctx)
      3 -> ask_about_break_up(ctx)
      _ -> ctx
    end
  end

  defp ask_about_break_up(ctx) do
    {ctx, topic} =
      ctx
      |> player()
      |> mes("Wait a second! Your break-up")
      |> mes("and Bruspetti's sudden need")
      |> mes("to investigate something in")
      |> mes("Lighthalzen... They're related")
      |> mes("somehow, aren't they?")
      |> next()
      |> mes("[Katinshuell]")
      |> mes("......")
      |> mes(".........")
      |> mes("No! It's not true!")
      |> next()
      |> player()
      |> next()
      |> select(["Mr. Shendar's house", "Freya's Spring"])

    case topic do
      1 -> accuse_of_sneaking(ctx)
      2 -> accuse_of_murder(ctx)
      _ -> ctx
    end
  end

  defp accuse_of_sneaking(ctx) do
    ctx
    |> player()
    |> mes("So while she was away")
    |> mes("in Lighthalzen, you snuck")
    |> mes("in Mr. Shendar's house and--")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("Y-yes! Yes, that's right!")
    |> mes("It's because I was so worried")
    |> mes("about her! I had no idea that")
    |> mes("she went all the way over to")
    |> mes("Lighthalzen! Ha ha! Ha ha!")
    |> next()
    |> backfired()
  end

  defp accuse_of_spring_visit(ctx) do
    ctx
    |> player()
    |> mes("So while she was away")
    |> mes("in Lighthalzen, you went")
    |> mes("to Freya's Spring, all")
    |> mes("by yourself, didn't you?!")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("......")
    |> mes(".........")
    |> mes("Um? ...Yes.")
    |> next()
    |> backfired()
  end

  defp backfired(ctx) do
    ctx
    |> player()
    |> mes("...............................")
    |> mes("(^333333Nuts! I think that")
    |> mes("backfired, so I'm going")
    |> mes("to have to try this again.)^000000")
    |> close()
  end

  defp accuse_of_murder(ctx) do
    ctx
    |> player()
    |> mes("Hmm... Why are you")
    |> mes("always hanging out at")
    |> mes("Freya's Spring alone?")
    |> mes("And why has Bruspetti")
    |> mes("not returned home yet?")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("...Will you stop talking nonsense?")
    |> mes("What is your evidence to convict me with the crime?")
    |> mes("I don't wish to hear you any longer.")
    |> next()
    |> player()
    |> mes("Even after you killed Bruspetti,")
    |> mes("you became worried about another possibility.")
    |> mes("So you were plotting to get rid of the possibility, too.")
    |> next()
    |> set_char_var(:rach_vice, 17)
    |> mes("[Katinshuell]")
    |> mes("No! Stop it! Stop!")
    |> mes("Are you implying that")
    |> mes("I killed her?! I didn't!")
    |> mes("Quit this nonsense")
    |> mes("before I get really angry!")
    |> close()
  end

  defp ask_about_spring(ctx) do
    ctx
    |> player()
    |> mes("Freya's Spring.")
    |> mes("Why are you always")
    |> mes("hanging around there")
    |> mes("by yourself, eh?")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("...............................")
    |> mes("It's because I really")
    |> mes("miss my ex-girlfriend.")
    |> next()
    |> player()
    |> mes("Oh. Right.")
    |> mes("That's a pretty")
    |> mes("good reason.")
    |> close()
  end

  defp ask_about_bruspetti(ctx) do
    ctx
    |> player()
    |> mes("If Bruspetti is not")
    |> mes("your girlfriend, then...")
    |> mes("Who is?! Answer that!")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("...............................")
    |> mes("Fine, fine. You win.")
    |> mes("She was my ex-girlfriend.")
    |> mes("I just don't like talking")
    |> mes("about Bruspetti, that's all.")
    |> mes("Now will you leave me alone?")
    |> next()
    |> player()
    |> mes("(^333333Nuts! He wasn't supposed")
    |> mes("to cave in like that! I need")
    |> mes("to question him again until")
    |> mes("my gut feeling is satisfied!^000000)")
    |> close()
  end

  defp show_diary(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Oh, it's you again.")
    |> mes("What do you want now?")
    |> mes("I just told you that I'm not")
    |> mes("in the mood for talking with")
    |> mes("anyone. I'm still coping with")
    |> mes("breaking up with my girlfriend.")
    |> next()
    |> player()
    |> mes("Katinshuell... I get the")
    |> mes("feeling that you're hiding")
    |> mes("something. By any chance,")
    |> mes("was Bruspetti your girlfriend?")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("Huh?! Er, wh-wh-what?")
    |> mes("What makes you think that?")
    |> mes("That's none of your business!")
    |> mes("Besides, don't you think that")
    |> mes("a girl like her is too good")
    |> mes("for some guy like me?!")
    |> next()
    |> player()
    |> mes("I don't have any real")
    |> mes("reason to suspect you of")
    |> mes("anything, but my gut feeling")
    |> mes("and the way you reacted isn't")
    |> mes("very reassuring. Well, I guess")
    |> mes("I can flip through this book...")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("Hey! Hey that's...")
    |> mes("That's Bruspetti's diary!")
    |> mes("I-I've been looking for-- um...")
    |> next()
    |> player()
    |> mes("Hey! How would you")
    |> mes("know about that?!")
    |> mes("Tell me the truth!")
    |> mes("Actually, you know what?")
    |> mes("Why don't we look at the")
    |> mes("truth together? How's that?")
    |> next()
    |> mes("^3355FFYou nonchalantly")
    |> mes("toss the diary at")
    |> mes("Katinshuell's feet,")
    |> mes("and it opens to one of")
    |> mes("the pages in the middle.^000000")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("......!")
    |> delitem(@diary_of_blue, 1)
    |> set_char_var(:rach_vice, 16)
    |> changequest(8119, 8120)
    |> close()
  end

  defp answer_question(ctx) do
    {ctx, question} =
      ctx
      |> mes("[Katinshuell]")
      |> mes("Argh! I'm so depressed.")
      |> mes("Honestly, I just want to")
      |> mes("be left by myself for a really")
      |> mes("long time. What the heck do you")
      |> mes("want to ask me about, anyway?")
      |> next()
      |> input(:string)

    case question do
      "Lighthalzen" -> ctx |> about_lighthalzen() |> quest_noted()
      "Bruspetti" -> ctx |> about_bruspetti() |> quest_noted()
      "Freya's Spring" -> ctx |> about_spring() |> quest_noted()
      _ -> not_understood(ctx, question)
    end
  end

  defp about_lighthalzen(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Lighthalzen...?")
    |> mes("a city in the Schwarzwald")
    |> mes("Republic. That, and it's")
    |> mes("a tough place to live in.")
    |> mes("That's all I really know...")
    |> next()
  end

  defp about_bruspetti(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("...It's been a while")
    |> mes("since I heard that name.")
    |> mes("Bruspetti... She's pretty")
    |> mes("popular around this town...")
    |> mes("Everyone liked her. Is that")
    |> mes("all you wanted to know?")
    |> next()
  end

  defp about_spring(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Freya's Spring...")
    |> mes("That's just a park")
    |> mes("where old people and")
    |> mes("couples sort of hang out.")
    |> mes("I don't like going there,")
    |> mes("though. You shouldn't, either.")
    |> next()
  end

  defp not_understood(ctx, question) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("...#{question}?")
    |> mes("What? I don't understand you...")
    |> close()
  end

  defp quest_noted(ctx) do
    ctx =
      if get_char_var(ctx, :rach_vice, 0) == 10 do
        ctx
        |> set_char_var(:rach_vice, 11)
        |> changequest(8114, 8115)
      else
        ctx
      end

    ctx
    |> mes("[Katinshuell]")
    |> mes("You happy, now?")
    |> mes("Quit trying to pry into")
    |> mes("my personal business,")
    |> mes("and just enjoy touring this")
    |> mes("little town. That's what")
    |> mes("you came to do, right?")
    |> close()
  end

  defp leave_alone(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Uh... ")
    |> mes("I just told you that I broke")
    |> mes("up with my girlfriend. You")
    |> mes("know, I kinda sorta wanna")
    |> mes("be left alone. Go away...")
    |> close()
  end

  defp break_up(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Eh? Oh, it's one of you")
    |> mes("guys, those do-gooder")
    |> mes("adventurers. You must not")
    |> mes("have anything else to do...")
    |> mes("Otherwise, why talk to me?")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("Geez... I know you guys go")
    |> mes("around solving problems,")
    |> mes("but this is one thing you")
    |> mes("can't handle. Me and my")
    |> mes("girlfriend are history now.")
    |> mes("It's over between us.")
    |> set_char_var(:rach_vice, 4)
    |> changequest(8107, 8108)
    |> close()
  end

  defp quiet_life(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("You're an adventurer,")
    |> mes("so I don't think you'd ")
    |> mes("understand how difficult")
    |> mes("it is to live a quiet, peaceful")
    |> mes("life. When you've lived through")
    |> mes("certain things, it's tough.")
    |> next()
    |> mes("[Katinshuell]")
  end

  defp haunting_thoughts(ctx) do
    ctx
    |> quiet_life()
    |> mes("When you're busy, you're")
    |> mes("distracted. But even if I'm")
    |> mes("left all alone, these thoughts")
    |> mes("of mine never cease to haunt me...")
    |> close()
  end

  defp haunting_thoughts_run_on(ctx) do
    ctx
    |> quiet_life()
    |> mes("When you're busy, you're")
    |> mes("distracted. But even if I'm")
    |> mes("left all alone, these thoughts of mine never cease to haunt me...")
    |> close()
  end

  defp want_peace(ctx) do
    ctx =
      ctx
      |> quiet_life()
      |> mes("I don't need any more")
      |> mes("excitement in my life.")
      |> mes("I just want to live quietly,")
      |> mes("away from other people,")
      |> mes("and to be left all alone for")
      |> mes("some semblance of peace.")

    if get_char_var(ctx, :friendship, 0) > 10 do
      ctx |> set_char_var(:rach_vice, 1) |> close()
    else
      close(ctx)
    end
  end

  defp karma(ctx) do
    ctx
    |> mes("[Katinshuell]")
    |> mes("Do you believe in karma?")
    |> mes("I do... No matter what you")
    |> mes("do, even if you don't get")
    |> mes("caught, somehow it just")
    |> mes("catches up to you.")
    |> next()
    |> mes("[Katinshuell]")
    |> mes("Have you ever felt")
    |> mes("guilty about something,")
    |> mes("but hid from the truth?")
    |> mes("Let me tell you that it must")
    |> mes("be a painful experience. It's")
    |> mes("better to confess when you can.")
    |> close()
  end
end
