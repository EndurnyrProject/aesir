defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Student do
  @moduledoc """
  Laci greets academy visitors and shares rumors about a ghost.

  ## Behavior

  - Greets the player when spoken to.
  - Discusses Aaci’s absence and ghost sighting with Gui Nesha on the touch event.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf (Script)
    - DZeroX (Timer)
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "kh_school",
        x: 57,
        y: 142,
        dir: 6,
        sprite: 893,
        name: "Student",
        scope: :shared,
        unique_name: "Student#kha",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: discuss_ghost(ctx)
  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Laci]")
    |> mes("Oh, wow! We usually")
    |> mes("don't get visitors on")
    |> mes("campus! Um, you're not")
    |> mes("a new faculty member, are you?")
    |> close()
  end

  defp discuss_ghost(ctx) do
    ctx
    |> mes("[Laci]")
    |> mes("Hey, Nesha...!")
    |> mes("have you heard why")
    |> mes("Aaci hasn't been coming")
    |> mes("to class for awhile?")
    |> next()
    |> mes("[Gui Nesha]")
    |> mes("That's right, I haven't")
    |> mes("seen Aaci in awhile.")
    |> mes("Did something happen?")
    |> next()
    |> mes("[Laci]")
    |> mes("It's because....")
    |> mes("Aaci saw a freakin' ghost!")
    |> mes("It's one hundred percent")
    |> mes("true! I heard about it from,")
    |> mes("well, you know, my sources.")
    |> next()
    |> mes("[Gui Nesha]")
    |> mes("...Wha...?")
    |> mes("Oh, come on,")
    |> mes("get outta town.")
    |> close()
  end
end
