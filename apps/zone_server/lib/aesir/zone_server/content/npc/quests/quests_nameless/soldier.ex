defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Soldier do
  @moduledoc """
  A soldier discusses the magistrate and the smugglers.

  ## Behavior

  - Advances the monastery investigation after explaining the smugglers' arrest.

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
        map: "ve_in",
        x: 81,
        y: 296,
        dir: 3,
        sprite: 946,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#Aru"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :aru_monas, 0) do
      progress when progress < 9 ->
        ctx
        |> mes("[Himus]")
        |> mes("Huh. The magistrate")
        |> mes("still seems pretty upset")
        |> mes("over the case that happened")
        |> mes("at least a few months ago...")
        |> close()

      9 ->
        explain_smugglers(ctx)

      10 ->
        ctx
        |> mes("[Himus]")
        |> mes("The magistrate is about")
        |> mes("to retire, so I hope he can")
        |> mes("finally quit work and just")
        |> mes("forget about this whole")
        |> mes("business. He does nothing")
        |> mes("but stress out about it!")
        |> close()

      _ ->
        ctx |> mes("[Himus]") |> mes("Nice day, isn't it?") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_smugglers(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Himus]")
      |> mes("Hm? Oh, the magistrate")
      |> mes("gave you the brush-off?")
      |> mes("Well, he hasn't really been")
      |> mes("himself ever since we arrested")
      |> mes("those ^32CD32smugglers coming from")
      |> mes("the south^000000 a few months ago.")
      |> next()
      |> mes("[Himus]")
      |> mes("Once we reported the arrest")
      |> mes("to the temple, the pope's")
      |> mes("soldiers came and took the")
      |> mes("smugglers away. We have no")
      |> mes("clue what happened to them")
      |> mes("or where they even are now.")
      |> next()
      |> mes("[Himus]")
      |> mes("It might not seem like")
      |> mes("a big deal to you, but")
      |> mes("the magistrate is pretty")
      |> mes("meticulous, and he hates")
      |> mes("it when people interfere")
      |> mes("with his job, you know?")
      |> next()
      |> select(["Who are the smugglers?"])

    ctx
    |> mes("[Himus]")
    |> mes("Well, I don't really know.")
    |> mes("Maybe the magistrate would")
    |> mes("know if he was able to finish")
    |> mes("interrogating the smugglers.")
    |> mes("I'm not sure if he did since the smugglers were taken away.")
    |> set_char_var(:aru_monas, 10)
    |> close()
  end
end
