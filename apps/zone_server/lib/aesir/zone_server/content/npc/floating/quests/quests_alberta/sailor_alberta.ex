defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsAlberta.SailorAlberta do
  @moduledoc """
  Gotanblue tells his story and offers passage to Turtle Island.

  ## Behavior

  - Recounts the expedition and offers passage for 10,000 zeny after the quest begins.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 244,
        y: 118,
        dir: 4,
        sprite: 709,
        name: "Sailor",
        unique_name: "Sailor#tur",
        scope: :renewal
      },
      %{
        map: "alberta",
        x: 247,
        y: 122,
        dir: 4,
        sprite: 709,
        name: "Sailor",
        unique_name: "Sailor#tur",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(get_char_var(ctx, :TURTLE, 0)) or
         Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 65536)) do
      talk_about_island(ctx)
    else
      ctx
      |> mes("[Gotanblue]")
      |> mes("Ahhhh...!")
      |> mes(
        "Just look at that ocean! It covers the earth as far as the eye can see. Tell me that's not one of the most beautiful things you've ever seen..."
      )
      |> close()
    end
  end

  defp talk_about_island(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gotanblue]")
      |> mes("Heh...")
      |> mes("Your eyes...")
      |> mes(
        "I can tell you're curious about Turtle Island. I guess you must have been talking to that drunken old man!"
      )
      |> next()
      |> select(["Do you know about Turtle Island?", "How can I get there?", "Stop talking."])

    case choice do
      1 -> tell_story(ctx)
      2 -> offer_passage(ctx)
      3 -> stop_talking(ctx)
      _ -> ctx
    end
  end

  defp tell_story(ctx) do
    ctx
    |> mes("[Gotanblue]")
    |> mes("Turtle Island...?")
    |> mes(
      "Well, first I think it's fair to warn you that Turtle Island took the lives of my buddies. That's right, I was part of ^3355FFJornadan Niliria^000000's crew."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "We wanted to find out if the legends about that island were true, so we left everything behind to learn the truth."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Jornadan Niliria was one of the greatest treasure hunters ever, and he gathered men for his crew from around the globe. I'm proud to say that each member of our crew was the best in his field."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "I happened to be the best at navigating. I was only twenty, but I was still invited to his team. It was such an honor to be accepted as an equal amongst these great men."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Anyway, our biggest clue about Turtle Island's location hinted that it was near Alberta, so our voyage began from here."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "We sailed day and night, drifting for weeks, until one day, we were surrounded by an incredibly thick fog. We had no idea of which direction we were going and the mist wouldn't clear."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "But none of us had any regrets and we just kept moving onward. There would be no turning back!"
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Finally, a coral reef sudden appeared and we couldn't steer away from it. Our ship was critically damaged. But when the fog cleared, we saw that we had finally arrived at Turtle Island! It was real!"
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "After we made camp on shore and explored the island, we learned something quite remarkable."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "There was a man who had actually made it to Turtle Island before us. His records, however, never reached Rune-Midgarts. He was a great swordmaster known simply as ^3355FFOne^000000."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "According to his records, he had traveled alone to find Turtle Island and made it by himself. But we couldn't find any sign of him anywhere..."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "As we explored Turtle Island further, we learned that not only was it abundant with treasure, but that it also held an item of great interest."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "From the first explorer's record, some kind of amazing ^3355FFjewel fragment^000000 was mentioned."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "He had traveled to Turtle Island with the purpose of discovering secrets to the sword arts, and stumbled upon a jewel he claimed was the most beautiful in the world."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "By the ^3355FFOne^000000's records, we were able to thoroughly explore all to be seen on Turtle Island. However..."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Even after months of searching, we could never find a trace of the jewel fragment. Eventually, we had to give up on our search."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Finally, we packed our things to leave the island. But then, as we were traveling at sea, we encountered a thick, blinding fog once again."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "We spent a month trying to steer through that mist. When we finally sailed out of that mist, we saw that we had arrived at the other side of Turtle Island!"
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Our spirits were crushed!! We tried again and again to leave that place, and spent nearly a year trying to leave but we kept winding up at Turtle Island's shores."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "As we struggled with the fog, we lost our comrades one by one. In the end, Jornadan, the drunken old man you met, and myself were the only ones who were able to return home to Alberta."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "We were the only ones who did not give in to despair, and doggedly held onto our hopes. Still, it was by pure luck that we found a way back to Rune-Midgarts."
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes(
      "Well, that's my story. You know, if you want to learn more about Turtle Island, why don't you speak to the scholar on the eastern port of Alberta?"
    )
    |> next()
    |> mes("[Gotanblue]")
    |> mes("Heh heh...")
    |> mes("I'm sure he can tell give you details that even I wouldn't be able to provide...")
    |> close()
  end

  defp offer_passage(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Gotanblue]")
      |> mes(
        "After my story of Turtle Island, you're still not afraid of going? I'm impressed! Alright then..."
      )
      |> next()
      |> mes("[Gotanblue]")
      |> mes(
        "If you wish for me to guide you there, I will charge you 10,000 zeny. I'm the only navigator that can guide you there and back safely."
      )
      |> next()
      |> select(["Turtle island -> 10000 zeny", "Cancel"])

    if choice == 1 do
      if zeny(ctx) > 9999 do
        sail(ctx)
      else
        insufficient_zeny(ctx)
      end
    else
      ctx
      |> mes("[Gotanblue]")
      |> mes("Alright then...")
      |> mes(
        "Well, if the spirit of adventure should happen to grab you, I will be here waiting."
      )
      |> close()
    end
  end

  defp sail(ctx) do
    ctx
    |> mes("[Gotanblue]")
    |> mes("Alright!!")
    |> mes(
      "You've made your choice! With my experience, we will arrive without fail! I appreciate your spirit!"
    )
    |> next()
    |> mes("^3355FF*Choo Choo*^000000")
    |> pay_zeny(10000)
    |> warp("tur_dun01", 157, 39)
    |> close()
  end

  defp insufficient_zeny(ctx) do
    ctx
    |> mes("[Gotanblue]")
    |> mes("Hmmm...")
    |> mes(
      "Sorry, but you don't have enough zeny. I hope you understand that I can let my expertise and experience be undervalued..."
    )
    |> close()
  end

  defp stop_talking(ctx) do
    ctx
    |> mes("[Gotanblue]")
    |> mes("Heh...")
    |> next()
    |> mes("[Gotanblue]")
    |> mes("Come back whenever you feel you're ready to hear my story, will you?")
    |> close()
  end
end
