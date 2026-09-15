defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.MerchantDaven do
  @moduledoc """
  Discusses Geffen's magic users, economy, and his own vanity.

  ## Behavior

  - Tailors his magic and economy remarks to Mages and Blacksmiths.
  - Reacts differently when a Swordman threatens him with Magnum Break.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 79,
        y: 76,
        dir: 2,
        sprite: 120,
        name: "Merchant Daven",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Merchant Daven]")
      |> mes("I remember Geffen")
      |> mes("back when it was boring. ")
      |> next()
      |> mes("[Merchant Daven]")
      |> mes("But now there are Mages and Wizards, and a flourishing")
      |> mes("economy in this town!")
      |> next()
      |> select(["Mages...?", "Economy?", "Who are you?"])

    ctx
    |> answer_topic(choice)
    |> close()
  end

  defp answer_topic(ctx, 1) do
    if base_job(ctx) == :mage do
      ctx
      |> mes("[Merchant Daven]")
      |> mes(
        "Mages are wielders of magic. But you would know more about that topic now, wouldn't you?"
      )
    else
      ctx
      |> mes("[Merchant Daven]")
      |> mes(
        "Mages and Wizards are always carrying books and studying magic. That's just the way they are."
      )
      |> next()
      |> mes("[Merchant Daven]")
      |> mes(
        "There's a Magic School in the NorthWest part of the city for Novices interested in becoming Mages. There, they can learn the basics of magic."
      )
      |> next()
      |> mes("[Merchant Daven]")
      |> mes(
        "After becoming well experienced in the use of magic, Mages can become qualified to become Wizards."
      )
      |> next()
      |> mes("[Merchant Daven]")
      |> mes(
        "Wizards have access to more powerful and destructive magic spells than Mages. Mages can apply to become Wizards at the top of Geffen Tower."
      )
    end
  end

  defp answer_topic(ctx, 2) do
    if class(ctx) == :blacksmith do
      ctx
      |> mes("[Merchant Daven]")
      |> mes("The economy...?")
      |> mes(
        "Why, that's all thanks to Blacksmiths! But you should know that already, shouldn't you?"
      )
    else
      ctx
      |> mes("[Merchant Daven]")
      |> mes(
        "Well, I guess you can thank the Blacksmiths for the economy here in Geffen. Sure, they always dirty, sweaty, smelly and talk kind of rudely..."
      )
      |> next()
      |> mes("[Merchant Daven]")
      |> mes(
        "But they're hard working people. Also, the ores they refine and the weapons they create are high in demand."
      )
      |> next()
      |> mes("[Merchant Daven]")
      |> mes(
        "Adventurers pay Blacksmiths lots of their hard earned zeny for the high quality weapons that only they can create."
      )
    end
  end

  defp answer_topic(ctx, 3) do
    {ctx, _choice} =
      ctx
      |> mes("[Merchant Daven]")
      |> mes("Me? I'm the world's most prettiest street merchant. Heh heh~")
      |> next()
      |> select(["...^EE0000Magnum Break^000000!"])

    if class(ctx) == :swordman do
      ctx
      |> mes("[Merchant Daven]")
      |> mes("Whoa, whoa!")
      |> mes("It was just a joke!")
      |> mes("Forgive me!")
    else
      ctx
      |> mes("[Merchant Daven]")
      |> mes("Magnum Break?")
      |> mes("But you can't even do that, can you?")
    end
  end

  defp answer_topic(ctx, _choice), do: ctx
end
