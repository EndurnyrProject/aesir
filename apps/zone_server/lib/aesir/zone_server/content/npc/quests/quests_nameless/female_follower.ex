defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.FemaleFollower do
  @moduledoc """
  Sappie tends the High Priestess’s room.

  ## Behavior

  - Directs the player to the High Priestess during the quest.

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
        map: "ra_temin",
        x: 103,
        y: 151,
        dir: 7,
        sprite: 917,
        name: "Female Follower",
        scope: :shared,
        unique_name: "Female Follower#em"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_em, 0) < 9 ->
        greeting(ctx)
        |> close()

      get_char_var(ctx, :aru_em, 0) == 9 ->
        ctx =
          greeting(ctx)
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Oh, you're right, that")
          |> mes("is a nice smell! So, is")
          |> mes("Priestess Niren away")
          |> mes("from her office today?")
          |> next()
          |> mes("[Sappie]")
          |> mes("Oh, yes, she's out since")
          |> mes("there are many followers")
          |> mes("that wish to meet her,")
          |> mes("even early in the morning.")
          |> next()

        ctx =
          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("Do you know where")
          |> mes("I could find her?")
          |> next()
          |> mes("[Sappie]")
          |> mes("Hm... Sippie mentioned")
          |> mes("something... Ah, right. Sippie")
          |> mes("said that High Priestess Niren")
          |> mes("decided to go to Cheshrumnir")
          |> mes("Garden. That garden is very")
          |> mes("large, and quite beautiful.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("The High Priestess")
        |> mes("must be very busy.")
        |> next()
        |> mes("[Sappie]")
        |> mes("Oh, you can't even imagine!")
        |> mes("She's been passing her wisdom")
        |> mes("to the people ever since she")
        |> mes("was a baby, and crowds of")
        |> mes("people still clamor for")
        |> mes("her sage teachings.")
        |> next()
        |> mes("[Sappie]")
        |> mes("If you really want")
        |> mes("to talk to her, it'd")
        |> mes("be best if you catch her")
        |> mes("before she's surrounded")
        |> mes("by Freya's followers.")
        |> set_char_var(:aru_em, 10)
        |> close()

      get_char_var(ctx, :aru_em, 0) == 10 ->
        ctx
        |> mes("[Sappie]")
        |> mes("High Priestess Niren must")
        |> mes("be in Cheshrumnir Garden.")
        |> mes("You should try to talk to her")
        |> mes("before the crowds show up.")
        |> close()

      get_char_var(ctx, :aru_em, 0) > 21 ->
        ctx
        |> mes("[Sappie]")
        |> mes("It's rumored that the")
        |> mes("Goddess Freya spoke to")
        |> mes("our pope, giving her an")
        |> mes("important message. Now")
        |> mes("everyone wants to hear")
        |> mes("what Freya told her...")
        |> close()

      true ->
        greeting(ctx)
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Sappie]")
    |> mes("I work really hard to keep")
    |> mes("this room clean and cozy so")
    |> mes("that the High Priestess can")
    |> mes("rest and refresh herself in")
    |> mes("comfort. Take a deep breath:")
    |> mes("smell that relaxing aroma?")
  end
end
