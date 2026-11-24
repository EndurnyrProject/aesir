defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Door do
  @moduledoc """
  The museum door is the first step in the ghost's spell.

  ## Behavior

  - Checks the first spell and advances the investigation when the key is turned seven times.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - og2
    - Euphy
    - Capuche
    - Daegaladh

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "bra_in01",
        x: 149,
        y: 184,
        dir: 3,
        sprite: 844,
        name: "Door",
        scope: :shared,
        unique_name: "Door#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "- A key is inserted in the locked door.-")

    if get_char_var(ctx, :brazil_ghost, 0) > 0 do
      {ctx, choice} = ctx |> next() |> select(["Turn the key.", "Ignore it."])

      case choice do
        1 -> say_spell(ctx)
        2 -> ctx |> mes("You do nothing.") |> close()
        _ -> ctx
      end
    else
      close(ctx)
    end
  end

  defp say_spell(ctx) do
    {ctx, input} =
      ctx |> mes("You start saying the first line of the magic words.") |> input(:string)

    ctx = ctx |> set_local(:"input$", input) |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(get_local(ctx, :"input$", ""))
      |> next()
      |> set_local(:"braspell$", "Mother the door won't open!")

    ctx =
      set_local(
        ctx,
        :chkspell,
        Rathena.compare(get_local(ctx, :"braspell$", ""), get_local(ctx, :"input$", ""))
      )

    cond do
      not Rathena.truthy?(get_local(ctx, :chkspell, 0)) ->
        ctx |> mes("Seems like you said something wrong.") |> close()

      get_char_var(ctx, :brazil_ghost, 0) == 2 ->
        unlock_door(ctx)

      true ->
        ctx |> mes("Mother the door won't open!") |> close()
    end
  end

  defp unlock_door(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sobbing Voice]")
      |> mes("'^FF0000Turn the key as many times as there are colors in the rainbow.^000000'")
      |> next()
      |> select(["Open the door", "Knock on the door.", "Turn the key.", "Take the key out."])

    case choice do
      1 -> ctx |> mes("The door is locked.") |> mes("So nothing happens.") |> close()
      2 -> knock(ctx)
      3 -> turn_key(ctx)
      4 -> insert_key(ctx)
      _ -> ctx
    end
  end

  defp knock(ctx) do
    {ctx, input} = ctx |> mes("How many times should I try to knock?") |> input(:int)
    {_, count} = Rathena.input_int(input, 0, 999)
    ctx = ctx |> set_local(:input, count) |> next()

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("You knocked on the door ", get_local(ctx, :input, 0)),
        " times."
      )
    )
    |> next()
    |> mes("But, nothing happens.")
    |> close()
  end

  defp turn_key(ctx) do
    {ctx, input} = ctx |> mes("How many times should I turn the key?") |> input(:int)
    {_, count} = Rathena.input_int(input, 0, 999)
    ctx = ctx |> set_local(:input, count) |> next()

    if get_local(ctx, :input, 0) == 7 do
      ctx
      |> mes("You turn the key 7 times.")
      |> next()
      |> mes("Click! Click! Click!")
      |> mes("Click! Click! Click!")
      |> mes("Click...!")
      |> next()
      |> mes("[Distant Sound]")
      |> mes("^FF0000kkkkhee- hihihihi!!!^000000")
      |> mes("You hear water flushing.")
      |> next()
      |> specialeffect2(:venomdust)
      |> mes("Faint laughing can be heard off in the direction of the toilet.")
      |> set_char_var(:brazil_ghost, 3)
      |> changequest(2208, 60_351)
      |> close()
    else
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("You turned over the key ", get_local(ctx, :input, 0)),
          " times."
        )
      )
      |> next()
      |> mes("But nothing doesn't happened.")
      |> close()
    end
  end

  defp insert_key(ctx) do
    {ctx, input} =
      ctx |> mes("How many times should I insert the key into the door?") |> input(:int)

    {_, count} = Rathena.input_int(input, 0, 999)
    ctx = ctx |> set_local(:input, count) |> next()

    ctx
    |> mes(
      Rathena.concat(
        Rathena.concat("You inserted the key ", get_local(ctx, :input, 0)),
        " times."
      )
    )
    |> next()
    |> mes("But nothing happened.")
    |> close()
  end
end
