defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Student do
  @moduledoc """
  Joey Choryee studies alongside Benkaistein.

  ## Behavior

  - Directs the player to Benkaistein during the friendship quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "yuno_in04", x: 107, y: 14, dir: 5, sprite: 754, name: "Student", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :friendship, 0) do
      stage when stage in [7, 8] ->
        ctx
        |> mes("[Joey Choryee]")
        |> mes("This is a study area where")
        |> mes("you're not supposed to speak,")
        |> mes("walk or even breathe loudly.")
        |> mes("Still, students like Benkaistein can tune out the whole world")
        |> mes("when they study hard enough...")
        |> next()
        |> set_char_var(:friendship, 8)
        |> mes("[Joey Choryee]")
        |> mes("Benkaistein...?")
        |> mes("He's in the north part")
        |> mes("of this room. He's a real")
        |> mes("nice guy, but a little anal.")
        |> mes("Well, he's too organized")
        |> mes("and he labels everything!")
        |> close()

      _ ->
        ctx
        |> mes("[Joey Choryee]")
        |> mes("Property damage. Huh.")
        |> mes("It has to do with lightning")
        |> mes("and fire and water and stuff")
        |> mes("like that? Here I thought it")
        |> mes("meant, I dunno, buildings")
        |> mes("getting wrecked or something.")
        |> close()
    end
  end
end
