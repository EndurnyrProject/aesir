defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.MatureLookingDancer7955 do
  @moduledoc """
  A dancer accompanies the bodyguard to Einbroch.

  ## Behavior

  - Takes the bodyguard to Einbroch during the trip.

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
        map: "airplane",
        x: 79,
        y: 55,
        dir: 2,
        sprite: 724,
        name: "Mature Looking Dancer",
        scope: :shared,
        unique_name: "Mature Looking Dancer#s2"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :que_sch, 0) do
      stage when stage < 13 ->
        ctx
        |> mes("[Dancer]")
        |> mes("Hi there~")
        |> mes("Are you enjoying")
        |> mes("yourself? I hope so!")
        |> close()

      13 ->
        ctx
        |> mes("[Dancer]")
        |> mes("This is the first time that")
        |> mes("the Schwarzwald Republic")
        |> mes("requested a performance")
        |> mes("from us. Isn't that amazing?")
        |> mes("I guess we earned a reputation")
        |> mes("overseas. I'll do my best!")
        |> next()
        |> mes("[Airship Announcement]")
        |> mes("We will be arriving")
        |> mes("in Einbroch shortly.")
        |> mes("Passengers to Einbroch,")
        |> mes("please get ready to land.")
        |> next()
        |> mes("[Dancer]")
        |> mes("Oh! We're finally here!")
        |> mes("Alright, I'll give this next")
        |> mes("performance my all!")
        |> close2()
        |> set_char_var(:que_sch, 14)
        |> warp("ein_in01", 278, 223)

      _ ->
        ctx
        |> mes("[Dancer]")
        |> mes("I've been dancing on")
        |> mes("stage for a long time, but")
        |> mes("I always feel so nervous")
        |> mes("right beforehand. I wonder")
        |> mes("why that happens to me.")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
