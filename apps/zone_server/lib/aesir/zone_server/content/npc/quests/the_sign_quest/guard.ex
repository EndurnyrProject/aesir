defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Guard do
  @moduledoc """
  Guards the Alchesh Estate and responds to visitors according to their quest progress.

  ## Behavior

  - Offers information about visiting the master during the relevant quest stage.
  - Changes his greeting as the quest progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 98,
        y: 202,
        dir: 5,
        sprite: 105,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#s10"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx = ctx |> mes("[Hurubu]") |> mes("Welcome to the") |> mes("Alchesh Estate.")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 35 ->
        ctx |> business_greeting() |> close()

      progress < 52 ->
        {ctx, choice} =
          ctx
          |> business_greeting()
          |> next()
          |> select(["I'd like to see Mr. Bakerlan.", "Have a nice day."])

        case choice do
          1 ->
            ctx
            |> mes("[Hurubu]")
            |> mes("Ah, you've")
            |> mes("come to speak")
            |> mes("to the master?")
            |> mes("He's not out on")
            |> mes("business, so you")
            |> mes("can probably see him.")
            |> close()

          2 ->
            ctx |> mes("[Hurubu]") |> mes("Ah...") |> mes("Good day.") |> close()

          _ ->
            ctx
        end

      progress in [97, 98] ->
        ctx
        |> mes("Please leave if")
        |> mes("you do not have")
        |> mes("any business here.")
        |> close()

      true ->
        ctx
        |> mes("Lately, it seems that")
        |> mes("the master is in a good")
        |> mes("mood. I believe that we")
        |> mes("have you to thank for that.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp business_greeting(ctx) do
    ctx
    |> mes("If you have any business")
    |> mes("with the master, please")
    |> mes("let me know.")
  end
end
