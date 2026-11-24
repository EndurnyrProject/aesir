defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Klitzer do
  @moduledoc """
  Klitzer is the Einbech miner in love with Calla in the Lovers Quest.

  ## Behavior

  - Starts the quest when the adventurer carries Calla's scent from Einbroch.
  - Takes Calla's Violin in exchange for a full HP massage and base EXP, then asks for a
    Flower to be delivered to her.
  - Asks for the adventurer's name after the Flower is delivered.
  - Learns of Lady Satra's tea invitation and trades a random rare ore for a Tuxedo.

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
        x: 200,
        y: 101,
        dir: 5,
        sprite: 854,
        name: "Klitzer",
        scope: :shared,
        unique_name: "Klitzer#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @tuxedo 7170
  @violin 1901
  @ores [7289, 7290, 7291, 7293, 7294, 7295, 7296]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :EIN_LOVERQ, 0)

    if progress == 15 and count_item(ctx, @tuxedo) > 0 do
      offer_tuxedo(ctx)
    else
      ctx |> talk(progress) |> close()
    end
  end

  defp talk(ctx, 16) do
    ctx
    |> mes("[Klitzer]")
    |> mes("Look out, world!")
    |> mes("I'm gonna become")
    |> mes("worthy of Calla's love!")
    |> mes("Someday, maybe even her")
    |> mes("parents will approve me!")
  end

  defp talk(ctx, 15) do
    ctx
    |> outfit_panic()
    |> mes("[Klitzer]")
    |> mes("What am I gonna do?!")
    |> mes("Okay, nothing too flashy")
    |> mes("or revealing. Can't let her")
    |> mes("think I'm wild, immature or")
    |> mes("unpredictable. Should I")
    |> mes("wear suspenders or a belt?!")
  end

  defp talk(ctx, 14) do
    ctx
    |> outfit_panic()
    |> mes("[Klitzer]")
    |> mes("Think, Klitzer, think!")
    |> mes("Okay, no fun colors.")
    |> mes("I don't want her to")
    |> mes("think I'm not serious")
    |> mes("about Calla. Stripes")
    |> mes("might be bad too...")
  end

  defp talk(ctx, 13) do
    ctx
    |> mes("[Klitzer]")
    |> mes("Eh...?")
    |> mes("What did you just say?")
    |> mes("You did something for")
    |> mes("the Kapellthaines?")
    |> next()
    |> mes("[Klitzer]")
    |> mes("What...?")
    |> mes("Did you just say")
    |> mes("that Calla's mother")
    |> mes("wants me to have tea")
    |> mes("with her? Holy moley...!")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Okay, okay.")
    |> mes("I-I I'll need something")
    |> mes("nice to wear, right? Oh.")
    |> mes("Wow. This is so sudden!")
    |> mes("W-what should I do?")
    |> next()
    |> set_char_var(:EIN_LOVERQ, 14)
    |> changequest(8085, 8086)
    |> mes("[Klitzer]")
    |> mes("This monkey suit")
    |> mes("that I've got on just")
    |> mes("won't do! Arrrgh! But I've")
    |> mes("already outgrown all of my")
    |> mes("nice clothes already. Boy,")
    |> mes("am I in a pickle...")
  end

  defp talk(ctx, progress) when progress > 6 do
    ctx
    |> mes("[Klitzer]")
    |> mes("*Sigh...*")
    |> mes("What can I do to")
    |> mes("get Calla's parents")
    |> mes("to accept me as her")
    |> mes("boyfriend? I can't")
    |> mes("think of anything...")
  end

  defp talk(ctx, 6), do: ask_name(ctx)

  defp talk(ctx, 5) do
    ctx
    |> mes("[Klitzer]")
    |> mes("Have you left to")
    |> mes("see Calla for me yet?")
    |> mes("I'm sorry if I sound")
    |> mes("pretty demanding...")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Anyway, please")
    |> mes("remember to bring")
    |> mes("Calla ^FF00001 Flower^000000 for me.")
    |> mes("It doesn't need to be")
    |> mes("fancy, an ordinary one")
    |> mes("should be just fine.")
  end

  defp talk(ctx, 3) do
    if count_item(ctx, @violin) == 1, do: receive_violin(ctx), else: lament(ctx)
  end

  defp talk(ctx, 2) do
    ctx
    |> mes("[Klitzer]")
    |> mes("^333333*Sigh*^000000")
    |> mes("I really appreciate your")
    |> mes("sympathy, but I'm merely")
    |> mes("a coward and a fool.")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Yeah...")
    |> mes("I'm a coward for doing")
    |> mes("nothing about my feelings")
    |> mes("and an idiot for falling in love with such a high class girl in")
    |> mes("the first place... Oh, Calla...")
  end

  defp talk(ctx, 1) do
    ctx
    |> mes("[Klitzer]")
    |> mes("That faintly sweet")
    |> mes("and pleasant scent...")
    |> mes("It's just like the fragrance")
    |> mes("they use in Calla's house.")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Ah, so you visited")
    |> mes("Calla in Einbroch?")
    |> mes("I miss her sooo much!")
    |> mes("Is she doing alright?")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Calla's so beautiful.")
    |> mes("And she's so lovely.")
    |> mes("Every time I close my")
    |> mes("eyes, I can still see")
    |> mes("her lovely smile.")
    |> next()
    |> mes("[Klitzer]")
    |> mes("I'm sorry if I sound")
    |> mes("silly, but I can't help")
    |> mes("it. I know I'm acting like")
    |> mes("a complete idiot. But I'd")
    |> mes("give anything to see her...")
    |> next()
    |> set_char_var(:EIN_LOVERQ, 2)
    |> setquest(8076)
    |> mes("[Klitzer]")
    |> mes("Just...")
    |> mes("Just don't listen")
    |> mes("to anything I say.")
    |> mes("I'm just a poor fool")
    |> mes("in love with the wrong")
    |> mes("person. That has to be it...")
  end

  defp talk(ctx, _progress), do: lament(ctx)

  defp offer_tuxedo(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Klitzer]")
      |> mes("Waaaah!")
      |> mes("What should I wear?!")
      |> mes("I can't for the life of me")
      |> mes("figure this out! Something,")
      |> mes("um, formal? I've never worn")
      |> mes("anything like that before!")
      |> next()
      |> mes("[Klitzer]")
      |> mes("Wait, #{char_name(ctx, 0)}.")
      |> mes("What's that you've got")
      |> mes("there? I've seen something")
      |> mes("like that before. It's called")
      |> mes("a Tuxedo, right? Something")
      |> mes("like that would be perfect!")
      |> next()
      |> select(["Give it to him.", "Ignore Him."])

    case choice do
      1 ->
        ctx |> accept_tuxedo() |> close()

      2 ->
        ctx
        |> mes("[Klitzer]")
        |> mes("But how can I get")
        |> mes("a Tuxedo? Ooh, I hope")
        |> mes("it doesn't cost too much")
        |> mes("zeny or I won't be able to")
        |> mes("get one of those soon...")
        |> close()

      _ ->
        ctx
    end
  end

  defp accept_tuxedo(ctx) do
    ctx
    |> mes("[Klitzer]")
    |> mes("I can have this?")
    |> mes("Oh, thank you so much!")
    |> mes("Finally, I have something")
    |> mes("nice enough to wear to meet")
    |> mes("Calla's mom! What a relief!")
    |> next()
    |> mes("[Klitzer]")
    |> mes("You've been helping me all")
    |> mes("this time and I haven't properly expressed my gratitude. I'm sorry")
    |> mes(
      "if I've been too absorbed in my own problems. I may be poor, but I need to repay you somehow..."
    )
    |> next()
    |> mes("[Klitzer]")
    |> mes("Wait...")
    |> mes("Why don't you have this")
    |> mes("ore? I don't know how")
    |> mes("valuable it is, but I know")
    |> mes("that it's pretty rare. It may")
    |> mes("even be useful to you later~")
    |> delitem(@tuxedo, 1)
    |> set_char_var(:EIN_LOVERQ, 16)
    |> changequest(8087, 8088)
    |> give_item(Enum.random(@ores), 1)
    |> next()
    |> mes("[Klitzer]")
    |> mes("#{char_name(ctx, 0)},")
    |> mes("you've really opened")
    |> mes("my eyes. From now on,")
    |> mes("I'll do my best to earn the")
    |> mes("approval of Calla's parents and")
    |> mes("become worthy of Calla's love.")
  end

  defp outfit_panic(ctx) do
    ctx
    |> mes("[Klitzer]")
    |> mes("Noooooo!")
    |> mes("I've got to find")
    |> mes("the perfect thing")
    |> mes("to wear or Calla's")
    |> mes("mother might ^FF0000hate^000000 me!")
    |> next()
  end

  defp ask_name(ctx) do
    {ctx, name} =
      ctx
      |> mes("[Klitzer]")
      |> mes("You've given her")
      |> mes("the flower? That's")
      |> mes("great! Thank you,")
      |> mes("thank you so mu--")
      |> next()
      |> mes("[Klitzer]")
      |> mes("...Oh!")
      |> mes("Gosh! I was thinking so")
      |> mes("much about myself that")
      |> mes("I forgot to ask you for your")
      |> mes("name! I'm sorry for being")
      |> mes("so knuckle-headed...")
      |> next()
      |> mes("[Klitzer]")
      |> mes("So...")
      |> mes("What's your name?")
      |> next()
      |> input(:string)

    if name == char_name(ctx, 0) do
      ctx
      |> mes("[Klitzer]")
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("That's very nice. Thank you,")
      |> mes("I'm really grateful for your help. Although I can't see Calla in")
      |> mes("person, I can at least send")
      |> mes("my regards if you help me.")
      |> next()
      |> set_char_var(:EIN_LOVERQ, 7)
      |> changequest(8080, 8081)
      |> mes("[Klitzer]")
      |> mes("I feel so much")
      |> mes("better now. Oh!")
      |> mes("When you have the")
      |> mes("time, why don't you talk")
      |> mes("to my mother? She always")
      |> mes("likes meeting my friends.")
    else
      ctx
      |> mes("[Klitzer]")
      |> mes("Hm...?")
      |> mes("Oh, don't be")
      |> mes("so nervous~")
      |> mes("But would you please")
      |> mes("tell me your name again?")
      |> mes("I couldn't hear you...")
    end
  end

  defp receive_violin(ctx) do
    ctx
    |> mes("[Klitzer]")
    |> mes("What brings you here?")
    |> mes("Aren't you tired of hearing")
    |> mes("me moan and whine about")
    |> mes("lost love? ^333333*Siiiiigh...*^000000")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Hey, this violin...")
    |> mes("Calla used to play")
    |> mes("such beautiful music")
    |> mes("on this for me. Did")
    |> mes("she give this to you?")
    |> next()
    |> mes("[Klitzer]")
    |> mes("I see. Calla must have")
    |> mes("known that I'm all broken up")
    |> mes("right now. She's too good to")
    |> mes("to me. How can she consider")
    |> mes("my feelings before thinking")
    |> mes("about herself?")
    |> next()
    |> mes("[Klitzer]")
    |> mes("I know I'm being")
    |> mes("shameless, but I have")
    |> mes("a favor to ask. Adventurer,")
    |> mes("would you please send")
    |> mes("Calla a present for me?")
    |> next()
    |> mes("[Klitzer]")
    |> mes("All you need to do is")
    |> mes("just give her ^FF00001 Flower^000000.")
    |> mes("I don't have the zeny and")
    |> mes("I don't think I'm welcome")
    |> mes("at Kapellthaine Manor.")
    |> next()
    |> mes("[Klitzer]")
    |> mes("Here, in return, I'll")
    |> mes("give you this health")
    |> mes("massage. It's not a")
    |> mes("big deal, but when I'm")
    |> mes("done, your mind and body")
    |> mes("will be refreshed. Here goes!")
    |> next()
    |> mes("^3355FF*Knead Knead*")
    |> mes("*Rub Rub Rub Rub*")
    |> mes("*Press Press Press*")
    |> mes("*C-c-c-c-c-c-crack!*")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Oh--")
    |> mes("Hell yeah!")
    |> mes("That's the stuff!")
    |> percent_heal(hp: 100, sp: 0)
    |> delitem(@violin, 1)
    |> set_char_var(:EIN_LOVERQ, 5)
    |> changequest(8077, 8079)
    |> massage_exp()
    |> next()
    |> mes("[Klitzer]")
    |> mes("Would you please bring")
    |> mes("1 Flower to Calla for me?")
    |> mes("I'm sorry for troubling you... ")
  end

  defp massage_exp(ctx) do
    renewal? = Rathena.truthy?(checkre(ctx, 3))
    getexp(ctx, massage_exp_amount(renewal?, base_level(ctx)), 0)
  end

  defp massage_exp_amount(true, level) do
    cond do
      level < 41 -> 61
      level < 61 -> 600
      level < 81 -> 3000
      level < 99 -> 20_000
      true -> 30_000
    end
  end

  defp massage_exp_amount(false, level) do
    cond do
      level < 41 -> 610
      level < 61 -> 6000
      level < 81 -> 30_000
      true -> 200_000
    end
  end

  defp lament(ctx) do
    ctx
    |> mes("[Klitzer]")
    |> mes("Is there something")
    |> mes("that you really want")
    |> mes("in life, but it's just")
    |> mes("beyond your grasp?")
    |> next()
    |> mes("[Klitzer]")
    |> mes("I wish I were more")
    |> mes("like you adventurers.")
    |> mes("People like you never")
    |> mes("seem to give up, no matter")
    |> mes("what the obstacles may be.")
    |> mes("But I'm so helpless...")
    |> next()
    |> mes("[Klitzer]")
    |> mes("I can't even see")
    |> mes("the one person that")
    |> mes("I love. We've just so")
    |> mes("different that it's not")
    |> mes("even possible anymore...")
  end
end
