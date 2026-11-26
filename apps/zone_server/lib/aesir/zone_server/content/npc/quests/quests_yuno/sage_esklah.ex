defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsYuno.SageEsklah do
  @moduledoc """
  Sage Esklah tests the stamp bearer and prepares Muriniel’s compass.

  ## Behavior

  - Requests compass materials in two stages and reveals the cottage location.

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
        x: 213,
        y: 298,
        dir: 4,
        sprite: 735,
        name: "Sage Esklah",
        scope: :shared,
        unique_name: "Sage Esklah#juno"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :dmdswrd_Q, 0) do
      27 ->
        ctx
        |> mes("[Esklah]")
        |> mes("Hm...?")
        |> mes("You must be the one who holds the Stamp of Muriniel...")
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "Heh, you don't look like much. But even though you're ordinary looking, you possess the legendary item!"
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "Only a few people in Midgard's history have been chosen to use the ^3355FFStamp of Muriniel.^000000"
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "However, it's my job to test whether or not you are truly qualified to possess it."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes("Let me tell you about the stamp craftman ^3355FFMuriniel^000000.")
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "This man lived long ago, somewhere in Mt. Mjornir. He was eager in his studies, and wanted to recreate every pattern that existed in the world."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "Believing that people were obstacles to his study of patterns, he lived in seclusion, studying alone."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "While studying patterns one day, he happened to find a magic circle that connected this world to another world."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "That circle was totally different from ones used by Mages, Wizards or sages. This pattern had the power to summon an evil creature from the other world."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "In order to summon the creature, the pattern must be created in the perfect location. Muriniel began to explore various places and finally found the spot he was looking for."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "The place he found is now ^3355FFMuriniel's Cottage^000000. But to see that place, you will first need the ^3355FFCompass of Muriniel^000000."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes("Heh heh. That's right, making the Compass of Muriniel will be my test for you.")
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "Now listen carefully, I won't tell you more than once. I will need you to collect some items to make the ^3355FFCompass of Muriniel^000000."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes("Bring me...")
        |> mes("^3355FF2 Iron Ore^000000,")
        |> mes("^3355FF10 Acorn^000000 and")
        |> mes("^3355FF5 Decayed Nail^000000.")
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "For someone seeking the doomed sword, this should be a relatively simple task. Now go, and bring me what I have asked."
        )
        |> set_char_var(:dmdswrd_Q, 28)
        |> close()

      28 ->
        if count_item(ctx, 1002) > 1 and count_item(ctx, 1026) > 9 and
             count_item(ctx, 957) > 4 do
          ctx
          |> mes("[Esklah]")
          |> mes("Let's see.")
          |> mes("2 Iron Ore...")
          |> mes("10 Acorn...")
          |> mes("5 Decayed Nail...")
          |> mes("Good, that's everything!")
          |> delitem(1002, 2)
          |> delitem(1026, 10)
          |> delitem(957, 5)
          |> next()
          |> mes("[Esklah]")
          |> mes(
            "Good work. Now, while I make the body of the compass, you can go and bring me the rest of the items I'll need."
          )
          |> next()
          |> mes("[Esklah]")
          |> mes(
            "Muhahahaha! What's with that look? You know how this kind of business gets done!"
          )
          |> next()
          |> mes("[Esklah]")
          |> mes("Now stop whining")
          |> mes("and go bring...")
          |> mes("^3355FF2 Brigan^000000 and")
          |> mes("^3355FF1 Phracon^000000.")
          |> mes("Now isn't that simple?")
          |> mes("Muhahahaha!!")
          |> set_char_var(:dmdswrd_Q, 29)
          |> close()
        else
          ctx
          |> mes("[Esklah]")
          |> mes(
            "Now listen carefully. I won't tell you more than once. I need some items to create the ^3355FFCompass of Muriniel^000000."
          )
          |> next()
          |> mes("[Esklah]")
          |> mes("Bring me...")
          |> mes("^3355FF2 Iron Ore^000000,")
          |> mes("^3355FF10 Acorn^000000, and")
          |> mes("^3355FF5 Decayed Nail^000000.")
          |> close()
        end

      29 ->
        if count_item(ctx, 7054) > 1 and count_item(ctx, 1010) > 0 do
          ctx
          |> mes("[Esklah]")
          |> mes("Now...")
          |> mes("Show me")
          |> mes("what you brought.")
          |> mes("That's 2 Brigan and...")
          |> mes("1 Phracon. Hmm. Very good.")
          |> mes("Now let me get to work.")
          |> delitem(7054, 2)
          |> delitem(1010, 1)
          |> next()
          |> mes("[Esklah]")
          |> mes("Hmm...")
          |> mes("Let's see...")
          |> mes("There, it's finished.")
          |> next()
          |> mes("^3355FFSage Esklah handed you the ^3355FFCompass of Muriniel^000000.")
          |> next()
          |> mes(
            "^3355FFIn the direction the compass is pointing, some words are engraved...^000000"
          )
          |> next()
          |> mes("^3355FF- Mountain Mjornir -^000000")
          |> mes("^3355FF- mjolnir_02 . 170 193 -^000000")
          |> next()
          |> mes("[Esklah]")
          |> mes(
            "Look at the middle of compass carefully to find the place you must use the stamp. I wish you the best of luck in your journey."
          )
          |> set_char_var(:dmdswrd_Q, 30)
          |> close()
        else
          ctx
          |> mes("[Esklah]")
          |> mes("Listen carefully!")
          |> mes("I want you to bring...")
          |> mes("^3355FF2 Brigan^000000 and")
          |> mes("^3355FF1 Phracon^000000")
          |> mes("Isn't that simple and easy?")
          |> mes("Muhahaha! Now, get a move on!")
          |> close()
        end

      30 ->
        ctx
        |> mes(
          "^3355FFYou look into the compass of Muriniel and take note of the engraving...^000000"
        )
        |> next()
        |> mes("^3355FF- Mountain Mjornir -^000000")
        |> mes("^3355FF- mjolnir_02 . 170 193 -^000000")
        |> close()

      _ ->
        ctx
        |> mes("[Esklah]")
        |> mes("I remember watching a harmless")
        |> mes("piece of paper floating")
        |> mes("through the air...")
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "As I was thinking of how wonderfully poetic that image was, that paper suddenly attacked me! Me, one of Juno's greatest Sages!"
        )
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "I tried defending myself with my trusty sword, but being paper-thin, that monster managed to dodge all of my blows. I had to cast magic in order to destroy it."
        )
        |> next()
        |> mes("[Esklah]")
        |> mes("Later, I learned that monster is known as ^3355FFThe Paper^000000.")
        |> next()
        |> mes("[Esklah]")
        |> mes(
          "It used to be a part of an old book that contained a lot of ancient knowledge about Juno, but somehow, became a monster. Isn't that peculiar?"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
