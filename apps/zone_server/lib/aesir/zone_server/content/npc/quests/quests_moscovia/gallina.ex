defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Gallina do
  @moduledoc """
  Gallina seeks her missing son Mikhail.

  ## Behavior

  - Starts the search and rewards the player after Mikhail returns.

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
        x: 144,
        y: 279,
        dir: 5,
        sprite: 959,
        name: "Gallina",
        scope: :shared,
        unique_name: "Gallina#mos"
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
        |> mes("[Gallina]")
        |> mes("Mikhail, my timid son must still be in this village.")
        |> mes("I'm sorry if he's shy and timid like his father.")
        |> close()

      stage < 25 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Mikhail hasn't come yet?")
        |> next()
        |> mes("[Gallina]")
        |> mes("No, where on earth is he?")
        |> close()

      stage == 25 ->
        reward(ctx)

      true ->
        idle_dialogue(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp idle_dialogue(ctx) do
    ctx
    |> mes("[Gallina]")
    |> mes("I'm always trying to prepare a new dish.")
    |> mes("What do you think of 'the most spicy chili hotcake in the world'?")
    |> mes("I think that will be great!")
    |> close()
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("[Gallina]")
      |> mes("He came back with my Matrushka roughly pasted together and just left...")
      |> next()
      |> mes("[Gallina]")
      |> mes("I'm sorry that I treated the little boy badly.")
      |> mes("He did his best in his own way.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("That's ok. You will be a sweet mom to your little boy. haha")
      |> next()
      |> mes("[Gallina]")
      |> mes("Yes. I'm sure I will. hoho..")
      |> mes(
        "Anna, my daughter made a mistake. She laid the blame upon her brother alone. I'll punish her too."
      )
      |> next()
      |> mes("[Gallina]")
      |> mes("I appreciate your effort. You went to a dangerous place to find my son")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("It often happens to me, hehe.")
      |> next()
      |> mes("[Gallina]")
      |> mes(
        "I can't afford to reward you with much but... I'll let you know how to make a delicious hotcake!"
      )
      |> next()
      |> mes("[Gallina]")
      |> mes("I have to work now but Larissa will tell you about that. She's our maid..")
      |> mes("She's really a nice cook.")
      |> next()
      |> mes("[Gallina]")
      |> mes("Hotcakes of Moscovia are so delicious!")
      |> mes("Once you make it, I bet you that you'll love it.")
      |> next()
      |> mes("[Gallina]")
      |> mes("Well, now I have to get to work!")
      |> mes("I'll make you my hotcakes someday. Please visit me later")
      |> set_char_var(:mos_swan, 100)
      |> completequest(18069)

    ctx
    |> getexp(
      if(Rathena.truthy?(checkre(ctx, 3)), do: 90000, else: 1_000_000),
      0
    )
    |> close()
  end
end
