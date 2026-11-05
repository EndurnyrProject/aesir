defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.MedicineChest do
  @moduledoc """
  The medicine chest reveals a hidden poem on the cottage’s sealed paper.

  ## Behavior

  - Offers colored liquids, with blue revealing the poem and advancing its discovery flag.
  - Allows the discovered poem to be read again.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_vila",
        x: 123,
        y: 170,
        dir: 0,
        sprite: 111,
        name: "Medicine Chest",
        scope: :shared,
        unique_name: "Medicine Chest#khp1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    poem = get_char_var(ctx, :KHCottagePoem2, 0)
    quest = get_char_var(ctx, :KielHyreQuest, 0)

    cond do
      poem < 1 and quest < 30 ->
        ctx
        |> mes("^3355FFThis medicine cabinet")
        |> mes("is filled with bottles of")
        |> mes("various colors. What kind")
        |> mes("of medicine can be found here?^000000")
        |> close()

      poem == 1 and quest < 30 ->
        investigate_ink(ctx)

      poem >= 2 or quest >= 30 ->
        offer_poem(ctx)

      true ->
        ctx
    end
  end

  defp investigate_ink(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis medicine cabinet")
      |> mes("is filled with bottles of")
      |> mes("various colors. What kind")
      |> mes("of medicine can be found here?^000000")
      |> next()
      |> mes("^3355FFWait, you have a blank piece")
      |> mes("of paper with the Kiel Hyre")
      |> mes("Foundation seal! It's strange")
      |> mes("that the seal was put on a blank")
      |> mes("piece of paper. Maybe something")
      |> mes("is written on it with special ink?^000000")
      |> next()
      |> mes("^3355FFIt's a crazy hunch, but")
      |> mes("maybe, just maybe, you can")
      |> mes("use something inside this")
      |> mes("medicine cabinet that will")
      |> mes("reveal any invisible ink")
      |> mes("written on this document!^000000")
      |> next()
      |> select(["What? That's crazy!", "Of course! Let's try it!"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFSorry.")
        |> mes("I thought it")
        |> mes("was a good idea...^000000")
        |> close()

      2 ->
        choose_liquid(ctx)

      _ ->
        ctx
    end
  end

  defp choose_liquid(ctx) do
    {ctx, choice} =
      select(ctx, [
        "Try Red Liquid",
        "Try Blue Liquid",
        "Try Yellow Liquid",
        "Try Green Liquid",
        "Cancel"
      ])

    case choice do
      1 ->
        ctx |> set_local(:"KHPotionColor$", "red") |> try_other_liquid()

      2 ->
        reveal_poem(ctx)

      3 ->
        ctx |> set_local(:"KHPotionColor$", "yellow") |> try_other_liquid()

      4 ->
        ctx |> set_local(:"KHPotionColor$", "green") |> try_other_liquid()

      5 ->
        ctx
        |> mes("^3355FFNever mind.")
        |> mes("This idea sounds")
        |> mes("too crazy to work...")
        |> mes("like puttting a man")
        |> mes("on the moon. Can you")
        |> mes("believe that hogwash?^000000")
        |> close()

      _ ->
        ctx
    end
  end

  defp try_other_liquid(ctx) do
    ctx
    |> mes("^3355FFYou tried sprinkling")
    |> mes("the #{get_local(ctx, :"KHPotionColor$", "")} liquid from the")
    |> mes("medicine cabinet onto")
    |> mes("the blank paper with the")
    |> mes("Kiel Hyre Foundation seal.")
    |> mes("However, nothing happened...^000000")
    |> close()
  end

  defp reveal_poem(ctx) do
    ctx
    |> mes("^3355FFIt works!")
    |> mes("The blue liquid is")
    |> mes("revealing small text")
    |> mes("written on the paper.")
    |> mes("It looks like some")
    |> mes("kind of long poem...^000000")
    |> next()
    |> mes("[Poem]")
    |> mes("The first snake is made of")
    |> mes("steel, but I used my rage")
    |> mes("to destroy it. The second")
    |> mes("snake is made of magic,")
    |> mes("but my love pierced its heart.")
    |> next()
    |> mes("[Poem]")
    |> mes("The third snake is flesh")
    |> mes("and blood, but my hope")
    |> mes("defeated it in the end.")
    |> mes("However, the fourth and")
    |> mes("final snake is formless, and")
    |> mes("no one knows its appearance.")
    |> next()
    |> mes("[Poem]")
    |> mes("I cast my despair to the air,")
    |> mes("but nobody knows if it killed")
    |> mes("the snake. I am merely ^0000FFa little")
    |> mes("lost devil^000000 with four swords and")
    |> mes("four snakes, searching for that")
    |> mes("girl in the darkness.")
    |> next()
    |> mes("^3355FFThis is a very")
    |> mes("strange poem. What")
    |> mes("could it possibly mean?^000000")
    |> set_char_var(:KHCottagePoem2, 2)
    |> close()
  end

  defp offer_poem(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis is where you poured")
      |> mes("some blue liquid to read")
      |> mes("a poem written in invisible")
      |> mes("ink on the blank piece of paper")
      |> mes("with the Kiel Hyre Foundation")
      |> mes("seal. Would you like read it?^000000")
      |> next()
      |> select(["No time!", "Read"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou're running out of")
        |> mes("time! For now, it would")
        |> mes("be best for you to search")
        |> mes("every inch of this cottage.^000000")
        |> close()

      2 ->
        reread_poem(ctx)

      _ ->
        ctx
    end
  end

  defp reread_poem(ctx) do
    ctx
    |> mes("[Poem]")
    |> mes("The first snake is made of")
    |> mes("steel, but I used my rage")
    |> mes("to destroy it. The second")
    |> mes("snake is made of magic,")
    |> mes("but my love pierced its heart.")
    |> next()
    |> mes("[Poem]")
    |> mes("The third snake is flesh")
    |> mes("and blood, but my hope")
    |> mes("defeated it in the end.")
    |> mes("However, the fourth and")
    |> mes("final snake is formless, and")
    |> mes("no one knows it's appearance.")
    |> next()
    |> mes("[Poem]")
    |> mes("I cast my despair to the air,")
    |> mes("but nobody knows if it killed")
    |> mes("the snake. I am merely a ^3355FFlittle^000000")
    |> mes("^3355FFlost devil^000000 with four swords and")
    |> mes("four snakes, searching for that")
    |> mes("girl in the darkness.")
    |> close()
  end
end
