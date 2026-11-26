defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Gordon do
  @moduledoc """
  Gordon is a retired alchemist living in the forest with Pleur.

  ## Behavior

  - Responds to visitors according to their progress in the quest.
  - Discusses the Stone of Sage and guides the visitor out of the maze.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_maze02",
        x: 14,
        y: 183,
        dir: 4,
        sprite: 51,
        name: "Gordon",
        scope: :shared,
        unique_name: "Gordon#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Gordon]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 18 ->
        ctx = family_conversation(ctx)

        cond do
          get_char_var(ctx, :sign_q, 0) < 17 -> close(ctx)
          get_char_var(ctx, :sign_q, 0) == 17 -> greet_gordon(ctx)
          true -> ctx
        end

      progress == 18 ->
        ctx
        |> startled_gordon()
        |> ask_questions()

      progress > 18 ->
        later_conversation(ctx)

      true ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp family_conversation(ctx) do
    ctx
    |> emotion(:delight)
    |> mes("Hello darling.")
    |> mes("What did you do today?")
    |> next()
    |> donpcevent("Pleur#sign::OnHo")
    |> mes("[Pleur]")
    |> mes("I played Hide-and-Seek")
    |> mes("with a white bear and a")
    |> mes("blue bear, father.")
    |> next()
    |> emotion(:delight)
    |> mes("[Gordon]")
    |> mes("Darling...")
    |> mes("Aren't you tired")
    |> mes("of playing with the")
    |> mes("animals? We've lived")
    |> mes("in this forest for so long...")
    |> next()
    |> donpcevent("Pleur#sign::OnKis2")
    |> mes("[Pleur]")
    |> mes(
      "Don't worry father, I understand. For now, this is the only place where we can relax and live inpeace. I think we deserve to rest after accomplishing our goals..."
    )
    |> next()
    |> emotion(:cry)
    |> mes("[Gordon]")
    |> mes("Thank you, Pluer.")
    |> mes("I have no regrets about")
    |> mes("our work, but sometimes")
    |> mes("I do wish for a more")
    |> mes("carefree life for you...")
  end

  defp greet_gordon(ctx) do
    {ctx, choice} = ctx |> next() |> select(["Roar~!", "Excuse me."])

    case choice do
      1 ->
        ctx
        |> set_char_var(:sign_q, 18)
        |> donpcevent("#skill::OnEnable")
        |> emotion(:huk)
        |> donpcevent("Pleur#sign::OnOMG")
        |> mes("[Pleur]")
        |> mes("No no no!")
        |> mes("Summon Flora!")
        |> next()
        |> mes("[Gordon]")
        |> mes("Great Schott!")
        |> mes("Summon... Marine Sphere!")
        |> close()

      2 ->
        ctx
        |> surprised_gordon()
        |> ask_questions()

      _ ->
        ctx
    end
  end

  defp surprised_gordon(ctx) do
    ctx
    |> emotion(:surprise)
    |> donpcevent("Pleur#sign::OnGasp")
    |> mes("[Gordon]")
    |> mes("Eh?! Don't you know")
    |> mes("how dangerous this place")
    |> mes("is? What are you doing")
    |> mes("here in the middle of")
    |> mes("this forest?")
    |> next()
  end

  defp startled_gordon(ctx) do
    ctx
    |> emotion(:hng)
    |> mes("Oh...!")
    |> mes("You scared us!")
    |> mes("Roaring like some")
    |> mes("animal! What do you")
    |> mes("think you were doing?")
    |> next()
  end

  defp ask_questions(ctx) do
    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Actually, I think")
      |> mes("I've been looking for")
      |> mes("you. I've been sent on")
      |> mes("an errand to find these")
      |> mes("two famous Alchemists.")
      |> next()
      |> mes("[Gordon]")
      |> mes("Mm...?")
      |> mes("Well, we're retired")
      |> mes("now, but I suppose it'd")
      |> mes("do no harm if you had")
      |> mes("something to ask us...")
      |> next()
      |> select(["Ask about Stone of Sage", "Ask about Alchemy", "Quit"])

    case choice do
      1 ->
        stone_of_sage(ctx)

      2 ->
        alchemy(ctx)

      3 ->
        ctx
        |> mes("[Gordon]")
        |> mes("Hah hah hah~")
        |> mes("Did you forget")
        |> mes("what you were")
        |> mes("going to ask me?")
        |> close()

      _ ->
        ctx
    end
  end

  defp stone_of_sage(ctx) do
    ctx
    |> set_char_var(:sign_q, 19)
    |> mes("[Gordon]")
    |> mes("Stone of Sage?")
    |> mes("Huh. To be honest,")
    |> mes("I don't know anything")
    |> mes("about it at all. I guess")
    |> mes("its existence is pretty")
    |> mes("much just a rumor, really.")
    |> next()
    |> mes("[Gordon]")
    |> mes("All I've heard is that")
    |> mes("the Stone of Sage might")
    |> mes("be a catylst to transmute")
    |> mes("materials into gold. If it")
    |> mes("really existed, it would be")
    |> mes("the ultimate alchemic item.")
    |> next()
    |> mes("[Pleur]")
    |> mes("However, I've also heard")
    |> mes("it's red, can make humans")
    |> mes("immortal and can cure any")
    |> mes("sort of disease or ailment.")
    |> mes("Just where do these rumors")
    |> mes("come from? It's crazy...")
    |> next()
    |> mes("[Gordon]")
    |> mes("Now, I even hear that some")
    |> mes("people are working on trying")
    |> mes("to create the stone themselves.")
    |> mes("If they succeed, it'll have a huge effect on the entire world!")
    |> next()
    |> mes("[Gordon]")
    |> mes("I'm sorry that you've gone")
    |> mes("through the trouble of finding")
    |> mes("us for this kind of information. We're retired after all, so we")
    |> mes("may be out of the loop.")
    |> next()
    |> mes("[Pleur]")
    |> mes("Although we're retired, we")
    |> mes("would be much interested in")
    |> mes("knowing if someone does manage")
    |> mes("to create such a stone. If that")
    |> mes("happens, would you tell us?")
    |> next()
    |> mes("[Gordon]")
    |> mes("Now let me guide you")
    |> mes("on a safe path back out")
    |> mes("of this maze. I've lived here")
    |> mes("quite a while, so I can find")
    |> mes("the exit with my eyes closed.")
    |> mes("Farewell, adventurer~")
    |> close2()
    |> warp("mjolnir_12", 44, 23)
  end

  defp alchemy(ctx) do
    ctx
    |> mes("[Pleur]")
    |> mes("I hope you understand that")
    |> mes(
      "my father and I devoted and sacrificed so much for our work. Finally, we discovered a way to summon monsters using potions."
    )
    |> next()
    |> mes("[Pleur]")
    |> mes("However, too many Alchemists")
    |> mes("hounded us for our information")
    |> mes("once we announced the results")
    |> mes("of our research. It was more")
    |> mes("than we could handle...")
    |> next()
    |> mes("[Gordon]")
    |> mes("I'm sorry, but if you have any")
    |> mes("questions about Alchemy, there")
    |> mes(
      "are many qualified researchers and practitioners out there. We came to this forest to find peace..."
    )
    |> close()
  end

  defp later_conversation(ctx) do
    ctx
    |> mes("Sometimes I miss")
    |> mes("being an alchemist.")
    |> mes("But then again, a man")
    |> mes("of my brilliance and genius")
    |> mes("would put all those newbie")
    |> mes("scientists to shame~")
    |> next()
    |> emotion(:sweat)
    |> mes("[Pleur]")
    |> mes("D...")
    |> mes("D...Daddy!!")
    |> next()
    |> emotion(:smile)
    |> mes("[Gordon]")
    |> mes("Heh heh~")
    |> mes("Am I being")
    |> mes("too arrogant?")
    |> close()
  end
end
