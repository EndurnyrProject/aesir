defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.PileOfBooks do
  @moduledoc """
  A pile of research documents in the shared Juno laboratory.

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
        x: 33,
        y: 106,
        dir: 4,
        sprite: 111,
        name: "Pile of Books",
        scope: :shared,
        unique_name: "Pile of Books#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFIt's simply a pile")
    |> mes("of scattered documents.")
    |> mes("Although it seems unorganized,")
    |> mes("it doesn't look like the people")
    |> mes("here have any trouble finding^FFFFFF ^3355FF what they need when they need it.")
    |> close()
  end
end
