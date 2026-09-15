defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.Soldier do
  @moduledoc """
  Shares different Kunlun shrine stories as the cursed sword quest advances.

  ## Behavior

  - Describes the old shrine before stage seven.
  - Discusses a fast-moving thief during stages seven through nine.
  - Mentions festival delays from stage ten onward.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 166,
        y: 196,
        dir: 3,
        sprite: 780,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#gon"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :b_sword, 0) do
      stage when stage < 7 -> tell_shrine_history(ctx)
      stage when stage > 6 and stage < 10 -> discuss_thief(ctx)
      _ -> discuss_festival_delay(ctx)
    end
  end

  defp tell_shrine_history(ctx) do
    ctx
    |> mes("[Wa Qiu Wu]")
    |> mes("Let me tell you something")
    |> mes("interesting about this place~")
    |> mes("Long ago, this entire area used to be a shrine.")
    |> next()
    |> mes("[Wa Qiu Wu]")
    |> mes("In those days, Taoist hermits")
    |> mes("used to gather here in order to")
    |> mes("reach the Sky Kingdom. However,")
    |> mes("they failed miserably...slowly the monsters began to come...")
    |> close()
  end

  defp discuss_thief(ctx) do
    ctx
    |> mes("[Wa Qiu Wu]")
    |> mes("Don't you think it was quite noisy")
    |> mes("last night? It was all because")
    |> mes("of that thief. He made quite")
    |> mes("a scene...It was so loud that")
    |> mes("I couldn't sleep at all...")
    |> next()
    |> mes("[Wa Qiu Wu]")
    |> mes("Ahh~~~~!")
    |> mes("In the middle of all that")
    |> mes("commotion, I saw")
    |> mes("something running straight")
    |> mes("into the shrine.")
    |> next()
    |> mes("[Wa Qiu Wu]")
    |> mes("It was moving so fast that")
    |> mes("I couldn't even tell what it was.")
    |> mes("From what I could recognize, it")
    |> mes("looked human. I wonder")
    |> mes("what it was...")
    |> next()
    |> mes("[Wa Qiu Wu]")
    |> mes("It might have been the")
    |> mes("thief, but it moved")
    |> mes("so fast, it seemed like")
    |> mes("just a blur.")
    |> close()
  end

  defp discuss_festival_delay(ctx) do
    ctx
    |> mes("[Wa Qiu Wu]")
    |> mes("Let me tell you something")
    |> mes("interesting~ This entire area")
    |> mes("used to be a shrine.")
    |> next()
    |> mes("[Wa Qiu Wu]")
    |> mes("A long time ago, Taoist hermits")
    |> mes("used to gather here in order to")
    |> mes("reach the Sky Kingdom. However,")
    |> mes("they failed miserably...slowly the monsters began to come.")
    |> next()
    |> mes("[Wa Qiu Wu]")
    |> mes("The town is getting ready for the")
    |> mes("Festival, but something is delaying")
    |> mes("it. This has never happened before...")
    |> close()
  end
end
