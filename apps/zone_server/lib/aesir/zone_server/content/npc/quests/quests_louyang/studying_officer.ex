defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.StudyingOfficer do
  @moduledoc """
  Helps visitors find documents for the doctor's errand.

  ## Behavior

  - Offers different conversations as the errand progresses.
  - Finds the requested document when given its exact name and advances the quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected `checkquest(.@i < 2)` to check whether the quest's state is below 2.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 156,
        y: 38,
        dir: 0,
        sprite: 822,
        name: "Studying Officer",
        scope: :shared,
        unique_name: "Studying Officer#lou"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :ch_par, 0)

    cond do
      progress < 5 -> distracted(ctx)
      progress < 9 -> studying(ctx)
      progress == 9 -> books_at_hall(ctx)
      progress == 10 -> books_at_home(ctx)
      progress < 15 -> request_document(ctx, progress)
      true -> fresh_air(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp distracted(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Huang Zhishu]")
      |> mes(".....")
      |> mes("^666666*Mumble mumble*^000000")
      |> next()
      |> mes("^3355FFHe appears to be")
      |> mes("rummaging around for")
      |> mes("some documents and takes")
      |> mes("no notice of you.^000000")
      |> next()
      |> select(["Excuse me.", "Pass him."])

    if choice == 1 do
      ctx
      |> mes("[Huang Zhishu]")
      |> mes("Hmmm...?")
      |> mes("Well...")
      |> mes("...")
      |> mes("I see...")
      |> mes("^666666*Mumble mumble...*^000000")
      |> close()
    else
      ctx
      |> mes("[Huang Zhishu]")
      |> mes(".........")
      |> mes("^666666*Mumble mumble*^000000")
      |> close()
    end
  end

  defp studying(ctx) do
    ctx
    |> mes("[Huang Zhishu]")
    |> mes("Books contain the spirit and")
    |> mes(
      "ideas of their authors. Any work of art can be considered a window into the soul of its creator."
    )
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes("^666666*Mumble mumble...*^000000")
    |> mes("Hmm... I see...")
    |> mes("Ah, I see....")
    |> mes("^666666*Mumble mumble...*^000000")
    |> close()
  end

  defp books_at_hall(ctx) do
    ctx
    |> mes("[Huang Zhishu]")
    |> mes(
      "A book is more than a mere collection of pages and words are more than simple arrangements of letters that mean nothing."
    )
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes(
      "For humans seeking to enrich their lives, books are an important part of their education, as books can impart various kinds of knowledge."
    )
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes("Read as many books as you can. Without books and the knowledge")
    |> mes("of others, you'll never grasp the essense of life.")
    |> next()
    |> mes("^3355FF*Rummage rummage...*^000000")
    |> close()
  end

  defp books_at_home(ctx) do
    ctx
    |> mes("[Huang Zhishu]")
    |> mes(
      "A book is more than a mere collection of pages and words are more than simple arrangements of letters."
    )
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes(
      "For humans seeking to enrich their lives, books are an important part of their education, as they can impart various kinds of knowledge."
    )
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes(
      "Read as many books as you can. Without books and the knowledge of others, you'll never grasp the essense of life."
    )
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes("^3355FF*Rummage rummage...*^000000")
    |> close()
  end

  defp request_document(ctx, progress) do
    {ctx, choice} =
      ctx
      |> mes("[Huang Zhishu]")
      |> mes("Huh?")
      |> mes("What are you doing here?")
      |> mes("Please don't disturb me,")
      |> mes("I'm trying to study.")
      |> next()
      |> mes("^3355FF*Rummage rummage...*^000000")
      |> next()
      |> select(["Sorry about that.", "I came to pick up my documents."])

    if choice == 1 do
      ctx
      |> mes("[Huang Zhishu]")
      |> mes("Apology accepted.")
      |> mes("Hmmm....")
      |> mes("Oh I see, I see...")
      |> next()
      |> mes("^3355FF*Rummage rummage...*")
      |> mes(".........^000000")
      |> emotion(:surprise)
      |> close()
    else
      ask_document(ctx, progress)
    end
  end

  defp ask_document(ctx, progress) do
    {ctx, input} =
      ctx
      |> mes("[Huang Zhishu]")
      |> mes("Huh?")
      |> mes("Ah...")
      |> mes("You're the one I'm waiting for.")
      |> mes("So what kind of document")
      |> mes("did you need?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", input)

    ctx =
      if {progress, input} in [
           {11, "Residence Transfer Application"},
           {12, "Summer SAT Class Application"},
           {13, "Sandy Dust Phenomenon Report"},
           {14, "Communication Proposal"}
         ] do
        set_local(ctx, :paper, 1)
      else
        ctx
      end

    ctx =
      ctx
      |> mes("[Huang Zhishu]")
      |> mes("Let's see, now.")
      |> mes("You want...")
      |> mes(Rathena.concat(Rathena.concat("a ", get_local(ctx, :"input$", "")), "?"))
      |> next()

    if get_local(ctx, :paper, 0) == 1 do
      find_document(ctx)
    else
      ctx
      |> mes("[Huang Zhishu]")
      |> mes("Huh?")
      |> mes("Wha...?")
      |> next()
      |> mes("[Huang Zhishu]")
      |> mes(
        "I'm sorry but I don't think we have that one. You might want to check the name of the document once"
      )
      |> mes("more, and then ask me again.")
      |> close()
    end
  end

  defp find_document(ctx) do
    ctx
    |> mes("[Huang Zhishu]")
    |> mes(
      Rathena.concat(
        Rathena.concat("Now where did I put that? You want a ", get_local(ctx, :"input$", "")),
        ", huh? I think I'll need some time to find it. Ah, right, I think I know where I put that."
      )
    )
    |> next()
    |> mes("...")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> next()
    |> mes("...")
    |> mes("......")
    |> mes(".........")
    |> mes("............")
    |> mes("...............")
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes("Here it is. A few days ago, someone asked me for the same document,")
    |> mes("so I was able to find it again pretty easily. I hope it's useful to you.")
    |> set_char_var(:ch_par, 15)
    |> complete_document_quests()
    |> setquest(11055)
    |> close()
  end

  defp complete_document_quests(ctx) do
    Enum.reduce(11051..11054, ctx, fn quest_id, ctx ->
      if checkquest(ctx, quest_id) > -1 and checkquest(ctx, quest_id) < 2 do
        completequest(ctx, quest_id)
      else
        ctx
      end
    end)
  end

  defp fresh_air(ctx) do
    ctx
    |> mes("[Huang Zhishu]")
    |> mes("Hmmm...?")
    |> mes(
      "Do you think I need to go outside more often? Well, I guess for some reason, I don't feel well. I guess I really should get some fresh air. ^666666*Yawn...*^000000"
    )
    |> emotion(:ok)
    |> next()
    |> mes("[Huang Zhishu]")
    |> mes(
      "But you should get out more often yourself! It's not a good idea to always stay home. If you don't get some exercise when you're young,"
    )
    |> mes("it could affect your health later.")
    |> close()
  end
end
