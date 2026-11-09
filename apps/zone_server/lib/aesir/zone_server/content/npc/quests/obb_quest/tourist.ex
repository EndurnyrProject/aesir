defmodule Aesir.ZoneServer.Content.Npc.Quests.ObbQuest.Tourist do
  @moduledoc """
  Pandger Mayer asks for food and introduces helpful adventurers to Jacob.

  ## Behavior

  - Asks lost adventurers to identify the town before requesting help.
  - Demands an exact, randomly chosen quantity of Meat and then twenty Well-baked Cookies.
  - Rewards the completed errands with a Cutter and an introduction to Jacob.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Celesta
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/obb_quest.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 43,
        y: 244,
        dir: 0,
        sprite: 99,
        name: "Tourist",
        scope: :shared,
        unique_name: "Tourist#thai"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("- Wait a moment! -")
      |> mes("- Currently you're carrying -")
      |> mes("- too many items with you. -")
      |> mes("- Please enlighten your weight -")
      |> mes("- and try again. -")
      |> close()
    else
      quest_dialogue(ctx)
    end
  end

  defp quest_dialogue(ctx) do
    case get_char_var(ctx, :thai_head, 0) do
      1 -> seek_forgiveness(ctx)
      2 -> ask_about_lutie(ctx)
      3 -> bring_meat(ctx)
      4 -> bring_cookies(ctx)
      5 -> receive_introduction(ctx)
      stage when stage > 5 -> farewell(ctx)
      _ -> lost_tourist(ctx)
    end
  end

  defp seek_forgiveness(ctx) do
    ctx = set_local(ctx, :th_rand, Enum.random(1..100))

    if get_local(ctx, :th_rand, 0) > 6 and get_local(ctx, :th_rand, 0) < 20 do
      ctx
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("You're that meanie...")
      |> next()
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("Aren't you...?")
      |> next()
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("Alright, alright, but you don't have to be mean.")
      |> set_char_var(:thai_head, 2)
      |> close()
    else
      ctx
      |> mes("[Tourist]")
      |> mes("...........")
      |> next()
      |> mes("[Tourist]")
      |> mes("I didn't think you were that")
      |> mes("mean. Scram, I ain't in the mood")
      |> mes("to talk to you.")
      |> close()
    end
  end

  defp ask_about_lutie(ctx) do
    {ctx, topic} =
      ctx
      |> mes("[Tourist]")
      |> mes("..........")
      |> next()
      |> select([
        "So do you have business in Lutie?",
        "You don't want to go to Lutie for a tour.",
        "What made you come over here?"
      ])

    case topic do
      1 ->
        ctx
        |> mes("[Tourist]")
        |> mes("Yes.")
        |> mes("Well, actually...")
        |> next()
        |> explain_cookie_search()

      2 ->
        ctx
        |> mes("[Tourist]")
        |> mes("...Oh really? Hmm...people said I")
        |> mes("could only get the well baked")
        |> mes("cookie in Lutie.")
        |> next()
        |> explain_cookie_search()

      3 ->
        ctx
        |> mes("[Tourist]")
        |> mes("I was told that I could only find")
        |> mes("the entrance to Lutie in")
        |> mes("Al De Baran...")
        |> next()
        |> mes("[Tourist]")
        |> mes("So I came here after searching")
        |> mes("for Al De Baran...almost")
        |> mes("killing myself when I passed the desert...*Sob*")
        |> close()

      _ ->
        ctx
    end
  end

  defp bring_meat(ctx) do
    if count_item(ctx, 517) == 0 do
      hungry_without_meat(ctx)
    else
      ctx = set_local(ctx, :th_rand, Enum.random(1..100))

      required_meat =
        cond do
          get_local(ctx, :th_rand, 0) > 0 and get_local(ctx, :th_rand, 0) < 10 -> 10
          get_local(ctx, :th_rand, 0) > 11 and get_local(ctx, :th_rand, 0) < 80 -> 20
          true -> 40
        end

      cond do
        count_item(ctx, 517) == required_meat ->
          ctx
          |> mes("[Tourist]")
          |> mes("Ah...thanks! Thank you so much!")
          |> delitem(517, required_meat)
          |> next()
          |> request_cookies()

        count_item(ctx, 517) < required_meat ->
          too_little_meat(ctx)

        true ->
          too_much_meat(ctx, required_meat)
      end
    end
  end

  defp bring_cookies(ctx) do
    if count_item(ctx, 538) > 19 do
      ctx
      |> mes("[Tourist]")
      |> mes("Ah~!! Thank you so much!!")
      |> mes("There really are many good")
      |> mes("people like you in this world.")
      |> next()
      |> set_char_var(:thai_head, 5)
      |> delitem(538, 20)
      |> mes("[Tourist]")
      |> mes("I appreciate what you've done for")
      |> mes("me...now I can see her smile with")
      |> mes("happiness.")
      |> next()
      |> mes("[Tourist]")
      |> mes("Hmm, there is still one problem")
      |> mes("left for me though...How do I")
      |> mes("get back home to Morocc??")
      |> mes("Well, if it can make my girl")
      |> mes("happy...")
      |> next()
      |> mes("[Tourist]")
      |> mes("...I'll get around to it.")
      |> mes("Sooner or later. Man,")
      |> mes("that desert's really big,")
      |> mes("you know?")
      |> close()
    else
      ctx
      |> mes("[Tourist]")
      |> mes("I see...I can understand that you")
      |> mes("can't help me. It's alright...")
      |> mes("It's not like I have the right")
      |> mes("to demand anything of you...")
      |> mes("But...")
      |> close()
    end
  end

  defp receive_introduction(ctx) do
    ctx =
      ctx
      |> mes("[Tourist]")
      |> mes("Thank you so much!")
      |> next()
      |> mes("[Tourist]")
      |> mes("Hmm...I wanna pay you back...")
      |> mes("And you're an adventurer...")
      |> mes("But I don't got any like...")
      |> mes("magic armor or those")
      |> mes("cards you guys are")
      |> mes("always playing with...")
      |> next()
      |> mes("[Tourist]")
      |> mes("Hmmm...")
      |> mes("....I got it!")
      |> mes("Sooner or later, you")
      |> mes("wanna visit some sort")
      |> mes("of wise man or...")
      |> mes("...something, right?")
      |> next()
      |> mes("[Tourist]")
      |> mes("Visit my pal ^649664Jacob^000000 in")
      |> mes("Morocc. Tell him that I")
      |> mes("introduced you. He knows")
      |> mes("about a wise man...")
      |> mes("Though, he isn't one")
      |> mes("himself...")
      |> next()
      |> mes("[Tourist]")
      |> mes("Ah, sorry, I haven't even told")
      |> mes("you my name. My name is...")
      |> mes("^0000FFPandger Mayer^000000.")
      |> next()
      |> mes("[Tourist]")
      |> mes("So yeah, tell my pal Jacob")
      |> mes("that Pandger Mayer introduced you.")
      |> next()
      |> mes("[Tourist]")
      |> mes("So...you tell 'em:")
      |> mes("^0000FFPandger Mayer introduced you^000000")
      |> mes("Exactly like that~")
      |> mes("^0000FFPandger Mayer introduced you^000000")
      |> mes("^FF0000Don't forget it~^000000")
      |> next()
      |> mes("[Tourist]")
      |> mes("Sorry I can't pay you back with")
      |> mes("more than this, though. Kinda")
      |> mes("stinks, huh?")
      |> next()
      |> mes("[Tourist]")
      |> mes("Here, take this as an extra")
      |> mes("token of my gratitute.")
      |> mes("This doohickey has been")
      |> mes("pretty handy in sticky")
      |> mes("situations...")
      |> next()
      |> mes("[Tourist]")
      |> mes("Hopefully, it'll be useful.")

    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 500 do
      ctx
      |> mes("Umm...it seems you're carrying too much stuff with you.")
      |> mes("Doncha want me to help you?")
      |> close()
    else
      ctx
      |> set_char_var(:thai_head, 6)
      |> give_item(1205, 1)
      |> next()
      |> mes("[Tourist]")
      |> mes("Heh...once gain, thanks for")
      |> mes("the help. Take care, guy.")
      |> close()
    end
  end

  defp farewell(ctx) do
    response = Enum.random(1..3)

    case response do
      1 ->
        ctx
        |> mes("[Tourist]")
        |> mes("Hey, thanks a bunch for your")
        |> mes("help. Anyways...now I remember")
        |> mes("I gotta go back through the")
        |> mes("desert again...*Sigh*")
        |> mes("Yeah, I better get back...")
        |> next()
        |> mes("[Tourist]")
        |> mes("...no matter how hard it is.")
        |> mes("But...yeah. It's gonna be pretty")
        |> mes("hard. Crossing the desert...")
        |> mes("alone. By myself...crud.")
        |> close()

      2 ->
        ctx
        |> mes("[Tourist]")
        |> mes("Hey, thanks a bunch for your")
        |> mes("help....I ain't sure if I")
        |> mes("can make it back to Morocc")
        |> mes("in one piece...")
        |> next()
        |> mes("[Tourist]")
        |> mes("But I better go back")
        |> mes("to my girlfriend. That's")
        |> mes("the point of me coming")
        |> mes("here in the first place,")
        |> mes("anyway.")
        |> close()

      3 ->
        ctx
        |> mes("[Tourist]")
        |> mes("Hey, thanks a bunch for your")
        |> mes("help. Man...Morocc is a long")
        |> mes("way off, isn't it? Aw nuts...")
        |> mes("I guess if I was crazy")
        |> mes("enough to come here because")
        |> mes("of my girlfriend...")
        |> next()
        |> mes("[Tourist]")
        |> mes("I'm crazy enough to walk all")
        |> mes("way back to Morocc...")
        |> mes("...")
        |> mes("...unless...")
        |> mes("You'll gimme a piggy-back ride?")
        |> next()
        |> mes("[Tourist]")
        |> mes("...kidding. I'm not that")
        |> mes("big of a jerk, I guess.")
        |> mes("Try not to look so")
        |> mes("surprised!")
        |> close()

      _ ->
        ctx
    end
  end

  defp lost_tourist(ctx) do
    if job_level(ctx) < 36 do
      ctx
      |> mes("[Tourist]")
      |> mes("Where am I...?")
      |> mes("...Who am I?")
      |> next()
      |> mes("[Tourist]")
      |> mes(".........")
      |> next()
      |> mes("[Tourist]")
      |> mes(".....")
      |> next()
      |> mes("[Tourist]")
      |> mes(".........")
      |> next()
      |> mes("[Tourist]")
      |> mes("Mahahahahahaha!!")
      |> next()
      |> mes("[Tourist]")
      |> mes("*Drools*...I love chocolate!")
      |> next()
      |> mes("[Tourist]")
      |> mes("Wait...")
      |> mes("I have a girlfriend...")
      |> mes("and...and...")
      |> mes("cookies...?")
      |> mes("I feel sooo lost...")
      |> next()
      |> mes("^3355FFWe don't talk to crazy people~^000000")
      |> close()
    else
      {ctx, town} =
        ctx
        |> mes("[Tourist]")
        |> mes("Where am I?")
        |> mes("*Sob*...I guess I got lost...")
        |> mes("Hey, where is this!?")
        |> next()
        |> select(["Ignore him.", "This is Alberta.", "This is Al De Baran."])

      case town do
        1 ->
          ctx |> mes("[Tourist]") |> mes("..........") |> close()

        2 ->
          ctx
          |> mes("[Tourist]")
          |> mes("Ah...I see. So this is")
          |> mes("Alberta...crud. I'm")
          |> mes("supposed to go to ^0000FFLutie^000000...")
          |> next()
          |> mes("[Tourist]")
          |> mes("Hey, thanks for letting me know.")
          |> mes("Now at least I know where I am.")
          |> mes("Geez...they got boats here")
          |> mes("that go everywhere, yeah?")
          |> next()
          |> mes("[Tourist]")
          |> mes("Oh right, everywhere...but Lutie.")
          |> mes("Man, this stinks.")
          |> close()
          |> set_char_var(:thai_head, 2)

        3 ->
          {ctx, tower} =
            ctx
            |> mes("[Tourist]")
            |> mes("Oh...oh right!")
            |> mes("Yeah, Al De Baran...")
            |> mes("Guess I'm not lost")
            |> mes("after all.")
            |> next()
            |> mes("[Tourist]")
            |> mes("I was told that I can see a ^FF0000Clock Tower^000000 in Al De Baran.")
            |> mes("Can you tell me where I can find the ^FF0000Clock Tower^000000?")
            |> next()
            |> select([
              "It's in the center of the town.",
              "Eh, I think I gave you the wrong town name."
            ])

          if tower == 1 do
            ctx
            |> mes("[Tourist]")
            |> mes("..............")
            |> mes("You know, I'm beginning")
            |> mes("to feel like...")
            |> mes("you're pullin' my")
            |> mes("chain...")
            |> set_char_var(:thai_head, 1)
            |> close()
          else
            ctx
            |> mes("[Tourist]")
            |> mes("Hah~!...I knew it! Well, it's")
            |> mes("pretty hard to admit when")
            |> mes("you do something wrong.")
            |> mes("Thanks for being honest, pal.")
            |> close()
          end

        _ ->
          ctx
      end
    end
  end

  defp explain_cookie_search(ctx) do
    {ctx, offer} =
      ctx
      |> mes("[Tourist]")
      |> mes("I wanted to give my girlfriend")
      |> mes("some well baked cookies.")
      |> mes("Sadly, in my hometown of")
      |> mes("Morocc, we don't have fancy")
      |> mes("foods like that.")
      |> next()
      |> mes("[Tourist]")
      |> mes("I've been asking all these")
      |> mes("merchants about it, and I was")
      |> mes("told that I could only get them")
      |> mes("in Lutie...that's my story.")
      |> next()
      |> mes("[Tourist]")
      |> mes("Now I'm running out of money and")
      |> mes("food...I can't stay here much longer...")
      |> next()
      |> select(["Do you want me to help you?", "Well, good luck with everything."])

    if offer == 1 do
      ctx
      |> set_char_var(:thai_head, 3)
      |> mes("[Tourist]")
      |> mes("Thank god! Thank you so much.")
      |> mes("I knew you would help me~!")
      |> next()
      |> mes("[Tourist]")
      |> mes("Umm...")
      |> mes("Before we talk about that help...")
      |> mes("Er, hmmmm...")
      |> mes("Well, you know I'm pretty")
      |> mes("much starving to death now...")
      |> next()
      |> mes("[Tourist]")
      |> mes("Could you please get me some Meat?")
      |> mes("I know I'm asking you too much,")
      |> mes("but I'm pretty much penniless")
      |> mes("so I don't really have much")
      |> mes("of a choice...")
      |> close()
    else
      ctx
      |> set_char_var(:thai_head, 1)
      |> mes("[Tourist]")
      |> mes(".........")
      |> mes("How could you be so cold")
      |> mes("hearted after hearing my story?")
      |> mes("...You're pretty mean!")
      |> close()
    end
  end

  defp hungry_without_meat(ctx) do
    ctx
    |> mes("[Tourist]")
    |> mes("I see...I can understand that you")
    |> mes("can't help me. It's alright...")
    |> mes("It's not like I have the right")
    |> mes("to demand anything of you...")
    |> mes("But...")
    |> next()
    |> mes("[Tourist]")
    |> mes("*Sob*...so... hungry...")
    |> close()
  end

  defp request_cookies(ctx) do
    ctx =
      ctx
      |> set_char_var(:thai_head, 4)
      |> mes("^3355FFHe seemed to have been")
      |> mes("starving for a long time.")
      |> mes("He ate all the meat I gave him")
      |> mes("and it was all gone in a flash.^000000")

    ctx =
      if count_item(ctx, 538) > 0 do
        ctx =
          mes(
            ctx,
            "^0000FF...Oh my! He took my cookies without even asking and ate all of those too!!^000000"
          )

        delitem(ctx, 538, count_item(ctx, 538))
      else
        ctx
      end

    ctx
    |> next()
    |> mes("[Tourist]")
    |> mes("*Phew*...thanks.")
    |> mes("At long last...")
    |> mes("I feel stuffed.")
    |> mes("...Oh. Right.")
    |> mes("My girlfriend.")
    |> next()
    |> mes("[Tourist]")
    |> mes("Er...about the well-baked")
    |> mes("cookie I told you about? Um... I")
    |> mes("know I'm being rude and selfish")
    |> mes("...But I don't think I can find")
    |> mes("it on my own.")
    |> next()
    |> mes("[Tourist]")
    |> mes("So, could you bring me ^0000FF20 Well-baked Cookies^000000?")
    |> next()
    |> mes("[Tourist]")
    |> mes("Although I shouldn't be asking for")
    |> mes("any more favors, and you'd have")
    |> mes("to go through all this trouble...")
    |> mes("while I'd be safe over here...")
    |> next()
    |> mes("[Tourist]")
    |> mes("I really want to make my")
    |> mes("girlfriend happy. Everything")
    |> mes("would be worth it for")
    |> mes("that smile on her face...")
    |> mes("I just can't pass this chance up!")
    |> next()
    |> mes("[Tourist]")
    |> mes("Haven't you been in love...?")
    |> mes("Surely you understand the")
    |> mes("sway that this woman has")
    |> mes("over me! Otherwise...I'd be")
    |> mes("selling jewels...anything")
    |> mes("other than this.")
    |> next()
    |> mes("[Tourist]")
    |> mes("I'm begging you, since you're")
    |> mes("stronger and less delicate")
    |> mes("than me, please bring me")
    |> mes("^0000FF20 Well-baked Cookies^000000!")
    |> mes("For me, it's impossible!!")
    |> close()
  end

  defp too_little_meat(ctx) do
    ctx
    |> mes("[Tourist]")
    |> mes("I appreciate that you're")
    |> mes("helping me out of the")
    |> mes("goodness of your heart,")
    |> mes("but...")
    |> next()
    |> mes("[Tourist]")
    |> mes("What are you...")
    |> mes("Cheap?! You can feed")
    |> mes("a starving man more")
    |> mes("than this...bring me")
    |> mes("more Meat!")
    |> close()
  end

  defp too_much_meat(ctx, required_meat) do
    ctx =
      if required_meat == 40 do
        ctx
      else
        ctx
        |> mes("[Tourist]")
        |> mes("I appreciate you bringing")
        |> mes("all this for me but...")
        |> next()
      end

    ctx
    |> mes("[Tourist]")
    |> mes("Geez, you want I should")
    |> mes("choke myself to death?")
    |> mes("I can't eat all of this!")
    |> mes("Bring me less Meat, yeah?")
    |> close()
  end
end
