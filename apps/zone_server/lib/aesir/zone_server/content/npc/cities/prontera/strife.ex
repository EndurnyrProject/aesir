defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Strife do
  @moduledoc """
  Follows Strife's dream of becoming a Knight and rewards a novice who grows stronger.

  ## Behavior

  - Records encouragement from a novice who shares Strife's dream.
  - Gives one item 2501 when that novice returns after changing class, then marks the reward complete.
  - Uses shorter repeat dialogue after each progression step.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 216,
        y: 70,
        dir: 2,
        sprite: 48,
        name: "Strife",
        scope: :shared,
        unique_name: "Strife#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    progress = get_char_var(ctx, :event_prt_nov_dreamtalk, 0)

    case {class(ctx), progress} do
      {:novice, 0} -> inspire_novice(ctx)
      {:novice, _progress} -> novice_refrain(ctx)
      {_class, 1} -> reward_progress(ctx)
      {_class, 2} -> accomplished_refrain(ctx)
      {_class, _progress} -> greet_experienced_adventurer(ctx)
    end
  end

  defp inspire_novice(ctx) do
    {ctx, choice} =
      ctx
      |> novice_dream_intro()
      |> mes("[Strife]")
      |> mes("MAGNUM BREAK!")
      |> next()
      |> select(["I wanna be strong too!", "Um... Do you best."])

    if choice == 1 do
      ctx
      |> set_char_var(:event_prt_nov_dreamtalk, 1)
      |> mes("[Strife]")
      |> mes("Wow...!")
      |> mes("That's so awesome!")
      |> mes("We both share the")
      |> mes("same dream!")
      |> next()
      |> mes("[Strife]")
      |> mes(
        "Hey, if you wanna become a Swordie, you gotta go to Izlude. There, you can go ahead and take the Swordman job test. The first time, I, um, failed miserably. But I won't fail again!"
      )
      |> next()
      |> mes("[Strife]")
      |> mes(
        "Training! Training! Gotta keep training! You need to be strong too! Once we both get stronger, we'll meet again!"
      )
      |> close()
    else
      ctx
      |> mes("[Strife]")
      |> mes(
        "Heh heh! I will for sure! 'Strife, the courageous Knight.' It sounds cool, doesn't it?"
      )
      |> close()
    end
  end

  defp novice_refrain(ctx) do
    ctx
    |> mes("[Strife]")
    |> mes("Fight...!")
    |> mes("Fight Fight FIGHT!")
    |> close()
  end

  defp reward_progress(ctx) do
    ctx
    |> mes("[Strife]")
    |> mes("Hey...!")
    |> mes(
      "You look different now. *Gasp* You've gotten... ^993333stronger^000000. Wow, that's so coooool!"
    )
    |> next()
    |> mes("[Strife]")
    |> mes("I'm so jealous!")
    |> mes("I guess that means")
    |> mes("that now, I gotta")
    |> mes("train even harder!")
    |> next()
    |> set_char_var(:event_prt_nov_dreamtalk, 2)
    |> give_item(2501, 1)
    |> mes("[Strife]")
    |> mes(
      "This is, well, for you to help you get even stronger. I guess I want to thank you for being such a good example."
    )
    |> close()
  end

  defp accomplished_refrain(ctx) do
    ctx
    |> mes("[Strife]")
    |> mes("Fight! Fight!")
    |> close()
  end

  defp greet_experienced_adventurer(ctx) do
    {ctx, choice} =
      ctx
      |> novice_dream_intro()
      |> select(["Do your best.", "Quit it, kid."])

    if choice == 1 do
      ctx
      |> mes("[Strife]")
      |> mes(
        "Yes, yes of course! Someday, I'll even be as strong as you! When that day comes, I hope that we can train together!"
      )
      |> close()
    else
      ctx
      |> mes("[Strife]")
      |> mes("Wha--?")
      |> mes("Fine! But I'm gonna keep on training, and we'll see who gets the last laugh!")
      |> close()
    end
  end

  defp novice_dream_intro(ctx) do
    ctx
    |> mes("[Strife]")
    |> mes("Whew!")
    |> mes("Man oh man...")
    |> mes("I'm gonna be such")
    |> mes("an awesome Knight!")
    |> next()
    |> mes("[Strife]")
    |> mes("I know, I know...")
    |> mes(
      "First, I gotta be a Swordie. But if I keep practicing, I can become an awesome Swordie. And then after that..."
    )
    |> next()
    |> mes("[Strife]")
    |> mes("I'll be the most")
    |> mes("awesomest Knight around!")
    |> mes("It's... It's my most precious dream.")
    |> next()
  end
end
