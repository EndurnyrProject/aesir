defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Alchemist.MasterAlchemist do
  @moduledoc """
  Vincent Carsciallo, head of the Alchemist Union, who performs the Alchemist job change.

  ## Behavior

  - Turns away transcended characters and greets Alchemists, Novices, and other classes.
  - Introduces the Union to Merchants who have not started the quest and reminds registered
    candidates to follow the other Alchemists' instructions.
  - Changes qualified candidates (Job Level 40 or higher, no unused skill points) into
    Alchemists, closing the quest log and clearing job quest variables.
  - Rewards a Slim Potion creation guide at Job Level 50, otherwise a random creation guide.

  ## Credits

  - Original from rAthena, authors and Contributors
    - nestor_zulueta
    - Darkchild
    - L0ne_W0lf
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alde_alche",
        x: 101,
        y: 184,
        dir: 4,
        sprite: 122,
        name: "Master Alchemist",
        scope: :shared,
        unique_name: "Master Alchemist#am"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @random_creation_guides {7127, 7128, 7129, 7130, 7131, 7144}

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = ctx |> cutin("job_alche_vincent", 2) |> mes("[Vincent Carsciallo]")

    cond do
      upper(ctx) == 1 ->
        ctx
        |> mes("You have transcended...")
        |> mes("Excellent, excellent.")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("You don't belong here.")
        |> mes("Go and explore the wide world, my friend.")
        |> close()
        |> cutin("", 255)

      Rathena.job_id(base_job(ctx)) != Rathena.job_id(:merchant) ->
        ctx
        |> non_merchant_greeting()
        |> close()
        |> cutin("", 255)

      get_char_var(ctx, :ALCH_Q, 0) == 0 ->
        ctx
        |> mes("Hmm...?")
        |> mes("A Merchant?")
        |> mes("Are you interested")
        |> mes("in learning Alchemy?")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("This is the Alchemist Union.")
        |> mes(
          "We research and experiment with many different substances in order to create new materials without using magic."
        )
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("Someday, we hope to unlock")
        |> mes("the secret of life, as well as the other mysteries of science.")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes(
          "After being traveling as a Merchant for a long time, you must have developed some scientific curiosity. If you'd like to learn Alchemy, why don't you try joining the Alchemist Union?"
        )
        |> close()
        |> cutin("", 255)

      get_char_var(ctx, :ALCH_Q, 0) == 40 ->
        final_step(ctx)

      true ->
        ctx
        |> mes("Ah...")
        |> mes("I believe you've")
        |> mes("already registered")
        |> mes("for training to become")
        |> mes("an Alchemist.")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("Please listen to the")
        |> mes(
          "other Alchemists and follow their instructions carefully. You will learn much from them."
        )
        |> close()
        |> cutin("", 255)
    end
  end

  defp non_merchant_greeting(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:alchemist) ->
        ctx
        |> mes("Welcome!")
        |> mes("So how is your")
        |> mes("research coming along?")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes(
          "At times you get results that are unexpected from an experiment. Although these may be setbacks in your research, such results can also lead to new discoveries."
        )
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("If you discover something new,")
        |> mes(
          "come and tell us. Don't forget that we are all working together to unlock the mysteries of science!"
        )

      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("Hm...")
        |> mes("A Novice?")
        |> mes("You shouldn't be")
        |> mes("playing in a place")
        |> mes("like this.")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("There are a lot of volatile chemicals and dangerous")
        |> mes("materials in this building. It'd be a lot better if you just played outside.")

      true ->
        ctx
        |> mes("Hmm...?")
        |> mes("What's an adventurer")
        |> mes("doing here in the")
        |> mes("Alchemist Union?")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("I'm afraid there's")
        |> mes("not much we can offer")
        |> mes("you here if you're not")
        |> mes("a member of our Union.")
    end
  end

  defp final_step(ctx) do
    cond do
      job_level(ctx) < 40 ->
        ctx
        |> set_char_var(:ALCH_Q, 0)
        |> mes("Hmm...you don't seem to be qualified yet.")
        |> mes("Remember, you must reach at least job level 40 to become an Alchemist.")
        |> close()
        |> cutin("", 255)

      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("Ah, you're almost")
        |> mes("ready to become an")
        |> mes("Alchemist, but you must")
        |> mes("first allocate your unused")
        |> mes("Skill Points.")
        |> next()
        |> mes("[Vincent Carsciallo]")
        |> mes("Talk to me again")
        |> mes("once you have spent")
        |> mes("all of your extra")
        |> mes("Skill Points.")
        |> close()
        |> cutin("", 255)

      true ->
        change_to_alchemist(ctx)
    end
  end

  defp change_to_alchemist(ctx) do
    ctx = if checkquest(ctx, 2039) != -1, do: changequest(ctx, 2039, 2040), else: ctx
    ctx = if checkquest(ctx, 2034) != -1, do: changequest(ctx, 2034, 2040), else: ctx

    ctx =
      ctx
      |> mes("Ah, well done.")
      |> mes("I can see that you")
      |> mes("have learned all of")
      |> mes("the basics of Alchemy.")
      |> next()
      |> set_char_var(:ALCH_Q, 0)
      |> completequest(2040)

    job_level_before_change = if match?({:error, _}, ctx.status), do: 0, else: job_level(ctx)

    {ctx, _} =
      ctx
      |> jobchange(:alchemist)
      |> FClearjobvar.call([])

    ctx =
      ctx
      |> mes("[Vincent Carsciallo]")
      |> mes("Henceforth, you are")
      |> mes("now a member of our")
      |> mes("illustrious Union.")
      |> mes("I hope you learn a lot...")
      |> next()

    ctx =
      if job_level_before_change == 50 do
        ctx
        |> give_item(7133, 1)
        |> mes("[Vincent Carsciallo]")
        |> mes("Let me give you")
        |> mes("something special.")
        |> mes("You can use this to")
        |> mes("begin your life")
        |> mes("of research.")
      else
        ctx
        |> give_item(elem(@random_creation_guides, Enum.random(1..6) - 1), 1)
        |> mes("[Vincent Carsciallo]")
        |> mes("And...")
        |> mes("Here's a little")
        |> mes("something to help")
        |> mes("you begin your")
        |> mes("research.")
      end

    ctx
    |> next()
    |> mes("[Vincent Carsciallo]")
    |> mes("I'll see")
    |> mes("you later then...")
    |> mes("Remember to carry")
    |> mes("yourself with pride")
    |> mes("as an Alchemist!")
    |> close()
    |> cutin("", 255)
  end
end
