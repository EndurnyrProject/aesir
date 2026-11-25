defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.OldNewsScrapbook do
  @moduledoc """
  The scrapbook lets the player search old newspapers for a fire report.

  ## Behavior

  - At the relevant quest stage, random articles appear until the player finds the laboratory fire.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 117,
        y: 102,
        dir: 3,
        sprite: 844,
        name: "Old News Scrapbook",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :barmunt_crow, 0) == 7 do
      ctx
      |> mes(
        "^660000It is a folder with an wooden frame holding a thick pile of old newspapers.^000000"
      )
      |> next()
      |> mes(
        "^660000You carefully looked through the newspapers to see if you could find any articles about fire accidents.^000000"
      )
      |> next()
      |> read_articles()
    else
      ctx
      |> mes(
        "^660000It is a folder with a wooden frame holding a thick pile of old newspapers.^000000"
      )
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp read_articles(ctx) do
    ctx =
      ctx
      |> mes("...................................")
      |> next()
      |> mes("...................................")
      |> next()
      |> set_local(:newspp, Enum.random(1..10))

    case get_local(ctx, :newspp, 0) do
      n when n in [1, 2] -> ctx |> assassin_article() |> read_articles()
      n when n in [3, 4] -> ctx |> fight_article() |> read_articles()
      5 -> fire_article(ctx)
      n when n in [6, 7] -> ctx |> culture_article() |> read_articles()
      _ -> ctx |> mine_article() |> read_articles()
    end
  end

  defp assassin_article(ctx) do
    ctx
    |> mes("- Page 1 -")
    |> mes("Renowned Assassin Sieglinde: 'I serve you only.'")
    |> mes(" ")
    |> mes(" Sieglinde has attained the title of Greatest Assassin")
    |> mes("for his professionalism")
    |> mes("and fame among ladies,")
    |> mes("for his bad-boy image characterized by his sharpened Katar:")
    |> mes("a handsome man that lives a life of romantic loneliness.")
    |> mes("Recently this Assassin-Turned-Into-Celebrity has made")
    |> mes("a true confession with a smile on his face:")
    |> mes("he has been secretly going out with a lady,")
    |> mes("and they are planning to wed next year.")
    |> mes(" The lady in question is known as Priestess M,")
    |> mes("and she works in Prontera Church, but he refused to give us more information")
    |> mes("about his fiancee for the sake of her safety.")
    |> mes("As soon as the news spread,")
    |> mes("his female fans showed a negative reaction")
    |> mes("saying, 'This is ridiculous.")
    |> mes("Assassins must live alone under the shadows.'")
    |> mes("Hopefully the fans' reaction won't cause too much worry")
    |> mes("to Siglinde and his soon-to-be wife.")
    |> mes(" ")
    |> next()
  end

  defp fight_article(ctx) do
    ctx
    |> mes("- Page 4 -")
    |> mes("Fight Scene in Juno")
    |> mes(" ")
    |> mes("Last night, two young men were witnessed")
    |> mes("violently fighting each other in Juno Plaza.")
    |> mes("According to the Juno soldier that arrested them,")
    |> mes("Mr. B had not been so happy with Mr. A's")
    |> mes("careless behavior, and it seems")
    |> mes("that his patience finally ran out last night.")
    |> mes("It seems the fight started when Mr. A put his bare sweaty feet on Mr. B's thigh,")
    |> mes("saying that his feet are too sweaty.'")
    |> mes("Blame the hot weather, people!")
    |> mes(" ")
    |> next()
  end

  defp fire_article(ctx) do
    ctx
    |> mes("God's Warning: A Secret Lab Reduced to Ashes")
    |> mes(" ")
    |> mes(" The smoke clouding the sky of Juno last night")
    |> mes("turned out to be from")
    |> mes("a secret laboratory set on fire.")
    |> mes(" More information about the laboratory")
    |> mes("has not yet been released, but according to the witnesses,")
    |> mes("the laboratory was found empty")
    |> mes("without anybody or anything inside")
    |> mes("except broken pieces of test tubes")
    |> mes("which proved that the place was used as a laboratory.")
    |> mes(" Scientist Sion, the accident scene investigator,")
    |> mes("suspects from the remnants of machines inside")
    |> mes("that the laboratory must have been used")
    |> mes("to test biotechnology projects,")
    |> mes("and expressed his belief that the fire was the wrath of God,")
    |> mes("righteous punishment for trifling with his creations.")
    |> mes(" ")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...........................")
    |> mes("...........................")
    |> mes("This is the place I've seen in my dream!")
    |> next()
    |> mes("Wait, then what about the place where they escaped...?")
    |> next()
    |> mes("You quickly checked the date of the news. It was too long ago")
    |> mes("for you to find any more information from searching news articles.")
    |> next()
    |> mes("What if they have any descendents or successors?")
    |> next()
    |> mes("You feel your heart beating faster with excitement.")
    |> mes(
      "You are now convinced this was not just your dream or illusion. You had a vision of what really happened in the past."
    )
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I can't believe this is happening!")
    |> mes("Think hard... It was ^FF0000an area connected to a northern cave^000000.")
    |> set_char_var(:barmunt_crow, 8)
    |> changequest(2065, 2066)
    |> close()
  end

  defp culture_article(ctx) do
    ctx
    |> mes("- Culture Page -")
    |> mes("- Please Save My Water -")
    |> mes(" ")
    |> mes("A recently acclaimed young author,")
    |> mes("Jean Cadoc's new series")
    |> mes("'Please Save My Water' has been ranked at the top")
    |> mes("for the most checked-out book in libraries.")
    |> mes("'Please Save My Water' is about a girl called Ujer")
    |> mes("who was blessed by Mother Nature.")
    |> mes("Her father left a will on his deathbed")
    |> mes(" to 'protect the water' against the evil,")
    |> mes("and she is fighting against a group of evil villains")
    |> mes("that are contaminating nature so that she can purify the water.")
    |> mes("This book will be soon selected as an essential academic book of")
    |> mes("the Schwarzwald Republic for")
    |> mes("promoting morality and")
    |> mes("promoting environmental protection throughout the nation.")
    |> mes(" ")
    |> next()
  end

  defp mine_article(ctx) do
    ctx
    |> mes("Einbech Mine Collapsed (2)")
    |> mes(" ")
    |> mes("According to an employee of Rekenber Corporation,")
    |> mes("which has been leading Einbech's mining business,")
    |> mes("three dead bodies have been discovered,")
    |> mes("but one survivor was admitted into a hospital.")
    |> mes("He is in a critical condition,")
    |> mes("and also informed us that they are")
    |> mes("still searching for survivors,")
    |> mes("and have hired specialists to investigate")
    |> mes("the cause of the accident.")
    |> mes(" ")
    |> next()
  end
end
