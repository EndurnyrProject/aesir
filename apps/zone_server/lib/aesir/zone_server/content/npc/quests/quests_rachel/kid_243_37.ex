defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Kid24337 do
  @moduledoc """
  A mischievous child offers clues about a temple window.

  ## Behavior

  - Asks about candy and may reveal a way into the temple during the Sanctuary quest.
  - Reminds the player about the window after revealing the secret.

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
      %{
        map: "rachel",
        x: 243,
        y: 37,
        dir: 3,
        sprite: 921,
        name: "Kid",
        scope: :shared,
        unique_name: "Kid#Candy Addict"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    quest = get_char_var(ctx, :ra_tem_q, 0)

    cond do
      quest < 2 or quest > 9 or
          Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 8192)) ->
        greet(ctx)

      quest == 2 ->
        reminder(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet(ctx) do
    ctx =
      ctx
      |> mes("[Kid]")
      |> mes("Hey! What's that")
      |> mes("smile for? You're not")
      |> mes("gonna come pat my head,")
      |> mes("are you? No! I hate that!")
      |> next()
      |> mes("[Kid]")
      |> mes("Don't come here!")
      |> mes("I don't want you to")
      |> mes("pat my head! Grrr...")
      |> mes("I-I'm warning you!")
      |> next()
      |> mes("[Kid]")
      |> mes("Hey, look at your")
      |> mes("clothes! Where did")
      |> mes("you come from, huh?")
      |> next()
      |> mes("[Kid]")
      |> mes("Are you from a")
      |> mes("different country?")
      |> next()
      |> mes("[Kid]")
      |> mes("Huh, huh?")
      |> mes("What country")
      |> mes("are you from?")
      |> next()
      |> mes("[Kid]")
      |> mes("Eh, whatever.")
      |> next()
      |> mes("[Kid]")
      |> mes("Oh hey, do")
      |> mes("you like candy?")

    if get_char_var(ctx, :ra_tem_q, 0) == 1, do: ask_about_candy(ctx), else: close(ctx)
  end

  defp ask_about_candy(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select(["Not at all.", "Yeah.", "Sure, I love the stuff~", "Not much."])

    case choice do
      1 -> ctx |> mes("[Kid]") |> mes("Hmpf! Okay.") |> close()
      choice when choice in [2, 3] -> candy_liker(ctx)
      4 -> dislikes_candy(ctx)
      _ -> ctx
    end
  end

  defp dislikes_candy(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("Oh. It's 'cause you're")
    |> mes("a grown-up. Why don't")
    |> mes("you like candies, anyway?")
    |> next()
    |> mes("[Kid]")
    |> mes("Why, huh?")
    |> mes("Tell me, tell")
    |> mes("me, how come?")
    |> close()
  end

  defp candy_liker(ctx) do
    if Enum.random(1..2) != 2 do
      ctx
      |> mes("[Kid]")
      |> mes("Oh yeah...?")
      |> next()
      |> mes("[Kid]")
      |> mes("But you're a grown-up,")
      |> mes("aren't you? Heh heh heh!")
      |> next()
      |> mes("[Kid]")
      |> mes("Candy is only for")
      |> mes("kids! Hahahahaah!")
      |> next()
      |> mes("[Kid]")
      |> mes("I tricked you!")
      |> mes("You big big dummy!")
      |> close()
    else
      ask_for_candy(ctx)
    end
  end

  defp ask_for_candy(ctx) do
    ctx =
      ctx
      |> mes("[Kid]")
      |> mes("Oh, you do?")
      |> mes("Does that mean")
      |> mes("that you have")
      |> mes("any candy, then?")
      |> next()
      |> mes("[Kid]")
      |> mes("I want one!")
      |> next()
      |> mes("[Kid]")
      |> mes("Hurry, give me one!")
      |> mes("Gimmie gimmie~!")
      |> next()

    if count_item(ctx, 529) > 0, do: offer_secret(ctx), else: no_candy(ctx)
  end

  defp offer_secret(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kid]")
      |> mes("Mmm...")
      |> mes("If you give me")
      |> mes("some Candy, then I'll")
      |> mes("tell you something")
      |> mes("really cool, yeah?")
      |> next()
      |> select(["Sure.", "No."])

    if choice == 1 do
      ctx
      |> mes("[Kid]")
      |> mes("Yay~")
      |> next()
      |> mes("[Kid]")
      |> mes("Hah! Got you!")
      |> mes("I didn't want any")
      |> mes("candy anyway! Nyeh!")
      |> mes("But I like you, so")
      |> mes("I can tell you a secret!")
      |> next()
      |> mes("[Kid]")
      |> mes("Did you know that")
      |> mes("they always leave one")
      |> mes("of the windows to the temple")
      |> mes("unlocked? You spy on the")
      |> mes("priests inside. They're always")
      |> mes("fighting! Isn't that bad?")
      |> next()
      |> mes("[Kid]")
      |> mes("Oh well, they're adults,")
      |> mes("so I dunno. Maybe they...")
      |> mes("Mm. Well, I remember that")
      |> mes("fighting is supposed to be bad.")
      |> next()
      |> mes("[Kid]")
      |> mes("Awww, nuts!")
      |> mes("I just remembered!")
      |> mes("If you have candy, it")
      |> mes("must be from another")
      |> mes("country! I should have")
      |> mes("taken it from you. Dang it!")
      |> next()
      |> mes("[Kid]")
      |> mes("Oooh, I hate you")
      |> mes("now! Leave me alone!")
      |> set_char_var(:ra_tem_q, 2)
      |> close()
    else
      ctx
      |> mes("[Kid]")
      |> mes("You don't wanna")
      |> mes("share your candy?")
      |> mes("Hmpf! I guess you")
      |> mes("must really love it.")
      |> mes("...You big greedy.")
      |> close()
    end
  end

  defp no_candy(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Kid]")
      |> mes("Wait, you don't have")
      |> mes("any Candy, huh? How can")
      |> mes("you tell me you like Candy")
      |> mes("when you don't carry any?")
      |> mes("Look at this! My pockets")
      |> mes("are full of candy!")
      |> next()
      |> mes("[Kid]")
      |> mes("See?")
      |> mes("Look at all")
      |> mes("this candy!")
      |> next()
      |> mes("[Kid]")
      |> mes("Yeah, you have to")
      |> mes("have at least this")
      |> mes("much candy to say")
      |> mes("that you like them.")
      |> mes("Hee hee hee hee!")
      |> next()
      |> mes("[Kid]")
      |> mes("Oh hey...")
      |> mes("Would you like to")
      |> mes("have some candy?")
      |> next()
      |> mes("[Kid]")
      |> mes("Haha! I tricked you!")
      |> mes("I'm not gonna share")
      |> mes("all this candy with you!")
      |> mes("All of it is for me!")
      |> next()
      |> mes("[Kid]")
      |> mes("...............................")
      |> mes("Um... Are you mad?")
      |> next()
      |> mes("[Kid]")
      |> mes("Oh...")
      |> mes("You are mad")
      |> mes("at me, aren't you?")
      |> next()
      |> mes("[Kid]")
      |> mes("Okay, okay.")
      |> mes("I'll tell you a really")
      |> mes("cool secret, so promise")
      |> mes("that you won't be mad anymore.")
      |> next()
      |> select(["No, thanks.", "What's that?"])

    case choice do
      1 ->
        ctx |> mes("[Kid]") |> mes("Please~") |> close()

      2 ->
        ctx
        |> mes("[Kid]")
        |> mes("Did you know that")
        |> mes("they always leave one")
        |> mes("of the windows to the temple")
        |> mes("unlocked? You spy on the")
        |> mes("priests inside. They're always")
        |> mes("fighting! Isn't that bad?")
        |> next()
        |> mes("[Kid]")
        |> mes("Oh well, they're adults,")
        |> mes("so I dunno. Maybe they...")
        |> mes("Mm. Well, I remember that")
        |> mes("fighting is supposed to be bad...")
        |> next()
        |> mes("[Kid]")
        |> mes("Now, I hope you")
        |> mes("won't be mad at")
        |> mes("me anymore...")
        |> mes("If you're not,")
        |> mes("then I'm gonna")
        |> mes("be madder at you!")
        |> set_char_var(:ra_tem_q, 2)
        |> close()

      _ ->
        ctx
    end
  end

  defp reminder(ctx) do
    ctx
    |> mes("[Kid]")
    |> mes("You're leaving?")
    |> mes("Don't you want to")
    |> mes("watch me play Rock,")
    |> mes("Paper, Scissors?")
    |> next()
    |> mes("[Kid]")
    |> mes("Hey! I don't like")
    |> mes("the way you're looking")
    |> mes("at me. I don't like you")
    |> mes("watching me like that!")
    |> mes("Why don't you go away?")
    |> next()
    |> mes("[Kid]")
    |> mes("Gosh, I said, go away!")
    |> next()
    |> mes("[Kid]")
    |> mes("If you're that bored,")
    |> mes("why don't you peep through")
    |> mes("the windows in the temple,")
    |> mes("huh? Gosh! Some people!")
    |> close()
  end
end
