defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.VoyageLog do
  @moduledoc """
  A voyage log recounting the Turtle Island expedition.

  ## Behavior

  - Randomly reveals a voyage account or one of three quest clues and keys.

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
        x: 246,
        y: 117,
        dir: 4,
        sprite: 111,
        name: "Voyage log",
        scope: :shared,
        unique_name: "Voyage log#tur"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if Rathena.truthy?(:rand.uniform(2) - 1) do
      read_voyage(ctx)
    else
      read_clue_or_close(ctx)
    end
  end

  defp read_voyage(ctx) do
    ctx
    |> mes("[Voyage log]")
    |> mes("03:20 am")
    |> mes(
      "There's no light from the stars tonight, and we can't even see a hundred meters ahead of us. The men seem to feel something bad in the air."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "The faces of my comrades betrayed their fears. They couldn't manage to sleep last night. I hope we will see sunrise soon..."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("04:10 ")
    |> mes(
      "5 minutes ago, our comrade, Cooker, was killed when the mast suddenly cracked and fell on his head."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "The estimated time of death is 04:07. The mast broke due to the shock of the ship hitting a reef. The left side of the deck also suffered from serious damage."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("04:45")
    |> mes(
      "While two of our workers were fixing the bottom of the deck, they were attacked by monsters that had snuck through cracks in the deck."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "These two were lost in the attack. The estimated time of death was 04:32. Fortunately, we are able to stay afloat, but we must hurry and find land."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "From the damage to the deck, we've lost 30% of our supplies. At this rate, we'll run out of food soon."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("05:23")
    |> mes(
      "There seem to be more and more reefs to steer around, and they are growing larger as we travel. I wonder if we'll find land soon..."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("Written by")
    |> mes("Captain Jornadan Niliria")
    |> close()
  end

  defp read_clue_or_close(ctx) do
    if get_char_var(ctx, :TURTLE, 0) == 1 do
      ctx =
        ctx
        |> mes(
          "^3355FFThe paper is torn and seaweed and mold are stuck to the paper. It seems this log is in very poor condition...^000000"
        )
        |> next()

      case Enum.random(1..3) do
        1 -> read_banana_clue(ctx)
        2 -> read_roots_clue(ctx)
        3 -> read_security_clue(ctx)
        _ -> close_log(ctx)
      end
    else
      close_log(ctx)
    end
  end

  defp close_log(ctx), do: ctx |> mes("^3355FFYou've closed the voyage log.^000000") |> close()

  defp read_banana_clue(ctx) do
    ctx
    |> mes(
      "^3355FFThere is a banana leaf between some of the pages. Here is what is written.^000000"
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("O / X date")
    |> mes("Just after we arrived on Turtle Island, we frantically searched all over for food.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes("It was so bad, that you could see the bones through our skin.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes("X / X date")
    |> mes(
      "We found some kind of fruit to eat! It's covered in some sort of yellow skin and looks like a banana!"
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("XO / X date")
    |> mes(
      "Well, it wasn't exactly like the bananas we have in Rune-Midgarts, but it was very similar."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("O / O date")
    |> mes(
      "In the middle of the night, one of the men reported that he felt sick after eating the food."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("OO / O date")
    |> mes("Another crew member, Berot Berot, was also found to have severe indigestion.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "It's now becoming very clear that the food we have been eating contains some kind of poison."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("XO / O date")
    |> mes(
      "The third person to experience indigestion passed away today. We are all very worried."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "Our suspicions were confirmed when we found that the animals on Turtle Island wouldn't eat the bananas we found."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("OX / O date")
    |> mes(
      "We decided to seal away this poisonous fruit, but learned that it didn't rot, not even after we removed the skin."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "We have no idea why it's harmful to eat, or why it never perishes, but it be of some medical or scientific interest."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("In the meantime, we've decided to bury this fruit until we can get back to Alberta.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes("^FF3355tur_dun01^000000")
    |> mes("^FF3355X : 160 , Y : 81^000000")
    |> next()
    |> mes(
      "^3355FFIn the Voyage log is a thin key marked with a skull. You've taken this Skull key, as it may be of some use later.^000000"
    )
    |> set_char_var(:TURTLE, 2)
    |> changequest(11029, 11030)
    |> close()
  end

  defp read_roots_clue(ctx) do
    ctx
    |> mes(
      "^3355FFYou notice a page with a stamp shaped like a bird's foot. The black ink smells sort of like fruit.^000000"
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("X / OO date")
    |> mes(
      "We've found evidence that other people were here, and that we are not the first to find Turtle Island."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "There was at least one person who made it here before us. Hopefully, his records are on the island somewhere."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("Starting tomorrow, we will begin searching for these hidden records.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes("O / OO date")
    |> mes(
      "We are having difficulty trying to find any records. Is it possible that the first people here wrote nothing of their journey?"
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("XO / OO date")
    |> mes("We finally found the records we have been searching for.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "His notes were so hard to find because only one man, rather than a whole team, came to Turtle Island before us!"
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "This man was a swordsman simply known as 'One.' His records tell much about what can be found on Turtle Island."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "His records were written on animals skin, but they were durable and still easy to read after all this time."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "According to his notes, Turtle Island consists of 4 levels. Although there are no people here, but there are many traps and devices which operate through a mysterious force."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("Still, it is certain that something has some control over Turtle Island.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "To keep this record safe, our crew has decided to hide this valuable record on the second level of Turtle Island."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("Search here...")
    |> mes("^FF3355tur_dun02^000000")
    |> mes("^FF3355X : 132 , Y : 251^000000")
    |> next()
    |> mes(
      "^3355FFThere is a picture of a tree in which there is a small keyhole clearly shown under the roots.^000000"
    )
    |> next()
    |> mes("^3355FFYou've gained^000000")
    |> mes("^3355FFthe Roots key.^000000")
    |> set_char_var(:TURTLE, 3)
    |> changequest(11029, 11031)
    |> close()
  end

  defp read_security_clue(ctx) do
    ctx
    |> mes(
      "^3355FFThese pages of this log are soiled with mud, and some of them are missing.^000000"
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("O / XX date")
    |> mes(
      "The greatest treasure of Turtle Island, the likes of which have never been seen, is hidden, sealed in some secret place..."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("We have spent many days searching for it, but found not one trace.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "In the meantime, we've collected many precious treasures. We've decided to take only some of it back home, and to leave the rest here."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("XO / XX date")
    |> mes("We have hidden the treasure we have left behind to keep it from getting stolen.")
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "It is somewhere on the fourth level, the bottom of the island. The treasure is sealed in a box that is a relic from an ancient culture."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes(
      "However, the technology of this treasure box is very sophisticated, and it won't be easy to open by force."
    )
    |> next()
    |> mes("[Voyage Log]")
    |> mes("Here...")
    |> mes("^FF3355tur_dun01^000000")
    |> mes("^FF3355X : 203 , Y : 155^000000")
    |> next()
    |> mes(
      "^3355FFYou find three small holes under the turtle stone. Within one of these holes is a thin key.^000000"
    )
    |> next()
    |> mes("^3355FFYou've gained ^000000")
    |> mes("^3355FFthe Security key^000000")
    |> set_char_var(:TURTLE, 4)
    |> changequest(11029, 11032)
    |> close()
  end
end
