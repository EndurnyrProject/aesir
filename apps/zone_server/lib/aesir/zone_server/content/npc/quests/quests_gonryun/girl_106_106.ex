defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Girl106106 do
  @moduledoc """
  Lyroo is a sick girl whose cure is needed to repair the broken sword.

  ## Behavior

  - Describes her symptoms while the player seeks a cure.
  - Takes the medicine and recovers as the quest progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 106,
        y: 106,
        dir: 7,
        sprite: 716,
        name: "Girl",
        scope: :shared,
        unique_name: "Girl#gnbs2"
      }
    ]

  @aloebera 606

  @impl true
  def on_talk(ctx) do
    sword = get_char_var(ctx, :b_sword, 0)

    cond do
      sword < 20 ->
        ctx
        |> mes("[Lyroo]")
        |> mes("Ah...Ah....")
        |> mes("Ah...Hi.......")
        |> next()
        |> mes("^0000FFThis girl seems to be in serious pain...^000000")
        |> close()

      sword < 24 ->
        ctx
        |> mes("[Lyroo]")
        |> mes("Aaa....Aaa....")
        |> mes("you...you....")
        |> mes("you are the....one...")
        |> mes("who will....cure....")
        |> mes("...me? Aa....")
        |> next()
        |> mes("[Lyroo]")
        |> mes("..tha... thank you....")
        |> next()
        |> mes("^0000FFBetter stop talking to her and")
        |> mes("hurry and find a cure.^000000")
        |> close()

      sword in 24..26 ->
        symptoms(ctx)

      sword == 27 ->
        medicine(ctx)

      true ->
        recovered(ctx)
    end
  end

  defp symptoms(ctx) do
    ctx = ctx |> mes("[Lyroo]") |> mes("Ahh...ahh....")

    ctx =
      mes(
        ctx,
        if(sex(ctx) == 0,
          do: "It's ..you.. pretty...sister..",
          else: "It's ..you.. handsome...brother.."
        )
      )

    {ctx, choice} =
      ctx
      |> mes("Ahh...heh heh...")
      |> next()
      |> select(["Ask about her health condition.", "Talk to her for a while."])

    cond do
      choice != 1 ->
        ctx
        |> mes("[Lyroo]")
        |> mes("Ahh........")
        |> mes("I..want to ...talk to...you..")
        |> mes("but.... sorry....")
        |> falls_asleep()

      Enum.random(1..4) == 3 ->
        ctx
        |> mes("[Lyroo]")
        |> mes("Uh....umm...?")
        |> mes("Umm... I...")
        |> mes("I can't talk...too long..")
        |> mes("So...listen....")
        |> mes("carefully..please...")
        |> next()
        |> mes("[Lyroo]")
        |> mes("^0030FFMy body...repeatedly turns cold and")
        |> mes("hot... I'm not sweating at all...")
        |> mes("....But I'm paralyzed...often")
        |> mes("often..and...my heart beats...")
        |> mes("...irregularly.^000000")
        |> next()
        |> mes("[Lyroo]")
        |> mes("Ahh...hah~")
        |> mes("...........")
        |> falls_asleep()

      true ->
        ctx
        |> mes("[Lyroo]")
        |> mes("I...am...so...")
        |> mes("...tired.")
        |> mes(".............")
        |> falls_asleep()
    end
  end

  defp falls_asleep(ctx) do
    ctx
    |> next()
    |> mes("^0000FFShe seems to have fallen asleep.^000000")
    |> close()
  end

  defp medicine(ctx) do
    ctx = ctx |> mes("[Lyroo]") |> mes("uh...umm?")

    ctx =
      mes(
        ctx,
        if(sex(ctx) == 0,
          do: "Ah....It's you, pretty sister...",
          else: "Ah....It's you, handsome brother..."
        )
      )

    {ctx, choice} =
      ctx
      |> mes("Uhm? what is that you have?")
      |> next()
      |> select(["It's nothing.", "It's your medicine."])

    if choice == 1 do
      ctx
      |> mes("[Lyroo]")
      |> mes("Oh...")
      |> mes("Alright...")
      |> mes("...")
      |> next()
      |> mes("^0000FFYou really should be giving her the medicine.^000000")
      |> close()
    else
      ctx
      |> mes("[Lyroo]")
      |> mes("Ah!")
      |> mes("You found the medicine~!")
      |> mes("I'm...so relieved...")
      |> next()
      |> mes("^0000FFYou gave her the medicine you")
      |> mes("received from Cylrnel.")
      |> mes("After taking the medicine, Lyroo")
      |> mes("fell asleep.^000000")
      |> delitem(@aloebera, 1)
      |> set_char_var(:b_sword, 28)
      |> close()
    end
  end

  defp recovered(ctx) do
    ctx = ctx |> mes("[Lyroo]") |> mes("Heehehe...")

    ctx =
      mes(
        ctx,
        if(sex(ctx) == 0, do: "Thank you my pretty sister.", else: "Thank you handsome brother~")
      )

    ctx |> mes("I'll get my health back") |> mes("and be a strong girl!") |> close()
  end
end
