defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.SageSyklah do
  @moduledoc """
  Sage Syklah prepares ink for the Stamp of Muriniel.

  ## Behavior

  - Requests materials for the ink and directs the player to Esklah.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf
    - kobra_k88
    - Darkchild
    - Lupus
    - Samuray22
    - akrus

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno",
        x: 305,
        y: 207,
        dir: 4,
        sprite: 735,
        name: "Sage Syklah",
        scope: :shared,
        unique_name: "Sage Syklah#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :dmdswrd_Q, 0) do
      25 ->
        ctx
        |> mes("[Syklah]")
        |> mes("What's that?!")
        |> mes("Can it be the Stamp of Muriniel?")
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "Now, we shall battle to the death to see if you are worthy of possessing this item. Prepare yourself!"
        )
        |> next()
        |> mes("[Syklah]")
        |> mes("...")
        |> mes(
          "Muhahahahaha!!! Don't worry, I was only messing with you. Yklah told me that you might be coming."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "It is said that The Stamp of Muriniel chooses its owner by its own will, and will not appear otherwise."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "Even though I am one of the three great Sages of Juno, I've never even seen this item before."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "Yklah gave me an idea about the Stamp of Muriniel you've brought, so we'll try it out as well."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "The pattern engraved on the Stamp of Muriniel has shapes that are similar to the pattern engraved on this^3355FFStatue of the Goddess Snotora^000000."
        )
        |> next()
        |> mes(
          "^3355FFYou see for yourself that, indeed, the pattern on the statue of the Goddess Snotora matches that on the Stamp of Muriniel.^000000"
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "When I was young, I learned about a legendary stamp ink related to this statue. But at the time, it made no sense to me. Just how legendary can stamp ink be?"
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "But now I believe that this stamping ink can be used with this Stamp of Muriniel."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "But even though I've learned how to make this special stamping ink, it is too difficult for me to collect the materials that are necessary to create it."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "Okay, if you're ready, please bring me the following items. I feel like making legendary red ink, so bring me..."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes("^3355FF20 Red Herb^000000,")
        |> mes("^3355FF5 Stone^000000 and")
        |> mes("^3355FF1 Stone Heart^000000.")
        |> mes("The Stone Heart will be used as a bottle to hold this special ink.")
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "I think that's all I need. Anyway, I believe that gathering these items shouldn't be a difficult task for you. Good luck to you."
        )
        |> set_char_var(:dmdswrd_Q, 26)
        |> close()

      26 ->
        if count_item(ctx, 7049) > 4 and count_item(ctx, 953) > 0 and
             count_item(ctx, 507) > 19 do
          ctx
          |> mes("[Syklah]")
          |> mes("Hahaha...!")
          |> mes(
            "So you've already gathered the items I've asked for. Good, good. Let's get started..."
          )
          |> delitem(7049, 5)
          |> delitem(953, 1)
          |> delitem(507, 20)
          |> next()
          |> mes(
            "^3355FFSage Syklah grinded the stones and stone heart and molded them into a strange shape.^000000"
          )
          |> next()
          |> mes(
            "^3355FFHe then ground the red herbs and placed them into the stone mold.^000000"
          )
          |> next()
          |> mes(
            "^3355FFAfterwards, he then took a strangely shaped capsule from his pocket, sprinkled some liquid from it, and began to chant a spell...^000000"
          )
          |> next()
          |> mes("[Syklah]")
          |> mes("Haooooh...")
          |> mes(
            "Doo de doo de~ Dah dah dah Dan dan dan Dah dah dah! Nu ha nu ha nu hahaha... Moo hee moo hee moo hee~"
          )
          |> mes("- Pah ahhhh !! -")
          |> next()
          |> mes(
            "^3355FFThe Stamping Ink of Muriniel has been created, and has been given to you by the sage Syklah.^000000"
          )
          |> set_char_var(:dmdswrd_Q, 27)
          |> next()
          |> mes("[Syklah]")
          |> mes("Now, with this stamping ink, you are able to use the Stamp of Muriniel.")
          |> next()
          |> mes("[Syklah]")
          |> mes(
            "Now, I don't think you can use the stamp just anywhere. After all, it is a legendary item."
          )
          |> next()
          |> mes("[Syklah]")
          |> mes(
            "Please visit the Third Sage ^3355FFEsklah^000000 who stays on Solomon, the island of prosperity, here in Juno."
          )
          |> next()
          |> mes("[Syklah]")
          |> mes(
            "He will be able to tell you more about where to use this stamp. However, be careful. He is the most fastidious sage among all of us."
          )
          |> close()
        else
          ctx
          |> mes("[Syklah]")
          |> mes("I hope you will bring me what I need to make the 'Stamp of Muriniel' ink soon.")
          |> next()
          |> mes("[Syklah]")
          |> mes("I will need...")
          |> mes("^3355FF20 Red Herb^000000,")
          |> mes("^3355FF5 Stone^000000 and")
          |> mes("^3355FF1 Stone Heart^000000.")
          |> close()
        end

      27 ->
        ctx
        |> mes("[Syklah]")
        |> mes(
          "Please visit ^3355FFEsklah^000000 on the island of prosperity, Solomon. But be careful. He is the most exacting Sage out of all of us."
        )
        |> close()

      _ ->
        ctx
        |> mes("[Syklah]")
        |> mes("The people here keep talking of some suspicious man living in Juno.")
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "Supposedly, he's pretty dangerous, and is always immersing himself in some kind of research."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "People already consider him a 'Mad Scientist,' wasting his time studying impractical things beyond the understanding of normal people."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "It's rumored that this scientist is responsible for creating 'Blazer,' a monster made of magic flame."
        )
        |> next()
        |> mes("[Syklah]")
        |> mes(
          "It's a dangerous and fearsome monster that casts spells like Fire Bolt and Fire Ball that lives outside of Juno."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
