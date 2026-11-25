defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Anna do
  @moduledoc """
  Anna shares clues about her missing brother Mikhail.

  ## Behavior

  - Discusses the search and directs the player to the inn.

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
        x: 148,
        y: 274,
        dir: 1,
        sprite: 958,
        name: "Anna",
        scope: :shared,
        unique_name: "Anna#mos"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FMos1
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :mos_swan, 0)

    cond do
      not Rathena.truthy?(stage) ->
        {ctx, _} = FMos1.call(ctx, [])
        idle_dialogue(ctx)

      stage == 1 ->
        ctx
        |> mes("[Anna]")
        |> mes("Mikhail, he's a coward, a crybaby.")
        |> mes("Mikhail, he's a coward, a crybaby.")
        |> close()

      stage == 2 ->
        ctx |> mes("[Anna]") |> mes("Why are you here?") |> next() |> ask_anna()

      stage == 3 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes(
          "Ok, I got a clue from Anna and one thing that I have to do is go to ^3131FFInn 'Sticky Herb Tree'^000000."
        )
        |> close()

      stage < 12 ->
        ctx |> mes("[Anna]") |> mes("Mikhail is foolish, timid and a coward!") |> close()

      stage in [25, 100] ->
        ctx =
          ctx
          |> mes("[Anna]")
          |> mes("Mik..ha..il")
          |> mes("He tattled on me to mom...")
          |> next()
          |> mes("[Gallina]")
          |> mes("Anna!")
          |> next()

        ctx = if stage == 100, do: emotion(ctx, :cry), else: ctx
        ctx |> mes("[Anna]") |> mes("....I'm sorry.") |> close()

      true ->
        idle_dialogue(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp idle_dialogue(ctx), do: ctx |> mes("[Anna]") |> mes("....I'm bored.") |> close()

  defp ask_anna(ctx) do
    {ctx, choice} =
      select(ctx, [
        "About where Mikhail might be hiding",
        "About their relationship",
        "About the situation",
        "Ask her about other things",
        "End the conversation"
      ])

    ctx =
      case choice do
        1 ->
          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Where is Mikhail?")
            |> mes("Do you know where he is?")
            |> next()
            |> emotion(:merong)
            |> mes("[Anna]")
            |> mes("If I had known that, I would have already found him, you fool.")
            |> next()

          ctx = emotion(ctx, :sweat, playerattached(ctx))

          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Hahaha, you're right.")

        2 ->
          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("How's your relationship with your brother?")
            |> next()
            |> mes("[Anna]")
            |> mes("Mikhail always stays behind me and asks me to read books!")
            |> mes("And he cries too much.")
            |> mes("It annoys me.")
            |> mes("And he only wants to play with me. That's why he has no friends.")
            |> next()

          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("You seem very courageous.")
          |> mes("I can understand why your mother worries about him.")

        3 ->
          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("What were you doing when Mikhail broke your mother's Matrushka?")
            |> next()
            |> mes("[Anna]")
            |> mes("I was there.")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Oh were you?")
            |> next()
            |> mes("[Anna]")
            |> mes("When my parents were out, they asked me to take care of Mikhail.")
            |> mes(
              "I didn't want to do that but I'm his sister so I was reading a book next to him."
            )
            |> next()
            |> mes("[Anna]")
            |> mes(
              "He began to tease me to read a book for him and later, he annoyed me saying that he's hungry!"
            )
            |> next()
            |> mes("[Anna]")
            |> mes(
              "I was so bothered with him and I pretended not to hear him and kept reading. I guess it made him mad and so he broke the Matrushka."
            )
            |> next()
            |> mes("[Anna]")
            |> mes("He made trouble and began to cry!")
            |> mes("He's such a timid boy...")
            |> mes("(giggling)")
            |> next()
            |> mes("[Anna]")
            |> mes(
              "And then I told him that we should glue the pieces together before Mom came back, so Mikhail went to get ^3131FFpaste^000000 but he hasn't come back yet."
            )
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Where can you get it?")
            |> mes("Why didn't you go with him?")
            |> next()
            |> mes("[Anna]")
            |> mes("Do you think we kids know that?")
            |> mes("He broke it and should get the thing by himself!")
            |> mes(
              "And Mom said that he should do his work for himself to become a great general."
            )
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Don't you have any idea of where he might be?")
            |> next()
            |> mes("[Anna]")
            |> mes("No.")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Is there anyone who is close to him?")
            |> next()
            |> emotion(:hng)
            |> mes("[Anna]")
            |> mes("(giggle) He's a fool and has no friends.")
            |> mes(
              "But among our villagers, the lady of ^3131FFInn 'Sticky Herb Tree'^000000 has held Mikhail dear."
            )
            |> next()
            |> mes("[Anna]")
            |> mes("I have no idea anymore.")
            |> next()
            |> mes("- Anna sticks her tongue out. -")
            |> next()

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("It's the only clue, I guess I'll go to ^3131FFInn 'Sticky Herb Tree'^000000?")

          if get_char_var(ctx, :mos_swan, 0) == 2 do
            ctx |> set_char_var(:mos_swan, 3) |> changequest(18060, 18061)
          else
            ctx
          end

        4 ->
          {ctx, answer} =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("What am I going to ask her?")
            |> next()
            |> input(:string)

          ctx = set_local(ctx, :"AnnaInfo$", answer)

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
            |> mes("Anna,")

          ctx =
            ctx
            |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"AnnaInfo$", "")), "?"))
            |> mes("Do you know what this is?")
            |> next()

          case get_local(ctx, :"AnnaInfo$", "") do
            "Gravity" ->
              ctx
              |> mes("[Anna]")
              |> mes(
                "I know that they have a game called RAGNAROK Online 2... and they like... what am I saying now... right?"
              )

            "Gallina" ->
              ctx
              |> mes("[Anna]")
              |> mes("Mom's hotcakes are so delicious! Oh, it's sweet flavor!")
              |> mes("Everyone in this village likes Mom's hotcakes. Hehe.")

            "Mikhail" ->
              ctx |> mes("[Anna]") |> mes("Mikhail is a timid fool!")

            _ ->
              ctx |> mes("[Anna]") |> mes("I have no idea about that thing.")
          end

        5 ->
          ctx
          |> mes("[Anna]")
          |> mes("Hmm ~ ~ ~ ~ ")
          |> next()
          |> mes("- Anna frowns at me and sticks out her tongue.")
          |> mes("She doesn't want to talk to me -")
          |> close()

        _ ->
          ctx
      end

    if choice in 1..4, do: ctx |> next() |> ask_anna(), else: ctx
  end
end
