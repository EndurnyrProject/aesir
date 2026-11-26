defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Investigator do
  @moduledoc """
  A guild investigator comments on the abandoned Z Gang hideout.

  ## Behavior

  - Changes the conversation according to the investigation stage and the player’s job.

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
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "cmd_in02", x: 94, y: 208, dir: 5, sprite: 828, name: "Investigator", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :diamond_edq, 0) not in [22, 23] ->
        ctx
        |> mes("[Investigator]")
        |> mes("Yeesh, I'm stuck here")
        |> mes("till I receive my new")
        |> mes("orders from the guild.")
        |> mes("They didn't... They didn't")
        |> mes("forget about me, did they?")
        |> close()

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:rogue) ->
        ctx
        |> mes("[Investigator]")
        |> mes("Hey, pal. You part")
        |> mes("of the guild? Nice.")
        |> mes("If they sent you to help")
        |> mes("out, well, there's nothing")
        |> mes("to do here. This place is")
        |> mes("pretty much cleaned out.")
        |> close()

      true ->
        ctx
        |> mes("[Investigator]")
        |> mes("What do you want?")
        |> mes("Oh, your guild musta")
        |> mes("sent you to help out.")
        |> mes("Yeah. We investigated.")
        |> mes("Didn't find anything.")
        |> mes("The Z Gang's long gone.")
        |> next()
        |> mes("[Investigator]")
        |> mes("Feel free to look")
        |> mes("around, but if you ask")
        |> mes("me, it's a waste of time.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
