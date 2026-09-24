defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Alchemist.ChiefResearcher do
  @moduledoc """
  Nicholas Flamel tests an Alchemist candidate's concentration and sends them to assist in Juno.

  ## Behavior

  - Refuses to talk while the player is carrying too much.
  - Gives candidates one of three random four-question hidden-word puzzles and requires a
    perfect score to pass.
  - Hands passing candidates the research materials for Bain and Bajin in Juno.
  - Clears candidates for the Union Leader once Bain and Bajin report back.

  ## Credits

  - Original from rAthena, authors and Contributors
    - nestor_zulueta
    - Darkchild
    - L0ne_W0lf
    - Kisuka
    - kobra_k88
    - Lupus
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alde_alche",
        x: 145,
        y: 19,
        dir: 1,
        sprite: 57,
        name: "Chief Researcher",
        scope: :shared,
        unique_name: "Chief Researcher#am"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @first_puzzle [
    {"t m y a n y e o b n e g p r i", ["Brake", "Brass", "Bug", "Broken", "Brigan?"], 5},
    {"o n c u t a p j l e r s v m u", ["vendor", "storage", "weapon", "simple", "streetshop"], 1},
    {"t v a r m e g p h e u b o y l", ["molasses", "party", "leader", "sweets", "treacle"], 2},
    {"q z a h n a i n b r d p t n c", ["partisan", "partizan", "pato", "paros", "pack"], 2}
  ]

  @shared_last_question {"r o e h n r o m c a i n p t t",
                         [
                           "forgemerchant",
                           "potionmerchant",
                           "dcmerchant",
                           "vendingmerchant",
                           "battlemerchant"
                         ], 2}

  @second_puzzle [
    {"m p d i c f a r o g n k w a s", ["packman", "sunshine", "ragnarok", "wonderland", "frost"],
     1},
    {"g b n o p r e f a r e t a s k", ["purple", "smoker", "ragnarok", "bolt", "burnt wood"], 3},
    {"u g n i s j e k c e o g n d p", ["scab", "kinship", "donate", "source", "opening"], 5},
    @shared_last_question
  ]

  @third_puzzle [
    {"s m i e x b w u n e t a g l r", ["tiger", "wolf", "pumpkin", "tripped", "tore"], 1},
    {"n i e g b o p d s o a u w r v", ["bash", "provoke", "endure", "stun", "abracadabra"], 3},
    {"l r m g r e x t a v i n e d e", ["alberta", "latifoliate", "crimson", "maple", "evergreen"],
     5},
    @shared_last_question
  ]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      ctx
      |> mes("- Wait a minute! -")
      |> mes("- Currently you are carrying -")
      |> mes("- too many items with you. -")
      |> mes("- Please come back again -")
      |> mes("- after you store some items into kafra storage. -")
      |> close()
    else
      talk_about_step(ctx, get_char_var(ctx, :ALCH_Q, 0))
    end
  end

  defp talk_about_step(ctx, step) when step > 19 and step < 22 do
    ctx =
      if step == 20 do
        introduce_test(ctx)
      else
        ctx
      end

    ctx =
      ctx
      |> mes("[Nicholas Flamel]")
      |> mes("Find the words scrambled")
      |> mes("in the group of letters I give you. They can be made by using some")
      |> mes("or all of the letters.")
      |> next()
      |> mes("[Nicholas Flamel]")
      |> mes("You pass if you")
      |> mes("choose the word")
      |> mes("that is ^551A8BIN^000000 the puzzle.")
      |> next()

    puzzle =
      case Enum.random(1..3) do
        1 -> @first_puzzle
        2 -> @second_puzzle
        3 -> @third_puzzle
      end

    {ctx, score} = solve_puzzle(ctx, puzzle)

    ctx =
      ctx
      |> mes("[Nicholas Flamel]")
      |> mes("Ah, you finished.")
      |> mes("Now, let's see...")

    if score > 30 do
      pass_test(ctx)
    else
      fail_test(ctx)
    end
  end

  defp talk_about_step(ctx, 22) do
    if get_char_var(ctx, :MaxWeight, 0) - weight(ctx) < 1370 do
      ctx
      |> mes("[Nicholas Flamel]")
      |> mes("Whoa...")
      |> mes("You're carrying too much stuff! First, put some of your things in Kafra Storage.")
      |> close()
    else
      send_to_juno(ctx)
    end
  end

  defp talk_about_step(ctx, 23) do
    ctx
    |> mes("[Nicholas Flamel]")
    |> mes("Didn't I say to")
    |> mes("go to Juno and help")
    |> mes("Bain and Bajin with")
    |> mes("their Alchemy research?")
    |> close()
  end

  defp talk_about_step(ctx, 24) do
    ctx
    |> set_char_var(:ALCH_Q, 40)
    |> changequest(2038, 2039)
    |> mes("[Nicholas Flamel]")
    |> mes("Ah, you're back!")
    |> mes("I just got a message from Bain")
    |> mes("and Bajin. They let me know that they were very happy with your assistance.")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("If you were good enough")
    |> mes("to help out those brothers,")
    |> mes("you definitely qualify to be")
    |> mes("an Alchemist.")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Good work!")
    |> mes(
      "All you have to do now is speak to the Union Leader on the 2nd floor! Congratulations, you'll become an Alchemist very soon!"
    )
    |> close()
  end

  defp talk_about_step(ctx, step) do
    if step == 40 and Rathena.job_id(base_job(ctx)) == Rathena.job_id(:merchant) do
      ctx
      |> mes("[Nicholas Flamel]")
      |> mes(
        "All you have to do now is speak to the Union Leader on the 2nd floor! Congratulations, you'll become an Alchemist very soon!"
      )
      |> close()
    else
      ctx
      |> mes("[Nicholas Flamel]")
      |> mes("Lorem ipsum dolor sit amet,")
      |> mes("consectetuer adipiscing elit.")
      |> mes("Vivamus sem. Sed metus")
      |> mes("lacus, viverra id, rutrum eget,")
      |> mes("rhoncus sit amet, lectus.")
      |> next()
      |> mes("[Nicholas Flamel]")
      |> mes("Suspendisse sit amet urna in")
      |> mes("nisl fringilla faucibus. Nulla scelerisque eros...")
      |> mes("^666666*Mumble Mumble*^000000")
      |> close()
    end
  end

  defp introduce_test(ctx) do
    ctx
    |> mes("[Nicholas Flamel]")
    |> mes("Ooh...")
    |> mes("You're the upstart")
    |> mes("Merchant that wants")
    |> mes("to become an Alchemist?")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes(
      "Not just anyone can become an Alchemist, you know. You've got to have motivation and clear goals and a strong sense of focus."
    )
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes(
      "Alchemists must memorize many chemical equations, scientific laws and a lot of other information. It's actually pretty tough."
    )
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes(
      "If you can't focus, you'll be confused later when you look at Alchemy charts. My test will judge your ability to do just that."
    )
    |> next()
  end

  defp solve_puzzle(ctx, questions) do
    Enum.reduce(questions, {ctx, 0}, fn {letters, options, answer}, {ctx, score} ->
      {ctx, choice} =
        ctx
        |> mes(letters)
        |> next()
        |> select(options)

      if choice == answer, do: {ctx, score + 10}, else: {ctx, score}
    end)
  end

  defp pass_test(ctx) do
    ctx
    |> set_char_var(:ALCH_Q, 22)
    |> mes("Excellent job!")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes(
      "Great, you found all of those hidden words. With that kind of concentration, you should have no problem memorizing information."
    )
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Come back in a little bit while")
    |> mes("I prepare the next assignment")
    |> mes("for your training.")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Oh, and before you talk to")
    |> mes("me again, make sure you have")
    |> mes("^551A8Bplenty of room in your inventory^000000.")
    |> close()
  end

  defp fail_test(ctx) do
    ctx
    |> set_char_var(:ALCH_Q, 21)
    |> mes("^666666*Gasp!*^000000 H-horrible!")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Judging from these results, you obviously have a problem with concentrating.")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes(
      "If you can't even solve these easy word puzzles, how can you keep track of your experiments and research?"
    )
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Why don't you relax")
    |> mes("and rest a bit before")
    |> mes("you take the test again?")
    |> close()
  end

  defp send_to_juno(ctx) do
    ctx
    |> mes("[Nicholas Flamel]")
    |> mes("Alright...")
    |> mes("For your next")
    |> mes("assignment, you'll")
    |> mes("need to travel to ^551A8BJuno^000000.")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes(
      "There, you'll need to talk to ^551A8BBain^000000 and ^551A8BBajin^000000. Those two are doing Alchemy research with the Sages"
    )
    |> mes("in Juno. You'll learn something by assisting them with their project.")
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Come back here to me after you")
    |> mes("help them out. They'll need all of these items to continue their experiments.")
    |> next()
    |> set_char_var(:ALCH_Q, 23)
    |> changequest(2037, 2038)
    |> mes("[Nicholas Flamel]")
    |> mes("1 Mixture,")
    |> mes("5 Burnt Tree,")
    |> mes("5 Fine Sand,")
    |> mes("3 Rough Oridecon")
    |> mes("and 3 Rough Elunium.")
    |> give_item(974, 1)
    |> give_item(7068, 5)
    |> give_item(7043, 5)
    |> give_item(756, 3)
    |> give_item(757, 3)
    |> next()
    |> mes("[Nicholas Flamel]")
    |> mes("Alright.")
    |> mes("Have a safe trip")
    |> mes("and come back in")
    |> mes("one piece.")
    |> close()
  end
end
