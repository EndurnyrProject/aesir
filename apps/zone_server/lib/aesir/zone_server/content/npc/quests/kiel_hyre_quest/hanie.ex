defmodule Aesir.ZoneServer.Content.Npc.Quests.KielHyreQuest.Hanie do
  @moduledoc """
  Hanie explains the Kiel Hyre Academy’s charitable admission policy.

  ## Behavior

  - Describes the academy’s founder and its education of impoverished orphans.

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
        map: "yuno_fild08",
        x: 196,
        y: 196,
        dir: 5,
        sprite: 102,
        name: "Hanie",
        scope: :shared,
        unique_name: "Hanie#kh1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Hanie]")
      |> mes("Oh, I wish I could study")
      |> mes("at the Kiel Hyre Academy...")
      |> mes("All of the graduates get")
      |> mes("really nice jobs! I'm almost")
      |> mes("jealous of the students!")
      |> next()
      |> select(["Kiel Hyre Academy?"])

    ctx
    |> mes("[Hanie]")
    |> mes("Oh, the Kiel Hyre Academy")
    |> mes("is a school founded by Kiel")
    |> mes("Hyre, an inventor that became")
    |> mes("rich from his strange machines.")
    |> mes("He decided to give back to society")
    |> mes("by building this private academy.")
    |> next()
    |> mes("[Hanie]")
    |> mes("However, the school will")
    |> mes("only accept orphans that are")
    |> mes("too poor to enroll in any other")
    |> mes("schools. Sometimes, it makes")
    |> mes("me wish that I was an orphan too!")
    |> mes("Well, not really, but you know...")
    |> close()
  end
end
