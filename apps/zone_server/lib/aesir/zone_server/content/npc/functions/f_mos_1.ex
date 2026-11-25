defmodule Aesir.ZoneServer.Content.Npc.Functions.FMos1 do
  @moduledoc """
  Gallina and Anna ask the player to help find Mikhail.

  ## Behavior

  - Offers the search and starts the quest when the player agrees.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  import Aesir.ZoneServer.Script.Dsl, warn: false
  alias Aesir.ZoneServer.Script.Rathena

  @doc "Callable rAthena global function; returns `{ctx, return_value}`."
  def call(ctx, args), do: scoped_call(ctx, args, &run/2)

  defp run(ctx, _args) do
    ctx =
      ctx
      |> mes("[Gallina]")
      |> mes("Oh, where the heck is he?")
      |> mes("I'll teach him a lesson.")
      |> mes("He's timid like Dad.")
      |> next()
      |> mes("[Anna]")
      |> mes("Mikhail, he's a coward, a crybaby.")
      |> mes("Mikhail, he's a coward, a crybaby.")
      |> next()
      |> mes("[Gallina]")
      |> mes("It's because you didn't look after your brother. So you clean the house, Anna?")
      |> next()

    {ctx, choice} =
      ctx
      |> emotion(:cry, getnpcid(ctx, "Anna#mos"))
      |> mes("[Anna]")
      |> mes("Oh, my................")
      |> next()
      |> select(["Talk to her.", "Just pass by her"])

    result =
      if choice == 2 do
        ctx
        |> mes("[Gallina]")
        |> mes("I'm worried that he's making trouble somewhere...")
        |> close()
      else
        offer_search(ctx)
      end

    throw({:script_end, result})
  end

  defp offer_search(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Hello, there?")
      |> next()
      |> mes("[Gallina]")
      |> mes("Oh, God!")
      |> mes("I didn't see you there. Sorry!")
      |> mes("You want to buy a hotcake, don't you?")
      |> mes("I'm sorry but we're not ready to open the store..")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("No, that's ok.")
      |> mes("Is there something that I can help with? What's the matter?")
      |> next()
      |> mes("[Gallina]")
      |> mes("Oh, well...")
      |> mes("My son, Mikhail broke our Matrushka while I was away from home.")
      |> mes("He's afraid that I would punish him. So he ran away.")
      |> next()
      |> mes("[Gallina]")
      |> mes("How timid the boy is!")
      |> mes("I doubt that he'd be able to be a great general in the future")
      |> next()
      |> mes("[Gallina]")
      |> mes("He used to come home at this time.")
      |> mes("I'm worried that something bad has happened to him.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("You look anxious. I'd like to help you to find your son.")
      |> next()
      |> mes("[Gallina]")
      |> mes("Did you say I'm anxious?")
      |> mes("I'm just anxious for him to get home.")
      |> mes("...So I can punish him for what he did.")
      |> next()
      |> mes("[Gallina]")
      |> mes("But it's not good that I refuse your kindness")
      |> mes("Will you find Mikhail for me?")
      |> next()
      |> select(["I was not serious.", "Yes, I will!"])

    if choice == 1 do
      ctx |> mes("[Gallina]") |> mes("You meanie! I'm not in the mood for jokes.") |> close()
    else
      ctx
      |> mes("[Gallina]")
      |> mes("Oh, God, You're so kind")
      |> mes("Mikhail is such a timid boy. I guess he didn't leave this village.")
      |> mes("Please bring him to me, then~")
      |> set_char_var(:mos_swan, 1)
      |> setquest(18060)
      |> close()
    end
  end
end
