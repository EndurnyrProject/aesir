defmodule Aesir.ZoneServer.Content.Npc.Cities.Lighthalzen.Beggar do
  @moduledoc """
  Asks passersby for a small donation and shares hard-earned wisdom.

  ## Behavior

  - Asks for 50 zeny and declines the donation when the player has less than that amount.
  - Accepts the donation and shares one of three randomly selected stories.

  ## Credits

  - Original from rAthena, authors and Contributors
    - erKURITA
    - Au{R}oN (Translated by Alan)
    - $ephiroth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 312,
        y: 233,
        dir: 3,
        sprite: 777,
        name: "Beggar",
        scope: :shared,
        unique_name: "Beggar#lhz_02",
        trigger: {3, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx), do: ask_for_money(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp ask_for_money(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Beggar]")
      |> mes("Please...")
      |> mes("My child is starving...")
      |> mes("Would you give me")
      |> mes("some money?")
      |> next()
      |> select(["Give him some money.", "Ignore him."])

    if choice == 1 do
      donate(ctx)
    else
      ignore_beggar(ctx)
    end
  end

  defp donate(ctx) do
    if zeny(ctx) < 50 do
      ctx
      |> mes("[Beggar]")
      |> mes("I appreciate your")
      |> mes("kindness, but it also")
      |> mes("looks like you're in need")
      |> mes("of zeny, too. Would you")
      |> mes("like to join me?")
      |> emotion(:smile)
      |> close()
    else
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Here you go,")
      |> mes("take this.")
      |> pay_zeny(50)
      |> next()
      |> mes("[Beggar]")
      |> mes("Thank you so much.")
      |> mes("I have nothing to offer you")
      |> mes("in exchange, but I can share")
      |> mes("a story with you and impart")
      |> mes("some of the wisdom I've")
      |> mes("learned over the years.")
      |> emotion(:thanks)
      |> next()
      |> tell_random_story()
    end
  end

  defp tell_random_story(ctx) do
    case Enum.random(1..3) do
      1 -> tell_choice_story(ctx)
      2 -> tell_fate_story(ctx)
      3 -> tell_anger_story(ctx)
    end
  end

  defp tell_choice_story(ctx) do
    ctx
    |> mes("[Beggar]")
    |> mes("Everyone's been in")
    |> mes("a situation where you")
    |> mes("sometimes you feel that")
    |> mes("you have to make a choice")
    |> mes("between doing the right thing")
    |> mes("and doing what you want, right?")
    |> next()
    |> mes("[Beggar]")
    |> mes("You may feel trapped.")
    |> mes("Well, let me tell you, when")
    |> mes("it comes to a problem, all")
    |> mes("the solutions available to")
    |> mes("you aren't always obvious.")
    |> mes("So just calm down and think.")
    |> next()
    |> mes("[Beggar]")
    |> mes("What you can see and")
    |> mes("understand might not match")
    |> mes("with reality. Like the stars that are always there, but not visible")
    |> mes("during the day, we'll always have hope, even if we can't see it.")
    |> next()
    |> reflect()
    |> mes("[Beggar]")
    |> emotion(:question)
    |> mes("Hmm...?")
    |> mes("You seem surprised~")
    |> close()
  end

  defp tell_fate_story(ctx) do
    ctx
    |> mes("[Beggar]")
    |> mes("I sort of believe in fate and")
    |> mes("sort of don't. Let me explain")
    |> mes("it this way. I take life day by")
    |> mes("day, with each day covering its")
    |> mes("own spectrum with miracle on one end and tragedy on the other.")
    |> next()
    |> mes("[Beggar]")
    |> mes("So each day has the capacity")
    |> mes("for experiences that can be")
    |> mes("good, bad or both. I believe")
    |> mes("each person can take an ")
    |> mes("active role in shaping their")
    |> mes("destiny, day by day.")
    |> next()
    |> mes("[Beggar]")
    |> mes("Now, there may be certain")
    |> mes("things that you can't control,")
    |> mes("but even a pessimist might")
    |> mes("be able to agree that this")
    |> mes("is a world that not only has")
    |> mes("tragedy, but miracles as well.")
    |> next()
    |> mes("[Beggar]")
    |> mes("Stand up when you're down")
    |> mes("and live your life with passion. The capacity for miracles will")
    |> mes("always be there and know that")
    |> mes("you can be someone else's")
    |> mes("miracle. Isn't that wonderful?")
    |> next()
    |> reflect()
    |> mes("[Beggar]")
    |> emotion(:question)
    |> mes("Don't believe me?")
    |> mes("Well, you'll see for")
    |> mes("yourself, youngster.")
    |> mes("There's much good in you.")
    |> close()
  end

  defp tell_anger_story(ctx) do
    ctx
    |> mes("[Beggar]")
    |> mes("Anger. People deal with")
    |> mes("it in different ways. Some")
    |> mes("suppress it. Some relish it.")
    |> mes("Some fear being angry. Now,")
    |> mes("to be simple, let's say there")
    |> mes("are two kinds of anger.")
    |> next()
    |> mes("[Beggar]")
    |> mes("The first is the kind that")
    |> mes("isn't so productive. More of")
    |> mes("a frustration that you can let")
    |> mes("go. Someone cut you off on the")
    |> mes("freeway or a friend innocently forgot your birthday? No biggie.")
    |> next()
    |> mes("[Beggar]")
    |> mes("Don't let this kind of")
    |> mes("anger get to you or you'll")
    |> mes("look like a loser. Think of")
    |> mes("the big picture and if you're")
    |> mes("still upset, vent appropriately. Be honest without hurting anyone.")
    |> next()
    |> mes("[Beggar]")
    |> mes("The second kind of anger")
    |> mes("is righteous anger. You've")
    |> mes("been wronged and need ")
    |> mes("some form of retribution. ")
    |> mes("Just don't misdirect your anger")
    |> mes("and respond appropriately.")
    |> next()
    |> mes("[Beggar]")
    |> mes("The second kind of anger is")
    |> mes("righteous anger. You've been")
    |> mes("wronged and need some form")
    |> mes("of retribution. Remember to")
    |> mes("make appropriate confrontations")
    |> mes("and don't misdirect your rage.")
    |> next()
    |> mes("[Beggar]")
    |> mes("Getting into a fight with")
    |> mes("righteous anger, say to protect")
    |> mes("someone dear to you, will make")
    |> mes("you a hero. Fighting with anger")
    |> mes("born of frustration will make you a bully. Know the difference.")
    |> next()
    |> reflect()
    |> mes("[Beggar]")
    |> emotion(:question)
    |> mes("What's wrong?")
    |> mes("It might be a lot")
    |> mes("to take in, I know.")
    |> close()
  end

  defp reflect(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> emotion(:think)
    |> mes(". . . . . . . . . . . .")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> emotion(:think)
    |> mes(". . . . . . . . . . . .")
    |> mes(". . . . . . . . . . . .")
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> emotion(:think)
    |> mes(". . . . . . . . . . . .")
    |> mes(". . . . . . . . . . . .")
    |> mes(". . . . . . . . . . . .")
    |> next()
  end

  defp ignore_beggar(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("...")
    |> mes("......")
    |> close()
  end
end
