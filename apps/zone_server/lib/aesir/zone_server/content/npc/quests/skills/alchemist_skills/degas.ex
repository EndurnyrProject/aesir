defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Degas do
  @moduledoc """
  A Juno researcher who complains about his noisy lab mates and longs for a private laboratory.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG
    - Toms
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in04",
        x: 27,
        y: 107,
        dir: 4,
        sprite: 748,
        name: "Degas",
        scope: :shared,
        unique_name: "Degas#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Degas]")
    |> mes("It's such a pain working")
    |> mes("so close to these other")
    |> mes("scientists. The guy next")
    |> mes("time is always cackling")
    |> mes("about taking over the")
    |> mes("world and whatnot.")
    |> next()
    |> mes("[Degas]")
    |> mes("And this other geek is")
    |> mes("always coughing. Between")
    |> mes("the two of them, it's far too")
    |> mes("noisy to focus on my research!")
    |> mes("If only I could work in my very own private, secret laboratory...")
    |> close()
  end
end
