defmodule Aesir.ZoneServer.Content.Npc.Quests.Monstertamers.MunakSGrandma do
  @moduledoc """
  An old woman in Comodo who tells the story of the granddaughter she lost to the village
  deity, and trades a keepsake for a Danggie and the granddaughter's diary.

  ## Behavior

  - Tells the story only while the player carries a Danggie (1558); otherwise grieves and closes
  - On the second page, offers to read the granddaughter's diary to the player
  - Without the diary (901), closes after saying she cannot remember it
  - Declining to hand over the diary and Danggie closes without taking anything
  - Handing over the diary (901) and the Danggie (1558) makes her read it and give the
    keepsake (659)

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Darkchild
    - x[tsk]
    - Lupus
    - Silent
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "comodo",
        x: 112,
        y: 182,
        dir: 0,
        sprite: 103,
        name: "Munak's Grandma",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if count_item(ctx, 1558) > 0 do
      tell_story(ctx)
    else
      grieve(ctx)
    end
  end

  @spec tell_story(Ctx.t()) :: Ctx.t()
  defp tell_story(ctx) do
    ctx =
      ctx
      |> mes("[Munak's grandma]")
      |> mes("Oh my...")
      |> mes("Have you seen my granddaughter,")

    ctx =
      if male?(ctx) do
        mes(ctx, "boy? My poor granddaughter")
      else
        mes(ctx, "young lady? My poor granddaughter")
      end

    {ctx, choice} =
      ctx
      |> mes("has been missing...")
      |> next()
      |> mes("[Munak's Grandma]")
      |> mes("I can't remember exactly when it")
      |> mes("was, but when I lived in Payon, I")
      |> mes("had a cute granddaughter. She")
      |> mes("was really happy when I made her")
      |> mes("hair like ^000077Danggie^000000...")
      |> next()
      |> mes("[Munak's Grandma]")
      |> mes("She was alwaying working with the")
      |> mes("village chief... She was such a sweet")
      |> mes("girl, and always got along with")
      |> mes("chief's son...")
      |> next()
      |> mes("[Munak's Grandma]")
      |> mes("But one day our deity became angry")
      |> mes("and cursed the chief's son with a")
      |> mes("sickness! The village had to offer")
      |> mes("my granddaughter to him as a")
      |> mes("companion to lift the curse...")
      |> next()
      |> mes("[Munak's Grandma]")
      |> mes("The chief's son regained his")
      |> mes("health, but I lost my")
      |> mes("granddaughter! I can't look at him")
      |> mes("and not think of her, so I tried to")
      |> mes("leave my misery behind and came")
      |> mes("here to Comodo...")
      |> next()
      |> select(["Oh come on! Cheer up!", "Um, is this diary...?"])

    case choice do
      1 -> cheer_up(ctx)
      2 -> ask_for_diary(ctx)
      _ -> ctx
    end
  end

  @spec grieve(Ctx.t()) :: Ctx.t()
  defp grieve(ctx) do
    ctx
    |> mes("[Munak's Grandma]")
    |> mes("My own granddaughter...")
    |> mes("Why did she have to leave...?")
    |> close()
  end

  @spec cheer_up(Ctx.t()) :: Ctx.t()
  defp cheer_up(ctx) do
    ctx
    |> mes("[Munak's Grandma]")
    |> mes("It seems my granddaughter haunts my")
    |> mes("dreams every night. I believe I've")
    |> mes("been trying to cheer up for years")
    |> mes("now...")
    |> close()
  end

  @spec ask_for_diary(Ctx.t()) :: Ctx.t()
  defp ask_for_diary(ctx) do
    if count_item(ctx, 901) > 0 do
      offer_to_read_diary(ctx)
    else
      cannot_remember(ctx)
    end
  end

  @spec cannot_remember(Ctx.t()) :: Ctx.t()
  defp cannot_remember(ctx) do
    ctx
    |> mes("[Munak's Grandma]")
    |> mes("What? A diary? What's that diary...?")
    |> mes("I don't... I can't remember, oh my...")
    |> next()
    |> mes("[Munak's Grandma]")
    |> mes("I really wish I could make her hair")
    |> mes("into a ^000077Danggie^000000 again. I really")
    |> mes("wish... Oh, oh my granddaughter...")
    |> close()
  end

  @spec offer_to_read_diary(Ctx.t()) :: Ctx.t()
  defp offer_to_read_diary(ctx) do
    ctx =
      ctx
      |> mes("[Munak's Grandma]")
      |> mes("Oh god!")
      |> mes("It's my granddaughter's diary!")
      |> mes("Th-This is her writing! Oh my...!")
      |> next()
      |> mes("[Munak's Grandma]")

    ctx =
      if male?(ctx) do
        mes(ctx, "Young man... I'll read this to you if")
      else
        mes(ctx, "Young lady... I'll read this to you if")
      end

    {ctx, choice} =
      ctx
      |> mes("you give it to me with a Danggie,")
      |> mes("please. I no longer have anything")
      |> mes("that belonged to her now...")
      |> next()
      |> select(["No way.", "Ok, I will."])

    case choice do
      1 -> refuse(ctx)
      2 -> read_diary(ctx)
      _ -> ctx
    end
  end

  @spec refuse(Ctx.t()) :: Ctx.t()
  defp refuse(ctx) do
    ctx =
      ctx
      |> mes("[Munak's Grandma]")
      |> mes("Oh...?")

    ctx =
      if male?(ctx) do
        ctx
        |> mes("Alright, young man.")
        |> mes("Thank you anyway.")
      else
        ctx
        |> mes("Thank you anyway,")
        |> mes("young lady")
      end

    ctx
    |> next()
    |> mes("[Munak's Grandma]")
    |> mes("It's alright...")
    |> mes("I can only hope that the deity is")
    |> mes("taking good care of her!")
    |> close()
  end

  @spec read_diary(Ctx.t()) :: Ctx.t()
  defp read_diary(ctx) do
    ctx =
      ctx
      |> delitem(1558, 1)
      |> delitem(901, 1)
      |> mes("[Munak's Grandma]")

    ctx =
      if male?(ctx) do
        ctx
        |> mes("Oh!")
        |> mes("Thank you,")
        |> mes("young man~!")
      else
        ctx
        |> mes("Goodness!")
        |> mes("Thank you,")
        |> mes("young lady...")
      end

    ctx
    |> next()
    |> mes("[Munak's Grandma]")
    |> mes("Alright...")
    |> mes("I'll read this.")
    |> mes("Let me see...")
    |> next()
    |> mes("[Munak's Grandma]")
    |> mes("It seems that my granddaughter was")
    |> mes("treated by the chief like his own")
    |> mes("child! There are so many happy")
    |> mes("memories in this book!")
    |> next()
    |> give_item(659, 1)
    |> mes("[Munak's Grandma]")
    |> mes("Oh, thank you. I now have a good")
    |> mes("keepsake of my granddaughter. Thank")
    |> mes("you so much! May God-Poing bless")
    |> mes("you!")
    |> close()
  end

  # rAthena spells this `Sex == SEX_MALE`. The transpiler renders the SEX_MALE constant as
  # a char-var read, which always answers 0 and inverted the branch, so compare against the
  # value `sex/1` returns for a male character instead.
  @spec male?(Ctx.t()) :: boolean()
  defp male?(ctx), do: sex(ctx) == 1
end
