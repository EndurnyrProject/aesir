defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Berling do
  @moduledoc """
  Berling helps the player find the last dwarf in the Brisingamen seal quest.

  ## Behavior

  - Explains his part in the necklace and teaches the song needed to approach Grer.
  - Repeats the song and hides after speaking to the player.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected the late-quest hide target from `OnBerling#1` to `Berling#1`.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_09",
        x: 87,
        y: 129,
        dir: 3,
        sprite: 826,
        name: "Berling",
        scope: :shared,
        unique_name: "Berling#1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    hideonnpc(ctx, "Berling#1")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :god_brising, 0) > 44 ->
        ctx
        |> mes("[Berling]")
        |> mes(
          "You're the one that's awakened us? Hahaha, perhaps that's a sign we may see Freya again! Hahahaha!"
        )
        |> next()
        |> mes("[Berling]")
        |> mes(
          "We are indebted to you for reviving us. Okay, I know what you want, and will help you obtain the power of the gods."
        )
        |> close2()
        |> hideonnpc("Berling#1")

      get_char_var(ctx, :god_brising, 0) == 43 ->
        meet_berling(ctx)

      get_char_var(ctx, :god_brising, 0) == 44 ->
        ctx
        |> mes("[Berling]")
        |> mes(
          "Did you already forget the lyrics? Let me tell them to you again, so don't forget this time."
        )
        |> next()
        |> sing_song()
        |> close2()
        |> hideonnpc("Berling#1")

      true ->
        hideonnpc(ctx, "Berling#1")
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp meet_berling(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Berling]")
      |> mes("What the...?")
      |> mes("It's a human?!")
      |> mes("What do you want?")
      |> mes("Wh-who are you?")
      |> next()
      |> select(["Dvalin wants you to wake up!", "Tell me who you are first!"])

    case choice do
      1 -> explain_necklace(ctx)
      2 -> ask_his_name(ctx)
      _ -> ctx
    end
  end

  defp explain_necklace(ctx) do
    ctx =
      ctx
      |> mes("[Berling]")
      |> mes("Dvalin?!")
      |> mes("You mean my brother!")
      |> mes("But he can only be revived if Alfrik is revived. What happened?")
      |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Umm...")
      |> mes("Let me explain...")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(
        "...So I guess I need to wake up all four of you dwarves so that Brisingamen, which holds Freya's power, can be made again."
      )
      |> next()
      |> mes("[Berling]")
      |> mes(
        "Oh! Say that name once again! Freya, the goddess who took my body and soul! Did you just say you want to make her necklace?"
      )
      |> next()
      |> mes("[Berling]")
      |> mes("Hahahaha!")
      |> mes("Stop joking around.")
      |> mes("The Brisingamen is")
      |> mes("a one of a kind")
      |> mes("masterpiece!")
      |> next()
      |> select(["I don't mean the original one, but..."])

    case choice do
      1 -> teach_song(ctx)
      _ -> ctx
    end
  end

  defp teach_song(ctx) do
    ctx
    |> mes("[Berling]")
    |> mes("Ah, now I see! You want a replica that has roughly the same power.")
    |> mes("A Brisingamen used by humans!")
    |> mes("Very clever!")
    |> next()
    |> mes("[Berling]")
    |> mes(
      "I, on the other hand, do not desire power. I would be happy to own but a strand of my goddess' hair."
    )
    |> next()
    |> mes("[Berling]")
    |> mes("Oh Freya...")
    |> mes(
      "The more of her beauty exists in this world, the happier I'll be. I'm more than willing to help you recreate this memento of Freya."
    )
    |> next()
    |> mes("[Berling]")
    |> mes(
      "Now, please go and find the last one of my brothers! Poor Grer, perhaps he is still digging silver in that mine for her..."
    )
    |> next()
    |> mes("[Berling]")
    |> mes(
      "Go and find Grer. I will give you Freya's golden teardrop, but he might have revived on his own..."
    )
    |> next()
    |> mes("[Berling]")
    |> mes("If he doesn't trust you, sing this song. You must remember each")
    |> mes("and every word...")
    |> next()
    |> sing_song()
    |> next()
    |> mes("[Berling]")
    |> mes(
      "Memorize all five lines of this song exactly. Now take this golden teardrop and please seek out Grer."
    )
    |> specialeffect2(:impositio)
    |> set_char_var(:god_brising, 44)
    |> close2()
    |> hideonnpc("Berling#1")
  end

  defp sing_song(ctx) do
    ctx
    |> mes("[Berling]")
    |> mes("^4d4dffNo jewel in the world can compare.^000000")
    |> next()
    |> mes("[Berling]")
    |> mes("^4d4dffOur masterpiece made from love.^000000")
    |> next()
    |> mes("[Berling]")
    |> mes("^4d4dffShe wanted the dazzling necklace.^000000")
    |> next()
    |> mes("[Berling]")
    |> mes("^4d4dffWe wanted the goddess of beauty.^000000")
    |> next()
    |> mes("[Berling]")
    |> mes("^4d4dffOur happiest times were with her.^000000")
  end

  defp ask_his_name(ctx) do
    ctx =
      ctx
      |> mes("[Berling]")
      |> mes("Where the hell")
      |> mes("did you come from?")
      |> mes("I, Berling, refuse to")
      |> mes("give my name to a rude,")
      |> mes("ill-bred human like yourself!")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Wait...")
    |> mes("Your name")
    |> mes("is Berling?")
    |> next()
    |> mes("[Berling]")
    |> mes("Baaaaahhh!")
    |> mes("Quiet you!")
    |> mes("Mind your own")
    |> mes("business!")
    |> close2()
    |> hideonnpc("Berling#1")
  end
end
