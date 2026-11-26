defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.SmallSafe do
  @moduledoc """
  A small safe hides the stolen diamond.

  ## Behavior

  - Reveals a switch during the investigation and awards the diamond once opened.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Fixed the never-true `diamond_edq < 22 && diamond_edq > 24` gate to `diamond_edq > 24`, so
    the emptied safe is described after the diamond is taken and earlier visits keep the
    original fallback.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "cmd_in02", x: 69, y: 188, dir: 1, sprite: 844, name: "Small Safe", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :diamond_edq, 0) == 22 or get_char_var(ctx, :diamond_edq, 0) == 23 ->
        ctx =
          ctx
          |> mes("^3355FFThere is a small")
          |> mes("safe hidden under the")
          |> mes("shadows of these boxes.^000000")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Looks like the Z Gang")
        |> mes("forgot to take this with")
        |> mes("them in their rush to escape.")
        |> mes("Hmmm... How do I open this?")
        |> mes("Is there a key, a switch,")
        |> mes("something I can use?")
        |> hideoffnpc("Odd Switch#Switch1")
        |> close()

      get_char_var(ctx, :diamond_edq, 0) == 24 ->
        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Hey, the safe opened!")
          |> mes("Those switches must have")
          |> mes("done the trick. Now...")
          |> mes("Let's look inside.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Awesome! It's a huge")
          |> mes("red diamond! Is this")
          |> mes("Ibrahim's Diamond")
          |> mes("of Destruction?")
          |> next()
          |> give_item(7723, 1)
          |> mes("[Investigator]")
          |> mes("Zzz... Zzz...")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Lucky for me, this")
        |> mes("guy is asleep. I better")
        |> mes("sneak out of here, and")
        |> mes("return this big diamond")
        |> mes("to Ibrahim as soon as I can.")
        |> changequest(3117, 3118)
        |> set_char_var(:diamond_edq, 25)
        |> close()

      get_char_var(ctx, :diamond_edq, 0) > 24 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("There was something here")
        |> mes("fixed to the ground, but now")
        |> mes("it looks like something yanked")
        |> mes("it out forcefully. How weird.")
        |> close()

      true ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("What is this?")
        |> mes("Oh well, I don't")
        |> mes("think it's important.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
