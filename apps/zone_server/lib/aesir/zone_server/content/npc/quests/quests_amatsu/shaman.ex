defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Shaman do
  @moduledoc """
  Discusses her friend and his interest in mysticism.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in01",
        x: 169,
        y: 173,
        dir: 1,
        sprite: 769,
        name: "Shaman",
        scope: :shared,
        unique_name: "Shaman#ama"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Tokako]")
    |> mes("Er, I'm not really a shaman...")
    |> mes("My friend, Takehue-kun brought")
    |> mes("me here and invited me to try on these clothes.")
    |> next()
    |> mes("[Tokako]")
    |> mes("He asks me to do a lot of")
    |> mes("weird stuff, but he is funny.")
    |> mes("Sometimes, I don't know what")
    |> mes("he is thinking. Still, he is a good friend.")
    |> next()
    |> mes("[Tokako]")
    |> mes("If you are curious about,")
    |> mes("something, ask Takehue-kun.")
    |> mes("He knows stuff about")
    |> mes("mysticism and the occult that other people don't know about.")
    |> mes(" ")
    |> close()
  end
end
