defmodule Aesir.ZoneServer.Content.Npc.Cities.Comodo.Moo do
  @moduledoc """
  Introduces Moo and the services offered by the Comodo Casino.

  ## Behavior

  - Usually describes the casino and its VIP gaming area.
  - Occasionally threatens cheaters instead.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in02",
        x: 57,
        y: 62,
        dir: 4,
        sprite: 109,
        name: "Moo",
        scope: :shared,
        unique_name: "Moo#cmd"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Moo]")

    if Enum.random(1..10) == 1 do
      threaten_cheaters(ctx)
    else
      welcome_guest(ctx)
    end
  end

  defp threaten_cheaters(ctx) do
    ctx
    |> mes("Those cheating punks!")
    |> mes("They'll never show their")
    |> mes("faces here again: otherwise")
    |> mes("they're gonna hafta get new")
    |> mes("ones! Oh--Sorry, I didn't")
    |> mes("see you there~ Hahahaha~")
    |> close()
  end

  defp welcome_guest(ctx) do
    ctx
    |> mes("Greetings, I am Moo,")
    |> mes("manager of the Comodo")
    |> mes("Casino. We pride ourselves in")
    |> mes("serving all of our customers'")
    |> mes("needs, doing all we can so that your visit here is unforgettable.")
    |> next()
    |> mes("[Moo]")
    |> mes("All of our guests can enjoy")
    |> mes("our general gaming area, and")
    |> mes("we also provide a VIP area")
    |> mes("where high rollers can play")
    |> mes("exciting high stakes games.")
    |> next()
    |> mes("[Moo]")
    |> mes("We always welcome all of")
    |> mes("your suggestions, and are")
    |> mes("always seeking to improve")
    |> mes("your experience here in")
    |> mes("the Comodo Casino.")
    |> close()
  end
end
