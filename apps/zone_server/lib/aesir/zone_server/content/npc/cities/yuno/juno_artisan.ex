defmodule Aesir.ZoneServer.Content.Npc.Cities.Yuno.JunoArtisan do
  @moduledoc """
  Describes notable equipment, items, and food associated with Juno.

  ## Behavior

  - Lets the player ask about powerful equipment, unique items, or traditional food.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KitsuneStarwind
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 157,
        y: 205,
        dir: 4,
        sprite: 54,
        name: "Juno Artisan",
        scope: :shared,
        unique_name: "Juno Artisan#juno"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Artisan]")
      |> mes("*Mumble mumble...*")
      |> next()
      |> mes("[Artisan]")
      |> mes(
        "Oh, hello there. Let me introduce myself. I am an artisan who tries to succeed the rights and duties of item makers in Juno."
      )
      |> next()
      |> select([
        "About Powerful Equipment",
        "About Unique Items",
        "About Authentic Food",
        "End Conversation"
      ])

    case choice do
      1 -> explain_equipment(ctx)
      2 -> explain_scroll(ctx)
      3 -> explain_food(ctx)
      4 -> end_conversation(ctx)
      _ -> ctx
    end
  end

  defp explain_equipment(ctx) do
    ctx
    |> mes("[Artisan]")
    |> mes(
      "Let me suggest the ^3355FFHoly Guard^000000 and ^3355FFHoly Avenger^000000 which are special items for Crusaders."
    )
    |> next()
    |> mes("[Artisan]")
    |> mes(
      "These pieces of equipment are very light and have sufficient abilities. They also happen to possess holy power."
    )
    |> next()
    |> mes("[Artisan]")
    |> mes(
      "Therefore, this equipment is more powerful over some kinds of monsters such as Ghosts or the Undead."
    )
    |> next()
    |> mes("[Artisan]")
    |> mes(
      "However it is rumored that only a few chosen Crusaders are able to obtain those items due of their rarity."
    )
    |> close()
  end

  defp explain_scroll(ctx) do
    ctx
    |> mes("[Artisan]")
    |> mes(
      "It looks like a simple scroll marked with concentric circles and a star. Although the ^FF3355Worn-Out Magic Scroll^000000 is very old, it's wanted by many Sages for research purposes."
    )
    |> next()
    |> mes("[Artisan]")
    |> mes("It seems you can use that item when you chant a high-level magic spell.")
    |> close()
  end

  defp explain_food(ctx) do
    ctx
    |> mes("[Artisan]")
    |> mes(
      "^3355FFRice Cake^000000! Yes, it's a traditional food that's favored by a lot of people. There's a lot of nostalgic memories of old fashioned markets that are connected to the Rice Cake."
    )
    |> next()
    |> mes("[Artisan]")
    |> mes("Ahhh~")
    |> mes("I wish I could eat a bit of Rice Cake right now.")
    |> close()
  end

  defp end_conversation(ctx) do
    ctx
    |> mes("[Artisan]")
    |> mes(
      "Although Juno is known as a city of Sages, I hope you understand that ordinary people live and prosper here as well. Please enjoy the unique atmosphere that Juno has to offer."
    )
    |> close()
  end
end
