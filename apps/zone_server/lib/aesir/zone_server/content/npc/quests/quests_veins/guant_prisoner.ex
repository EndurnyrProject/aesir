defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.GuantPrisoner do
  @moduledoc """
  Ruan discusses prison life and a megaphone.

  ## Behavior

  - Changes his conversation with the investigation stage.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ra_in01",
        x: 58,
        y: 389,
        dir: 0,
        sprite: 929,
        name: "Guant Prisoner",
        scope: :shared,
        unique_name: "Guant Prisoner#sch"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :que_sch, 0)

    cond do
      stage < 11 ->
        ctx |> prison_complaint() |> close()

      stage == 11 ->
        ctx = ctx |> prison_complaint() |> next()

        {ctx, _} =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("What...?!")
          |> next()
          |> select(["Where I can find that Megaphone?"])

        {ctx, _} =
          ctx
          |> mes("[Ruan]")
          |> mes("Huh? Why would you")
          |> mes("want to know that?")
          |> next()
          |> select(["I really need one!"])

        ctx
        |> mes("[Ruan]")
        |> mes("Uh, you can get one from")
        |> mes("that Dancer Job Change")
        |> mes("place in Comodo. They're")
        |> mes("really hard to get, though,")
        |> mes("if not impossible. Knock")
        |> mes("yourself out, buddy.")
        |> close()

      stage < 20 ->
        ctx
        |> mes("[Ruan]")
        |> mes("Nobody knows what")
        |> mes("will happen tomorrow.")
        |> mes("I mean, this is a world of")
        |> mes("miracles and tragedies.")
        |> mes("Death, or real love...")
        |> mes("You will never know what will happen.")
        |> close()

      true ->
        ctx |> mes("[Ruan]") |> mes("........") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp prison_complaint(ctx) do
    ctx
    |> mes("[Ruan]")
    |> mes("This stinks. Why am")
    |> mes("I locked up in here?")
    |> mes("I didn't do anything")
    |> mes("to deserve this!")
    |> next()
    |> mes("[Ruan]")
    |> mes("It's getting to be so")
    |> mes("bad that I even miss the")
    |> mes("sound of Hianna's voice.")
    |> mes("It's freakishly loud.")
    |> mes("You couldn't outyell her")
    |> mes("even with a Megaphone.")
  end
end
