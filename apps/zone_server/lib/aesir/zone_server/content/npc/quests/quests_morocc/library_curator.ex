defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.LibraryCurator do
  @moduledoc """
  The library curator helps adventurers search for The Crow of the Fate.

  ## Behavior

  - During the quest, the curator searches by title, author, or keyword and directs successful searches to Juno.

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
        map: "prt_in",
        x: 179,
        y: 92,
        dir: 3,
        sprite: 57,
        name: "Library Curator",
        scope: :shared,
        unique_name: "Library Curator#garas"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :barmunt_crow, 0) do
      0 ->
        greeting(ctx, false)

      1 ->
        offer_search(ctx)

      2 ->
        ctx
        |> mes("[Curator Guys]")
        |> mes(
          "^3131FFThe Crow of the Fate^000000 was sold out even before we got a hold of one copy. You won't be able to find the book anywhere in the Rune-Midgarts Kingdom."
        )
        |> mes("If you really want to read the book, you should try Juno Library.")
        |> close()

      _ ->
        greeting(ctx, true)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx, later?) do
    description =
      if later? do
        "Our library's Monster Encyclopedia has every monster in the Rune-Midgarts Kingdom, categorized by dungeon to help the readers find them easily."
      else
        "Our library's Monster Encyclopedia has every monster in the Rune-Midgarts Kingdom categorized by dungeon, to help our readers find them easily."
      end

    ctx
    |> mes("[Curator Guys]")
    |> mes(description)
    |> mes("We also have many essential books for adventurers. Why don't you take a look?")
    |> next()
    |> mes("[Curator Guys]")
    |> mes("The other library across the street also has Monster Encyclopedias.")
    |> mes("If you're interested, feel free to drop by that library as well.")
    |> close()
  end

  defp offer_search(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Curator Guys]")
      |> mes(
        "Our library's Monster Encyclopedia has every monster in the Rune-Midgarts Kingdom categorized by dungeon, to help our readers find them easily."
      )
      |> mes("We also have many essential books for adventurers. Why don't you take a look?")
      |> next()
      |> select(["Search books.", "Look around the library."])

    case choice do
      1 ->
        search(ctx)

      2 ->
        ctx
        |> mes("[Curator Guys]")
        |> mes("Each book tells you a story of life, wisdom, happiness, and sensation.")
        |> mes(
          "Look around! They are the witnesses of mankind. And everyday, we have new ones joining them."
        )
        |> close()

      _ ->
        ctx
    end
  end

  defp search(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Curator Guys]")
      |> mes("Do you have a specific book in mind?")
      |> mes("No problem, I'm here to assist you.")
      |> mes("What kind of book are you looking for?")
      |> next()
      |> select(["Say the title.", "Say the author.", "Search by keyword."])

    case choice do
      1 -> ask_search(ctx, :title)
      2 -> ask_search(ctx, :author)
      3 -> ask_search(ctx, :keyword)
      _ -> ctx
    end
  end

  defp ask_search(ctx, kind) do
    {ctx, input} = prompt_search(ctx, kind)
    ctx = set_local(ctx, :"input$", input)
    ctx = if kind == :keyword, do: ctx, else: next(ctx)

    {terms, failure} =
      case kind do
        :title ->
          {["The Crow of the Fate"],
           "Hmm... I'm sorry. I've worked at this place for a few decades, but I don't think I've ever seen such a book."}

        :author ->
          {["Oliver Hilpert"],
           "Hmm... I'm sorry. I've worked at this place for a few decades, but I don't think I've ever heard of such an author."}

        :keyword ->
          {["Fate", "Crow", "Oliver", "Hilpert"],
           "Hmm... I'm sorry. I've worked at this place for a few decades, but I don't think I've ever seen a book whose name is even close to the words you said."}
      end

    if Enum.any?(terms, &(Rathena.compare(get_local(ctx, :"input$", ""), &1) == 1)) do
      ctx
      |> mes("[Curator Guys]")
      |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), "...?"))
      |> mes("Alright, let me see...")
      |> next()
      |> found_book()
    else
      ctx |> mes("[Curator Guys]") |> mes(failure) |> close()
    end
  end

  defp prompt_search(ctx, :title) do
    ctx
    |> mes("[Curator Guys]")
    |> mes("Oh, do you know the title?")
    |> mes("Sure, now what's the name?")
    |> input(:string)
  end

  defp prompt_search(ctx, :author) do
    ctx
    |> mes("[Curator Guys]")
    |> mes("Oh, do you know the author?")
    |> mes("Sure, now what's the name?")
    |> input(:string)
  end

  defp prompt_search(ctx, :keyword) do
    ctx
    |> mes("[Curator Guys]")
    |> mes("You must be having a hard time remembering the book's title or author.")
    |> mes("No problem; why don't you tell me at least a little bit of what you remember?")
    |> next()
    |> input(:string)
  end

  defp found_book(ctx) do
    ctx =
      ctx
      |> emotion(:aha)
      |> mes("[Curator Guys]")
      |> mes("Oh, right! I think I know the book:")
      |> next()
      |> mes("[Curator Guys]")
      |> mes("^3131FFOliver Hilpert's")
      |> mes("<The Crow of the Fate>^000000!")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("That's right! That's what I'm looking for!")
    |> next()
    |> mes("[Curator Guys]")
    |> mes("Haha... But I have bad news for you.")
    |> mes(
      "The book has become so popular that you can't even find it from Schwarzwald, the author's country."
    )
    |> mes(
      "We tried to get a hold of the book, but it was too late. It'll take a while for the next editon to be published, so why don't you read a different book for now?"
    )
    |> next()
    |> mes("[Curator Guys]")
    |> mes(
      "If you are not busy and really want to read the book, I have a suggestion: try Juno Library."
    )
    |> mes(
      "You can find every book published in Schwarzwald from the library. Chances are, you'll find it there."
    )
    |> next()
    |> mes("[Curator Guys]")
    |> mes(
      "Well, Juno is quite far from here, but if you're really enthusiastic about reading such a popular book, it should be worthwile."
    )
    |> next()
    |> mes(
      "^660000The book isn't for you, but you believe in 100% customer satisfaction. Let's go to Juno Library now.^000000"
    )
    |> set_char_var(:barmunt_crow, 2)
    |> changequest(2063, 2064)
    |> close()
  end
end
