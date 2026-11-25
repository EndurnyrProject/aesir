defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BookRussia do
  @moduledoc """
  A large spell book describes the Eternal Summer ritual.

  ## Behavior

  - The book reveals its preface and ritual instructions as the winter quest advances.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 217,
        y: 45,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#book_russia"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :mos_nowinter, 0) == 15 ->
        read_first_time(ctx)

      get_char_var(ctx, :mos_nowinter, 0) == 16 ->
        {ctx, choice} = select(ctx, ["Read from the preface.", "Read from the marked page."])

        if choice == 1 do
          ctx
          |> read_first_feature()
          |> next()
          |> read_second_feature()
          |> next()
          |> read_recipe()
          |> close()
        else
          ctx
          |> read_recipe()
          |> close()
        end

      get_char_var(ctx, :mos_nowinter, 0) > 14 ->
        ctx
        |> mes("-This book is the magic book that")
        |> mes("helped me make the medicine, but,")
        |> mes("I never want to read it again.-")
        |> close()

      true ->
        ctx |> mes("-It's an unusually large book laid down, open.-") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp read_first_time(ctx) do
    ctx =
      ctx
      |> mes("-Beside the pot,")
      |> mes("There is an unusually large book.")
      |> mes("The letters are in disarray and")
      |> mes("some of them, I can't understand.")
      |> mes("The comments by Baba Yaga")
      |> mes("help me read some of them.-")
      |> next()
      |> mes("-Ok, time to read it.-")
      |> next()
      |> read_first_feature()
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("That? That's just the preface?!")
      |> next()
      |> read_second_feature()
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("It just accounts for the spell.")
      |> mes("What a long preface.")
      |> mes("I'll mark this spot.")
      |> mes("so I can easily find the mixing")
      |> mes("process next time...")
      |> set_char_var(:mos_nowinter, 16)
      |> next()
      |> read_recipe()
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("I'll mark this page so that I")
    |> mes("know where to read next time.")
    |> close()
  end

  defp read_recipe(ctx) do
    ctx
    |> mes("^0000ffSeasonal Magic^000000:^ff0000Eternal Summer^000000")
    |> mes("First of all, you need to put and")
    |> mes("mix the first 3 things in a pre-heated pot.")
    |> mes("The extended arms of those who stalk at night,")
    |> mes("The rotten mixture of plants and animals,")
    |> mes("and the limbs of one going forward,")
    |> mes("who wants to run backward.")
    |> mes("This first stage should be complete.")
    |> mes("Just after this stage, the mixture")
    |> mes("will barely show any alteration.")
    |> mes("After this, you must add the liquid")
    |> mes("that aids all life and stir 20 times.")
    |> mes("At this point you will certainly")
    |> mes("see its color and smell changing.")
    |> mes("Remember that if you realize that")
    |> mes("something is wrong, you must stop and start over.")
    |> mes("Following these precise steps are")
    |> mes("most important when working on magic.")
    |> mes("Next, 2 things must be put in the pot.")
    |> mes("First, objects that are seen when")
    |> mes("looking at the night sky.")
    |> mes("Second the pretty mass of earth,")
    |> mes("slipping through even when watered.")
    |> mes("You should check if it's smell has changed.")
    |> mes("Then stir it well 15 times.")
    |> mes("It's color will change.")
    |> mes("The final ingredients will be those")
    |> mes("that contain heat.")
    |> mes("You must follow the order.")
    |> mes("Stones that have the attribute of sun,")
    |> mes("brains of a marine sphere,")
    |> mes("the organ of passion,")
    |> mes("and a stone that cannot be cut.")
    |> mes("Once the final ingredient is placed in the pot,")
    |> mes("It will be over.")
    |> mes("The solution must be sprinkled at")
    |> mes("the place where you want to affect,")
    |> mes("the changing of the seasons.")
  end

  defp read_first_feature(ctx) do
    ctx
    |> mes("...Therefore, this spell is")
    |> mes("particularly good among our mighty ones.")
    |> mes("Usually, the magic is considered")
    |> mes("as a contract with evil.")
    |> mes("But, the following is not the power")
    |> mes("of Hell but of Nature and the spirit of humans.")
    |> mes("I already told you that this spell")
    |> mes("has 2 features as follows.")
    |> mes("First, it changes natural phenomenon.")
    |> mes("Unlike the idea from foolish scholars,")
    |> mes("this world is composed of invisible and precise orders.")
    |> mes("The things that people call")
    |> mes("miracles are made by stimulating")
    |> mes("them or simply altering their arrangement.")
    |> mes("Most of the spells for weather")
    |> mes("changing are included in them and")
    |> mes("they require a high level of comprehension.")
    |> mes("The orders of this world are not simply aligned.")
    |> mes("It is almost impossible to observe")
    |> mes("the smallest and detailed part of")
    |> mes("them and completely understand their structure")
    |> mes("However, it is not that difficult")
    |> mes("to repeat the spells that are already made.")
    |> mes("This thick spell book is for that purpose.")
  end

  defp read_second_feature(ctx) do
    ctx
    |> mes("...The second feature is")
    |> mes("This spell book represents the desire of mankind.")
    |> mes("Their spirit is so great,")
    |> mes("sometimes flames in their hearts")
    |> mes("are embodied and become reality.")
    |> mes("Now, practice one of the spells for weather.")
    |> mes("You have to go to a damp and deserted place,")
    |> mes("and have a pot of melting materials")
    |> mes("along with the spirit of the caster.")
    |> mes("The next spells should be conducted")
    |> mes("through the exact process.")
    |> mes("If you realize that something is")
    |> mes("wrong, you'd MUST stop immediately.")
    |> mes("To prevent the ordinary from")
    |> mes("abusing the magic,")
    |> mes("the narratives of the materials are metaphors,")
    |> mes("but, whoever understands this can")
    |> mes("read everything in it.")
  end
end
