defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Toilet do
  @moduledoc """
  The museum toilet is part of the ghost's spell and later provides dungeon access.

  ## Behavior

  - Advances the investigation when the spell is followed by three flushes.
  - Transports adventurers after the investigation is complete.

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
        x: 144,
        y: 187,
        dir: 3,
        sprite: 844,
        name: "Toilet",
        scope: :shared,
        unique_name: "Toilet#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "- Looks like an ordinary toilet -")

    cond do
      get_char_var(ctx, :brazil_ghost, 0) > 6 -> ctx |> next() |> dungeon_menu()
      get_char_var(ctx, :brazil_ghost, 0) > 0 -> ctx |> next() |> toilet_menu()
      true -> close(ctx)
    end
  end

  defp dungeon_menu(ctx) do
    {ctx, choice} = select(ctx, ["Flush the toilet.", "Doing nothing."])

    case choice do
      1 ->
        ctx
        |> mes(
          "After flushing the toilet, you suddenly feel dizzy and are suddenly swept away somewhere."
        )
        |> specialeffect2(:waterfall_small_t2_90)
        |> close()
        |> warp("bra_in01", 206, 102)

      2 ->
        ctx |> mes("The water in the toilet looks gross.") |> close()

      _ ->
        ctx
    end
  end

  defp toilet_menu(ctx) do
    {ctx, choice} = select(ctx, ["Use the toilet", "Ignore."])

    case choice do
      1 -> say_spell(ctx)
      2 -> ctx |> mes("You do nothing.") |> close()
      _ -> ctx
    end
  end

  defp say_spell(ctx) do
    {ctx, input} = ctx |> mes("- What was the second line to that spell now? -") |> input(:string)
    ctx = ctx |> set_local(:"input$", input) |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(get_local(ctx, :"input$", ""))
      |> next()
      |> set_local(:"braspell$", "Mother the water is flooding!")

    ctx =
      set_local(
        ctx,
        :chkspell,
        Rathena.compare(get_local(ctx, :"braspell$", ""), get_local(ctx, :"input$", ""))
      )

    cond do
      not Rathena.truthy?(get_local(ctx, :chkspell, 0)) ->
        ctx |> mes("Seems like you said something wrong.") |> close()

      get_char_var(ctx, :brazil_ghost, 0) == 3 ->
        flush_or_close(ctx)

      true ->
        ctx |> mes("Nothing happens.") |> close()
    end
  end

  defp flush_or_close(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sobbing Voice]")
      |> mes("^FF0000If the moon disappears 3 times... don't worry.....^000000")
      |> next()
      |> select(["Flush the toilet.", "Close the lid."])

    case choice do
      1 ->
        flush(ctx)

      2 ->
        ctx
        |> mes("You close the lid of the toilet.")
        |> mes("Nothing seems to be happening.")
        |> close()

      _ ->
        ctx
    end
  end

  defp flush(ctx) do
    {ctx, input} = ctx |> mes("How many times should I flush?") |> input(:int)
    {_, count} = Rathena.input_int(input, 0, 999)
    ctx = ctx |> set_local(:input, count) |> next()

    if get_local(ctx, :input, 0) == 3 do
      ctx
      |> mes("You flush the toilet 3 times.")
      |> next()
      |> mes("qwaaaaaaaaa!")
      |> mes("kwaaaaaaaaaa!")
      |> mes("kwaaaaaaaaaaaaaaaaaaa!")
      |> next()
      |> mes("[Distant Sound]")
      |> mes("^FF0000kkkkhee- hihihihi!!!^000000")
      |> mes("Suddenly the sink sounds like water is flowing freely from it.")
      |> next()
      |> specialeffect2(:venomdust)
      |> mes("Faint laughing can be heard off in the direction of the faucet.")
      |> set_char_var(:brazil_ghost, 4)
      |> changequest(60_351, 60_352)
      |> close()
    else
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("You flush the toilet ", get_local(ctx, :input, 0)),
          " times."
        )
      )
      |> next()
      |> mes("But nothing happens.")
      |> close()
    end
  end
end
