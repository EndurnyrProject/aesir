defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGeffen.Eric do
  @moduledoc """
  Eric, in Geffen, builds his late grandfather's Headset design from materials the player brings.

  ## Behavior

  - Tells the story of his grandfather's schematic and lists the materials: 40 Steel,
    1 Oridecon, 1 Alcohol and 1 Coal.
  - With all materials, takes them and gives a Headset; otherwise asks the player to keep
    looking.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Samuray22
    - Lupus
    - Silent
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "geffen_in", x: 30, y: 71, dir: 4, sprite: 83, name: "Eric", scope: :shared}]

  @steel 999
  @oridecon 984
  @alcohol 970
  @coal 1003
  @headset 5001

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Eric]")
      |> mes("Please listen")
      |> mes("to my story")
      |> mes("of my blessed")
      |> mes("grandfather.")
      |> next()
      |> select(["Talk", "Ask about Items needed", "Manufacture", "Quit"])

    case choice do
      1 -> tells_his_story(ctx)
      2 -> lists_the_materials(ctx)
      3 -> builds_the_headset(ctx)
      4 -> farewell(ctx)
      _ -> ctx
    end
  end

  defp tells_his_story(ctx) do
    ctx
    |> mes("[Eric]")
    |> mes(
      "My Grandfather, who passed away a few years ago, was special to me. He always stayed with me, and took care of me. He was much better than my old man, who was always busy working."
    )
    |> next()
    |> mes("[Eric]")
    |> mes(
      "To me, Grandfather's library was always like a fantasy land where I could escape. I spent most of my time there."
    )
    |> next()
    |> mes("[Eric]")
    |> mes(
      "I learned a lot of things from his books in the Library. Grandfather was interested in Alchemy and Music, and his Library was filled with many mysterious old books."
    )
    |> next()
    |> mes("[Eric]")
    |> mes("One day...")
    |> mes("As usual, I went to the Library and discovered an interesting schematic.")
    |> next()
    |> mes("[Eric]")
    |> mes(
      "It showed some instrument which looked like Ear Muffs that, when worn on the head, could transmit music or whispers to the ears through a thin wire."
    )
    |> next()
    |> mes("[Eric]")
    |> mes("I guess...")
    |> mes(
      "It is my grand father's unfinished work. I met a few Alchemists and asked them to produce it, but they rejected my offer..."
    )
    |> next()
    |> mes("[Eric]")
    |> mes(
      "In the end, I thought 'I've gotta make it myself.' So I researched for a few years, and now I fully understand how to make that thing. But, I could never gather the materials to make it!"
    )
    |> next()
    |> mes("[Eric]")
    |> mes(
      "If I can get those articles, I would build it right away. If you are interested in my idea, would you bring them for me?"
    )
    |> next()
    |> mes("[Eric]")
    |> mes(
      "All I wanna do is build this thing in honor of my grandfather and finish the work he started. If you ask me to keep it, I wouldn't mind."
    )
    |> close()
  end

  defp lists_the_materials(ctx) do
    ctx
    |> mes("[Eric]")
    |> mes("40 ^3355FFSteel^000000")
    |> mes("1 ^3355FFOridecon^000000")
    |> mes("1 ^3355FFAlcohol^000000")
    |> mes("1 ^3355FFCoal^000000")
    |> mes("These are the things I need for Grandfather's masterpiece.")
    |> close()
  end

  defp builds_the_headset(ctx) do
    if has_materials?(ctx) do
      ctx
      |> delitem(@steel, 40)
      |> delitem(@oridecon, 1)
      |> delitem(@alcohol, 1)
      |> delitem(@coal, 1)
      |> give_item(@headset, 1)
      |> mes("*Tap! Tap! Tap!*")
      |> next()
      |> mes("[Eric]")
      |> mes("Thank you.")
      |> mes(
        "Because of you, I could accomplish my grandfather's wish. He would be happy if he looked down on me from Heaven."
      )
      |> next()
      |> mes("[Eric]")
      |> mes("As I said, please take this. I am just proud that I can make this by myself.")
      |> close()
    else
      ctx
      |> mes("[Eric]")
      |> mes(
        "Thank you for trying to help me, but you didn't bring all the items I need. I think you will find them all soon though."
      )
      |> close()
    end
  end

  defp has_materials?(ctx) do
    count_item(ctx, @steel) > 39 and count_item(ctx, @oridecon) > 0 and
      count_item(ctx, @alcohol) > 0 and count_item(ctx, @coal) > 0
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Eric]")
    |> mes("N-no?")
    |> mes("Well...")
    |> mes("You have your own")
    |> mes("worries, I suppose.")
    |> mes("Farewell.")
    |> close()
  end
end
