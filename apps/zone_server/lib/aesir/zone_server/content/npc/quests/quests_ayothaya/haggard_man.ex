defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.HaggardMan do
  @moduledoc """
  A wounded fugitive offers a reward for keeping his whereabouts secret.

  ## Behavior

  - At the ring quest's relevant stage, accepts a White Potion and rewards the player with experience.
  - Disappears after the encounter, including when the player lacks a potion or confronts him.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "ayo_dun02", x: 91, y: 264, dir: 3, sprite: 841, name: "Haggard Man", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @white_potion 504

  @impl true
  def on_event("OnInit", ctx), do: hide(ctx)

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :thai_find, 0) == 13 do
      encounter(ctx)
    else
      ctx
      |> mes("[Haggard Man]")
      |> mes("Huh? Who are you?")
      |> mes("This isn't a safe place for a tourists! You should leave right away!")
      |> close()
      |> hide()
    end
  end

  defp encounter(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Haggard Man]")
      |> mes("^666666*...Cough cough*^000000")
      |> mes("No...! My hiding place!")
      |> next()
      |> mes("[Haggard Man]")
      |> mes("Hmmm...?")
      |> mes("I'm bleeding?!")
      |> mes("Oh, how did this happen?")
      |> mes("My spiritual training wasn't supposed to go like this...!")
      |> next()
      |> select(["Treat his wound first.", "Is that you, Annon?"])

    case choice do
      1 -> treat_wound(ctx)
      2 -> confront(ctx)
      _ -> ctx
    end
  end

  defp treat_wound(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Anyway, I think you need to be treated. Let me check if I have some potions.")
      |> next()

    if Rathena.truthy?(count_item(ctx, @white_potion)) do
      healed(ctx)
    else
      no_potion(ctx)
    end
  end

  defp healed(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Ah...")
      |> mes("Here we are,")
      |> mes("a White Potion.")
      |> delitem(@white_potion, 1)
      |> next()
      |> mes("[Haggard Man]")
      |> mes("You mean the White Potion,")
      |> mes("the ultimate drink for healing?")
      |> mes(
        "I appreciate you doing me this favor. ^666666*Phew*^000000 Now, I feel much better."
      )
      |> next()
      |> mes("[Annon]")
      |> mes("Ah, my apologies for not introducing myself earlier.")
      |> mes("I am called Annon. You must wondering what I must be doing")
      |> mes("here under the ground.")
      |> next()
      |> mes("[Annon]")
      |> mes(
        "Well, I'm performing a special exercise for my spiritual training. Though, it may be hard to believe."
      )
      |> next()
      |> mes("[Annon]")
      |> mes("What...?")
      |> mes("Shuda sent you?! Oh well...")
      |> mes("I thank you for curing me. Now, it's time for me to resume my training.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> specialeffect(:cloaking)
      |> mes(
        "Wait, I can't let you go! You don't know how hard it was for me to find you! You can't just leave!"
      )
      |> next()
      |> mes("[Annon]")
      |> mes(
        "Hm? Then what is it that you want? I implore you, do not tell Shuda that you have found me. No matter what, I am not going back to her!"
      )
      |> next()
      |> mes("[Annon]")
      |> mes("Eh...?")
      |> mes("Did you find")
      |> mes("her ring already?")
      |> mes("Ooh, I was hoping it")
      |> mes("would never be found.")
      |> next()
      |> mes("[Annon]")
      |> mes(
        "She probably told you that I ran away out of shame for losing the ring, and that if you got the ring back, I'd be happy to return, right?"
      )
      |> next()
      |> mes("[Annon]")
      |> mes("Well...")
      |> mes("I threw away")
      |> mes("that ring on purpose!")
      |> mes("I'm serious about not")
      |> mes("going back to Shuda.")
      |> next()
      |> mes("[Annon]")
      |> mes(
        "It looks like you wish to know more. If you promise me that you will not mention my whereabouts"
      )
      |> mes("to Shuda, then I'll explain.")
      |> next()
      |> select([
        "You think the world revolves around you?",
        "What do you want me to do?"
      ])

    case choice do
      1 -> ctx |> explain_fear() |> reward()
      2 -> ctx |> request_silence() |> reward()
      _ -> ctx
    end
  end

  defp explain_fear(ctx) do
    {ctx, _} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("You think the world")
      |> mes("revolves around you?")
      |> mes("You can't just run away!")
      |> next()
      |> mes("[Annon]")
      |> mes("Oh, I know, I know!")
      |> mes("But you don't understand. Obviously, Shuda is beautiful.")
      |> next()
      |> mes("[Annon]")
      |> mes("But our parents arranged our marriage when we were babies.")
      |> mes("That kind of arrangement doesn't matter to me, but she obviously cares about it.")
      |> next()
      |> mes("[Annon]")
      |> mes("In all honesty, she scares me")
      |> mes("to death. Whenever I'm with her,")
      |> mes(
        "I can't help but break into a cold sweat. And when she's near, I have nightmares about her. ^666666*Brrr...*^000000"
      )
      |> next()
      |> mes("[Annon]")
      |> mes("She thinks it's funny to electrocute me. and ties me up in")
      |> mes(
        "a darkened room and feeds me only Jellopy whenever I don't listen to her. Now can you see why I crave freedom?"
      )
      |> next()
      |> mes("[Annon]")
      |> mes(
        "Of course, if you reveal to her that you've found me, I'll repay your favor. I implore you, just pretend you haven't found me, please?"
      )
      |> next()
      |> select(["...Alright, alright."])

    ctx
    |> mes("[Annon]")
    |> mes("Thank you so much!")
    |> mes(
      "Now, to pay you back, let me use one of the skills I've learned in my spiritual training."
    )
  end

  defp request_silence(ctx) do
    ctx
    |> mes("[Annon]")
    |> mes(
      "Of course, what I want you to do is to keep me a secret from Shuda. Just forget that you've ever met me, and let Shuda know it was impossible to find me."
    )
    |> next()
    |> mes("[Annon]")
    |> mes(
      "Besides, even if you help her, all she'll do is offer to name her kids after you. Now... Do you really want that? I know for sure that she and I won't be having children. There's enough evil in the world."
    )
    |> next()
    |> mes("[Annon]")
    |> mes("Now, you must be wondering")
    |> mes(
      "how I would repay you for your silence. Well, let me show you one of the skills I've learned in my spiritual training."
    )
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Annon]")
      |> mes("Let's see...")
      |> mes("Let me twist your")
      |> mes("arm this way, and")
      |> mes("apply pressure here...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Wahhh~!")
      |> mes("What the hell")
      |> mes("are you doing!")
      |> mes("You're hurting me, man!")
      |> next()
      |> mes("[Annon]")
      |> mes("Oh, this is a special kind")
      |> mes("of massage. Don't worry, it'll")
      |> mes("relieve you of fatigue. It's quite heavenly, actually. You'll see~")
      |> next()
      |> mes("^3355FF*Snap snap snap*")
      |> mes("*Snap snap snap*")
      |> mes("*Crack crack crack*")
      |> mes("*Crack crack crack*^000000")
      |> next()
      |> mes("^3355FFYou feel as though Annon")
      |> mes(
        "realigned every bone in your skeleton, placing them in the right spots. Strangely, you feel intense relaxation and refreshment instead of excruciating pain."
      )
      |> set_char_var(:thai_find, 14)
      |> completequest(12_034)

    ctx = grant_exp(ctx)
    ctx = next(ctx)

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Whoa...?")
    |> mes("That felt was so great~")
    |> mes("It even feels like my mind")
    |> mes("has been cleansed too!")
    |> mes("You've got a deal!")
    |> next()
    |> mes("[Annon]")
    |> mes("Thank you, thank you so much.")
    |> mes("Now I can avoid being tied to Shuda, at least for a little longer.")
    |> next()
    |> mes("[Annon]")
    |> mes("Now, if you'll excuse me,")
    |> mes("I must make good my escape")
    |> mes("before others find me.")
    |> mes("Good day~!")
    |> close()
    |> set_server_temp_var("annonactive", 0)
    |> disablenpc("Haggard Man")
  end

  defp grant_exp(ctx) do
    renewal = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)

    exp =
      cond do
        level < 56 -> if renewal, do: 900, else: 9000
        level < 61 -> if renewal, do: 1050, else: 10_500
        level < 66 -> if renewal, do: 1868, else: 18_684
        level < 71 -> if renewal, do: 2741, else: 27_411
        level < 76 -> if renewal, do: 7075, else: 70_757
        level < 81 -> if renewal, do: 13_024, else: 130_246
        level < 86 -> if renewal, do: 15_034, else: 150_340
        level < 91 -> if renewal, do: 18_205, else: 182_052
        true -> if renewal, do: 40_678, else: 406_786
      end

    getexp(ctx, exp, 0)
  end

  defp no_potion(ctx) do
    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("No way, no way.")
      |> mes("He's too seriously")
      |> mes("wounded to be cured")
      |> mes("with the normal potions")
      |> mes("that I have. I'll need")
      |> mes("a stronger potion...")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Okay, you stay")
      |> mes("here for a while.")
      |> mes("I'll bring you some")
      |> mes("medicine and treat")
      |> mes("your wound.")
      |> next()
      |> mes("[Haggard Man]")
      |> mes("No, you don't have to...")
      |> mes("^666666*Cough cough cough*^000000")
      |> mes("W-wait, don't push")
      |> mes("me back inside!")
      |> mes("Wahhhhhh~!")
      |> next()
      |> set_server_temp_var("annonactive", 0)
      |> disablenpc("Haggard Man")

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Okay, it's time")
      |> mes("for me to play doctor!")
      |> mes("I don't have much time!")
      |> mes("My mission: Bring back an")
      |> mes("ultra powerful potion for")
      |> mes("this poor guy~")

    ctx |> emotion(:best, playerattached(ctx)) |> close()
  end

  defp confront(ctx) do
    ctx =
      ctx
      |> mes("[Haggard Man]")
      |> mes("Annon...?")
      |> mes("Who's that?")
      |> mes("I've never heard of him!")
      |> mes("I don't know him, okay!")
      |> mes("Stop disturbing my training!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Uh...")
    |> mes(
      "Hmm, it doesn't seem like you should be yelling with that kind of wound. You sure you're not Annon?"
    )
    |> next()
    |> mes("[Haggard Man]")
    |> mes("I told you!")
    |> mes("I've never")
    |> mes("heard of him!")
    |> mes("L-leave me alone!")
    |> next()
    |> mes("[Haggard Man]")
    |> mes("I have to")
    |> mes("hide from Shuda.")
    |> mes("^666666*Cries*^000000")
    |> close()
    |> set_server_temp_var("annonactive", 0)
    |> disablenpc("Haggard Man")
  end

  defp hide(ctx), do: ctx |> set_server_temp_var("annonactive", 0) |> disablenpc("Haggard Man")
end
