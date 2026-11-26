defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Kid327185 do
  @moduledoc """
  Karyn asks for help rescuing his sister Curdie.

  ## Behavior

  - Starts the rescue quest, gives progress reminders and later helps the player borrow a boat.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "veins",
        x: 327,
        y: 185,
        dir: 3,
        sprite: 944,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#camelcamel"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) do
      rescue_progress(ctx, get_char_var(ctx, :rachel_camel, 0))
    else
      ctx
      |> mes("[Kid Karyn]")
      |> mes("^333333*Sob*^000000...")
      |> mes("^333333*Sob*^000000...")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp rescue_progress(ctx, 0) do
    ctx =
      ctx
      |> mes("[Kid Karyn]")
      |> mes("*Sob*")
      |> next()
      |> mes("^3355FFThis sobbing child")
      |> mes("looks really upset...^000000")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, why are you")
      |> mes("crying? Are you lost?")
      |> mes("Where's your mommy?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("My... Mom's")
      |> mes("at home...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("......")
      |> mes(".........")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I see. So...")
      |> mes("Are you having")
      |> mes("trouble finding")
      |> mes("your way back home?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("No! I'm ten years old!")
      |> mes("I can find my way home,")
      |> mes("even with my eyes closed!")
      |> mes("^333333*Sniff sniff*^000000 Uuuuuuweeeh~")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Well...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Can you tell me")
      |> mes("why you're crying?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("I... ^333333*Sniff*^000000")
      |> mes("I-I went to... Th-...")
      |> mes("Volcan.... w-w-with")
      |> mes("my sist-- Waaaaaaah!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Poor kid... Come on,")
      |> mes("take a deep breath so")
      |> mes("you can tell me about what")
      |> mes("happened a little more slowly.")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("*^333333Sob*^000000 ...It's just...")
      |> mes("I went to Thor Volcano")
      |> mes("with my little sister to see")
      |> mes("which one of us was braver...")
      |> mes("But then, we met some...")
      |> mes("Scary people there... and...")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("I got scared, so... So...")
      |> mes("My sister... Wah~! *Sob*")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("*Sob*")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("I-I ran away from them...")
      |> mes("But I left my sister over")
      |> mes("there with those weird men...")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Mom's sick, and dad's")
      |> mes("always at work... He's")
      |> mes("the captain of a ship, so...")
      |> mes("I don't think they can help.")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Can you help me please,")
      |> mes("and bring my sister back?")
      |> mes("*Sniff* Please? I promise")
      |> mes("that I can pay you as soon")
      |> mes("as my dad comes back!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wait... I have a question.")
      |> mes("You said that someone took")
      |> mes("away your sister at Thor")
      |> mes("Volcano? What did they look")
      |> mes("like? Are you sure that there")
      |> mes("were people there?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("I... I don't know!")
      |> mes("I got so scared, I just")
      |> mes("ran away! I... I didn't")
      |> mes("mean to leave my sister!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hmmm...")
      |> mes("Maybe your sister was")
      |> mes("kidnapped by bandits...")
      |> next()

    {ctx, choice} = select(ctx, ["Decline Request", "Accept Request"])

    case choice do
      1 ->
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Sorry kid, but I've got")
        |> mes("things to do. I'm sure")
        |> mes("someone else will come")
        |> mes("along to save your sister.")
        |> next()
        |> mes("[Kid Karyn]")
        |> mes("Wah~")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[#{char_name(ctx, 0)}]")
          |> mes("Okay, I'll see what")
          |> mes("I can do. I'll try my best")
          |> mes("to find your sister.")
          |> next()
          |> mes("[Kid Karyn]")
          |> mes("Thank you so much!")
          |> mes("Please find my sister")
          |> mes("Curdie soon! Oh, I hope")
          |> mes("she's okay! If she's not...")
          |> mes("^333333*Sob*^000000 I don't know what")
          |> mes("I'll do! Waaaaaaaah~")
          |> next()

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Alright...")
        |> mes("Wish me luck.")
        |> mes("I'll go search Thor")
        |> mes("Volcano to find your")
        |> mes("little sister Curdie.")
        |> setquest(3060)
        |> set_char_var(:rachel_camel, 1)
        |> close()

      _ ->
        ctx
    end
  end

  defp rescue_progress(ctx, 1) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I'd better search")
    |> mes("Thor Volcano for Curdie,")
    |> mes("Karyn's little sister.")
    |> close()
  end

  defp rescue_progress(ctx, 2) do
    ctx =
      ctx
      |> mes("[Kid Karyn]")
      |> mes("W-were you able")
      |> mes("to find my sister?")
      |> mes("Is she alright?")
      |> mes("What happened?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("I found her,")
      |> mes("she's alright but...")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("What? Why isn't")
      |> mes("she with you?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Curdie is... Well, she's")
    |> mes("been shackled down. We")
    |> mes("need to find a way to free her.")
    |> mes("Do you know where there's")
    |> mes("a forge or a locksmith that")
    |> mes("might be able to help her?")
    |> next()
    |> mes("[Kid Karyn]")
    |> mes("Oh! Oh, there's a")
    |> mes("locksmith in the market")
    |> mes("street! You can ask him")
    |> mes("to help free Curdie!")
    |> changequest(3061, 3062)
    |> set_char_var(:rachel_camel, 3)
    |> close()
  end

  defp rescue_progress(ctx, 3) do
    ctx
    |> mes("[Kid Karyn]")
    |> mes("Let's see...")
    |> mes("I'd better find the")
    |> mes("locksmith in the market")
    |> mes("street, and ask him to help")
    |> mes("me unlock Curdie's shackles.")
    |> close()
  end

  defp rescue_progress(ctx, 4) do
    ctx
    |> mes("[Kid Karyn]")
    |> mes("Huh... I'd better talk")
    |> mes("to Mr. Lockenlock first, the")
    |> mes("locksmith in the market street.")
    |> close()
  end

  defp rescue_progress(ctx, 5) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Hmm... I'd better talk")
    |> mes("to Ms. Ivory, the organic")
    |> mes("soap maker if I want to help")
    |> mes("Karyn free his sister Curdie.")
    |> close()
  end

  defp rescue_progress(ctx, 6) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wait... I should be")
      |> mes("bringing Ms. Ivory all")
      |> mes("of the soap ingredients.")
      |> mes("What were they again...?")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^4D4DFF10 Milk^000000,")
    |> mes("^4D4DFF100 Green Herbs^000000,")
    |> mes("^4D4DFF50 Jellopies^000000, and")
    |> mes("^4D4DFF5 Empty Bottles^000000.")
    |> mes("I better get those...")
    |> close()
  end

  defp rescue_progress(ctx, 7) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I need to talk to")
    |> mes("someone named Saraman")
    |> mes("to get the soap ingredients...")
    |> close()
  end

  defp rescue_progress(ctx, 8) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Let's see...")
      |> mes("I need to bring")
      |> mes("Mr. Saruman all the")
      |> mes("things he needs to")
      |> mes("stimulate a camel's ")
      |> mes("appetite. I need to get...")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("^4D4DFF1 Unripe Apple^000000,")
    |> mes("^4D4DFF5 Monster's Feed^000000,")
    |> mes("^4D4DFF1 Empty Bottle^000000, and")
    |> mes("^4D4DFF1 Yellow Potion^000000.")
    |> close()
  end

  defp rescue_progress(ctx, 9) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I have everything I need")
    |> mes("to stimulate a camel's")
    |> mes("appetite. Now I need to")
    |> mes("feed the camel so that I can")
    |> mes("get the soap ingredients and")
    |> mes("5 lumps of camel dung.")
    |> close()
  end

  defp rescue_progress(ctx, 10) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Right now, my time")
    |> mes("would be better spent")
    |> mes("looking for the Silk Sand")
    |> mes("Camel for the ingredients.")
    |> close()
  end

  defp rescue_progress(ctx, 11) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I'd better find Mr. Saraman's")
    |> mes("lost camel, feed it camel")
    |> mes("appetite stimulants, and")
    |> mes("then get the soap ingredient")
    |> mes("and 5 lumps of camel dung")
    |> mes("if I want to free Curdie.")
    |> close()
  end

  defp rescue_progress(ctx, 17) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I managed to get the soap")
    |> mes("ingredient and 5 of those")
    |> mes("camel dung lumps. I should")
    |> mes("head back to Mr. Saraman to")
    |> mes("tell him where his camel is,")
    |> mes("and then go to Ms. Ivory.")
    |> close()
  end

  defp rescue_progress(ctx, 18) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Let's see...")
    |> mes("Shouldn't I be going")
    |> mes("to see Ms. Ivory now?")
    |> close()
  end

  defp rescue_progress(ctx, 19) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I have the Silk Sand Camel")
    |> mes("Soap now, so I should go")
    |> mes("bring it to Mr. Lockenlock.")
    |> close()
  end

  defp rescue_progress(ctx, 20) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I'd better use the soap to")
    |> mes("make a key mold that I can")
    |> mes("bring over to Mr. Lockenlock.")
    |> close()
  end

  defp rescue_progress(ctx, 21) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Making the key is more")
    |> mes("important that telling Karyn")
    |> mes("about what's happened.")
    |> close()
  end

  defp rescue_progress(ctx, 22) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I need to bring")
    |> mes("1 Steel to Mr. Lockenlock")
    |> mes("so that he can make a key")
    |> mes("that will finally free Curdie.")
    |> close()
  end

  defp rescue_progress(ctx, 23) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("I finally got the")
    |> mes("key that I can use")
    |> mes("to free Curdie. I'm")
    |> mes("gonna go save her now.")
    |> next()
    |> mes("[Kid Karyn]")
    |> mes("Thank you so much!")
    |> mes("Please bring back Curdie")
    |> mes("as soon as you can! ^333333*Sob*^000000")
    |> close()
  end

  defp rescue_progress(ctx, progress) when progress > 11 and progress < 17 do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Well... I found the")
    |> mes("camel. Now I need to get")
    |> mes("all the soap ingredients.")
    |> mes("The sooner I do that, the")
    |> mes("sooner I can help Curdie.")
    |> close()
  end

  defp rescue_progress(ctx, 24) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hey, Karyn! I sent")
      |> mes("your sister back to town")
      |> mes("with a Butterfly Wing.")
      |> mes("Did she come back safe?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Yes, Curdie's back")
      |> mes("and she's resting in")
      |> mes("the hospital right now.")
      |> mes("Thank you so much for")
      |> mes("all of your help!")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("I'm not sure what's wrong")
      |> mes("with Curdie, though. Ever")
      |> mes("since she got back, she gets")
      |> mes("frightened whenever she")
      |> mes("sees the soldiers in town.")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("I promise to tell my dad")
      |> mes("about what you did after he")
      |> mes("comes back from overseas.")
      |> mes("Thank you for everything")
      |> mes("that you did for us!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Umm... I see...")
      |> mes("I'll come by later")
      |> mes("when Curdie's released")
      |> mes("from the hospital.")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Yes, please do.")
      |> mes("I promise to help you")
      |> mes("whenever you need me!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hahahaha!")
      |> mes("Well... I guess that's")
      |> mes("pretty reassuring. Until then,")
      |> mes("take good care of your mother")
      |> mes("and sister. You got that?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Got it!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Good, good...")
      |> mes("It's a promise, then.")
      |> mes("I'll see you later~")
      |> completequest(3083)
      |> set_char_var(:rachel_camel, 25)
      |> specialeffect2(:absorbspirits)

    ctx =
      if Rathena.truthy?(checkre(ctx, 3)),
        do: getexp(ctx, 100_000, 50_000),
        else: getexp(ctx, 1_000_000, 700_000)

    close(ctx)
  end

  defp rescue_progress(ctx, _progress) do
    cond do
      get_char_var(ctx, :aru_monas, 0) < 15 -> thank_player(ctx)
      get_char_var(ctx, :aru_monas, 0) == 15 -> lend_boat(ctx)
      get_char_var(ctx, :aru_monas, 0) < 26 -> boat_reminder(ctx)
      true -> fishing_news(ctx)
    end
  end

  defp thank_player(ctx) do
    ctx
    |> mes("[Kid Karyn]")
    |> mes("Oh, hello! Thank you")
    |> mes("so much for helping me")
    |> mes("last time! When I get")
    |> mes("older, I'm gonna do my")
    |> mes("best to help you the same")
    |> mes("way that you helped me!")
    |> close()
  end

  defp lend_boat(ctx) do
    ctx =
      ctx
      |> mes("[Kid Karyn]")
      |> mes("Hi! It's good to see")
      |> mes("you again! Kurdi just came")
      |> mes("back home from the hospital,")
      |> mes("and is getting better everyday!")
      |> mes("Ah, and I've been taking care")
      |> mes("of her, just like I promised~")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Really? That's good")
      |> mes("You should be proud~")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("^666666*Blush*^000000 Heh heh!")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Anyway, I was wondering")
      |> mes("if you could help me.")
      |> mes("Your dad's a fisherman,")
      |> mes("right? Would you mind")
      |> mes("asking him if I could")
      |> mes("borrow his boat?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Well... Actually...")
      |> mes("The pope said that my")
      |> mes("dad isn't allowed to use")
      |> mes("his boat for a while...")
      |> mes("I'm not sure why...")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("So yeah. Dad's not allowed")
      |> mes("to go out to sea right now.")
      |> mes("But it should be okay if it's")
      |> mes("you, right? Hey, you helped")
      |> mes("me, so I hafta help you, right?")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("My dad is really mad that")
      |> mes("he can't use his boat so")
      |> mes("maybe we better not tell")
      |> mes("him you want to use it. Let's")
      |> mes("keep it our secret, okay?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("S-sure thing!")
      |> next()
      |> mes("[Kid Karyn]")
      |> mes("Anyway, his boat is the")
      |> mes("only one on the south beach")
      |> mes("since all the other fishermen")
      |> mes("dock theirs boats in other")
      |> mes("places. Also, my dad's boat")
      |> mes("will rust if no one uses it.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Great! Thanks so much")
    |> mes("for your help, Karyn~")
    |> mes("I'll be sure to take")
    |> mes("good care of your dad's")
    |> mes("boat. I only need it for")
    |> mes("a little while, anyway.")
    |> next()
    |> mes("[Kid Karyn]")
    |> mes("Heh heh! Thanks!")
    |> mes("I'm happy that")
    |> mes("I can help you too!")
    |> set_char_var(:aru_monas, 16)
    |> close()
  end

  defp boat_reminder(ctx) do
    ctx
    |> mes("[Kid Karyn]")
    |> mes("Hi! How do you like")
    |> mes("fishing on my dad's boat?")
    |> mes("Oh, and Kurdi says hi!")
    |> close()
  end

  defp fishing_news(ctx) do
    ctx
    |> mes("[Kid Karyn]")
    |> mes("Dad says that he'll")
    |> mes("be able to go fishing")
    |> mes("again soon! I hope that")
    |> mes("he'll catch a lot of fish!")
    |> close()
  end
end
