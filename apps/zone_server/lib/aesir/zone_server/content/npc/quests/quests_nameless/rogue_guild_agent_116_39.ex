defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.RogueGuildAgent11639 do
  @moduledoc """
  Reports on the Rogue Guild investigation in Morocc.

  ## Behavior

  - Shares different information as the investigation progresses.
  - Asks the player to report back to the guild.

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
      %{
        map: "morocc",
        x: 116,
        y: 39,
        dir: 3,
        sprite: 779,
        name: "Rogue Guild Agent",
        scope: :shared,
        unique_name: "Rogue Guild Agent#nd4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :rumour_nd, 0) == 1 ->
        ctx
        |> mes("[Agent]")
        |> mes("A case? What are you...?")
        |> mes("Ask somebody else. I don't")
        |> mes("know what you're saying.")
        |> mes("Leave me alone, and")
        |> mes("just let me relax~")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) > 1 and get_char_var(ctx, :rumour_nd, 0) < 20 ->
        ctx
        |> mes("[Agent]")
        |> mes("Ahhh, what'd I do")
        |> mes("for a nice jug of")
        |> mes("frosty beer now~")
        |> mes("...What?")
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 20 ->
        ctx =
          ctx
          |> mes("[Agent]")
          |> mes("Oh, yeah, I'm almost")
          |> mes("done with my investigation.")
          |> next()

        ctx =
          if get_char_var(ctx, :zdan_edq, 0) > 12 do
            ctx
            |> mes("[Agent]")
            |> mes("The Z Gang has been")
            |> mes("causing trouble everywhere.")
            |> mes("It's just mischief, but...")
            |> mes("If I got my hands on them...")
            |> specialeffect(:beginspell)
            |> next()
            |> mes("[Agent]")
            |> mes("Anyway, that gang is")
            |> mes("drawing a lot of flak")
            |> mes("to Morocc. I mean, they")
            |> mes("kind of live here, so...")
            |> next()
          else
            ctx
            |> mes("[Agent]")
            |> mes("I don't know who these")
            |> mes("pranksters are, but once")
            |> mes("I get my hands on them...")
            |> mes("I'm gonna--! I'm gonna--!")
            |> specialeffect(:beginspell)
            |> next()
          end

        ctx
        |> mes("[Agent]")
        |> mes("God, I want a drink.")
        |> mes("Listen, would you just")
        |> mes("go report to the Rogue")
        |> mes("Guild for me? I know it's")
        |> mes("my responsibility, but...")
        |> mes("It's something for you to do.")
        |> next()
        |> mes("[Agent]")
        |> mes("Heh! Keep up")
        |> mes("the good work~")
        |> set_char_var(:rumour_nd, 21)
        |> close()

      get_char_var(ctx, :rumour_nd, 0) == 21 ->
        ctx
        |> mes("[Agent]")
        |> mes("Hurry up, and report")
        |> mes("for me to the Rogue")
        |> mes("Guild. While you do that,")
        |> mes("I think I'll enjoy a drink~")
        |> close()

      true ->
        ctx
        |> mes("[Agent]")
        |> mes("*Hiccup*")
        |> mes("Ahahaha,")
        |> mes("this feels good!")
        |> mes("Good ol' beeeer~")
        |> next()
        |> mes("[Agent]")
        |> mes("*Hiccup*")
        |> next()
        |> mes("[Agent]")
        |> mes("What are you?")
        |> mes("Get lost!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
