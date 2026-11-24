defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Faucet do
  @moduledoc """
  The museum faucet advances the ghost investigation.

  ## Behavior

  - Accepts the next spell and reveals the carpet clue when turned on once.

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
        x: 134,
        y: 189,
        dir: 3,
        sprite: 844,
        name: "Faucet",
        scope: :shared,
        unique_name: "Faucet#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = mes(ctx, "- It seems like an ordinary faucet -")

    if get_char_var(ctx, :brazil_ghost, 0) > 0 do
      {ctx, choice} = ctx |> next() |> select(["Examine it.", "Ignore."])

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
    {ctx, input} = ctx |> mes("- What was the next line to that spell now? -") |> input(:string)

    ctx = ctx |> set_local(:"input$", input) |> next()

    ctx =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes(get_local(ctx, :"input$", ""))
      |> next()
      |> set_local(:"braspell$", "Mother the drought has started!")

    ctx =
      set_local(
        ctx,
        :chkspell,
        Rathena.compare(get_local(ctx, :"braspell$", ""), get_local(ctx, :"input$", ""))
      )

    cond do
      not Rathena.truthy?(get_local(ctx, :chkspell, 0)) ->
        ctx |> mes("Seems like you said something wrong.") |> close()

      get_char_var(ctx, :brazil_ghost, 0) == 4 ->
        examine_faucet(ctx)

      true ->
        ctx |> mes("Nothing happens.") |> close()
    end
  end

  defp examine_faucet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sobbing Voice]")
      |> mes("^FF0000Don't worry... the waterfall will help it....^000000")
      |> next()
      |> select(["Tap on the faucet.", "Turn on the water."])

    case choice do
      1 -> tap_faucet(ctx)
      2 -> turn_on_water(ctx)
      _ -> ctx
    end
  end

  defp tap_faucet(ctx) do
    {ctx, input} = ctx |> mes("How many times will you tap the faucet?") |> input(:int)
    {_, count} = Rathena.input_int(input, 0, 999)
    ctx = ctx |> set_local(:input, count) |> next()

    ctx
    |> mes(
      Rathena.concat(Rathena.concat("You tap the faucet ", get_local(ctx, :input, 0)), " times.")
    )
    |> next()
    |> mes("But nothing happens.")
    |> close()
  end

  defp turn_on_water(ctx) do
    {ctx, input} = ctx |> mes("How many times should I turn the water on?") |> input(:int)
    {_, count} = Rathena.input_int(input, 0, 999)
    ctx = ctx |> set_local(:input, count) |> next()

    if get_local(ctx, :input, 0) == 1 do
      ctx
      |> mes("You turn the faucet on once.")
      |> next()
      |> mes("swwwaaaaaaa-")
      |> next()
      |> mes("[Distant Sound]")
      |> mes("^FF0000kkkkhee- hihihihi!!!^000000")
      |> mes("You see the carpet move.")
      |> next()
      |> specialeffect2(:venomdust)
      |> mes("Faint laughing can be heard off in the direction of the carpet.")
      |> set_char_var(:brazil_ghost, 5)
      |> changequest(60_352, 60_353)
      |> close()
    else
      ctx
      |> mes(
        Rathena.concat(
          Rathena.concat("You turn the faucet on ", get_local(ctx, :input, 0)),
          " times."
        )
      )
      |> next()
      |> mes("But nothing happens.")
      |> close()
    end
  end
end
