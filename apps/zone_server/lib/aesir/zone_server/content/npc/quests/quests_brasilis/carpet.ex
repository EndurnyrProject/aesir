defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsBrasilis.Carpet do
  @moduledoc """
  The carpet advances the museum ghost quest when the spell and ritual are correct.

  ## Behavior

  - Prompts for a spell and a carpet ritual during the ghost quest.
  - Advances the quest when the carpet is shaken seven times.

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
        x: 138,
        y: 184,
        dir: 3,
        sprite: 844,
        name: "Carpet",
        scope: :shared,
        unique_name: "Carpet#bra"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :brazil_ghost, 0) > 0 do
      {ctx, choice} =
        ctx
        |> mes("- A carpet with an intricate pattern on it -")
        |> next()
        |> select(["Examine it.", "Ignore."])

      case choice do
        1 ->
          examine(ctx)

        2 ->
          ctx |> mes("You do nothing.") |> close()

        _ ->
          ctx
      end
    else
      ctx |> mes("- A carpet with an intricate pattern on it -") |> close()
    end
  end

  defp examine(ctx) do
    {ctx, spell} =
      ctx |> mes("- What was the next line to that spell now? -") |> input(:string)

    ctx = ctx |> set_local(:"input$", spell) |> next()
    ctx = mes(ctx, "[#{char_name(ctx, 0)}]")

    ctx =
      ctx
      |> mes(get_local(ctx, :"input$", ""))
      |> next()
      |> set_local(:"braspell$", "Mother where are my friends?")

    ctx =
      set_local(
        ctx,
        :chkspell,
        Rathena.compare(get_local(ctx, :"braspell$", ""), get_local(ctx, :"input$", ""))
      )

    cond do
      not Rathena.truthy?(get_local(ctx, :chkspell, 0)) ->
        ctx |> mes("Seems like you said something wrong.") |> close()

      get_char_var(ctx, :brazil_ghost, 0) == 5 ->
        perform_ritual(ctx)

      true ->
        ctx |> mes("Nothing happens.") |> close()
    end
  end

  defp perform_ritual(ctx) do
    {ctx, action} =
      ctx
      |> mes("[Sobbing Voice]")
      |> mes(
        "^FF0000your 7 friends....are...sleeping... now it...'s time ....to wake them........^000000"
      )
      |> next()
      |> select(["Jump on the carpet.", "Lie on the carpet.", "Shake the carpet."])

    case action do
      1 ->
        {ctx, jump_count} = ctx |> mes("How many times should I jump?") |> input(:int)
        {_, bounded_jump_count} = Rathena.input_int(jump_count, 0, 999)
        ctx = ctx |> set_local(:input, bounded_jump_count) |> next()

        ctx
        |> mes("You jump on the carpet #{get_local(ctx, :input, 0)} times.")
        |> next()
        |> mes("But nothing happens.")
        |> close()

      2 ->
        {ctx, lie_count} =
          ctx |> mes("How many times should I lie on the carpet?") |> input(:int)

        {_, bounded_lie_count} = Rathena.input_int(lie_count, 0, 999)
        ctx = ctx |> set_local(:input, bounded_lie_count) |> next()

        ctx
        |> mes("You lie on the carpet #{get_local(ctx, :input, 0)} times.")
        |> next()
        |> mes("But nothing happens.")
        |> close()

      3 ->
        {ctx, shake_count} =
          ctx |> mes("How many times should I shake the carpet?") |> input(:int)

        {_, bounded_shake_count} = Rathena.input_int(shake_count, 0, 999)
        ctx = ctx |> set_local(:input, bounded_shake_count) |> next()

        if get_local(ctx, :input, 0) == 7 do
          ctx
          |> mes("You shake the carpet 7 times.")
          |> next()
          |> mes("- fly~ fly~ fly~ fly~ fly~ fly~ fly~ -")
          |> next()
          |> mes("[Distant Sound]")
          |> mes("^FF0000kkkkhee- hihihihi!!!^000000")
          |> next()
          |> specialeffect2(:venomdust)
          |> mes("Faint laughing can be heard off in the direction of the mirror.")
          |> set_char_var(:brazil_ghost, 6)
          |> changequest(60_353, 60_354)
          |> close()
        else
          ctx
          |> mes(
            Rathena.concat(
              Rathena.concat("You shake the carpet ", get_local(ctx, :input, 0)),
              " times."
            )
          )
          |> next()
          |> mes("But nothing happens.")
          |> close()
        end

      _ ->
        ctx
    end
  end
end
