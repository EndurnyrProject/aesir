defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.MatureLookingDancer170266 do
  @moduledoc """
  A dancer discusses the performance and returns the bodyguard home.

  ## Behavior

  - Returns the bodyguard to Comodo after the performance.

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
        map: "ein_in01",
        x: 170,
        y: 266,
        dir: 0,
        sprite: 724,
        name: "Mature Looking Dancer",
        scope: :shared,
        unique_name: "Mature Looking Dancer#s3"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :que_sch, 0) do
      stage when stage < 17 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Oh, the dinner")
        |> mes("party isn't finished yet.")
        |> mes("It'll be over before")
        |> mes("you even know it~")
        |> close()

      17 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Well well, it looks like our")
        |> mes("performance was a success.")
        |> mes("The new girls did a really")
        |> mes("great job. So let's head")
        |> mes("back home, shall we?")
        |> close2()
        |> warp("comodo", 191, 146)

      _ ->
        ctx
        |> mes("[Dancer]")
        |> mes("Dancing is so fun, but")
        |> mes("sometimes it's hard to")
        |> mes("keep up with the audience's")
        |> mes("expectations, you know?")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
