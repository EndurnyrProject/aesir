defmodule Aesir.ZoneServer.Content.Npc.Cities.Geffen.Citizen do
  @moduledoc """
  Recounts the tragedy behind an unfinished powerful weapon.

  ## Credits

  - Original from rAthena, authors and Contributors
    - massdriller
    - Nexon
    - MasterOfMuppets
    - Silent
    - Musashiden
    - Evera
    - L0ne_W0lf
    - Lesbian
    - Lupus
    - Samuray22
    - DeadlySilence

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "geffen", x: 203, y: 146, dir: 5, sprite: 97, name: "Citizen", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Citizen]")
    |> mes("There was a skillful weapon smith")
    |> mes("in Al De Baran who had 4 sons.")
    |> mes("Unfortunately he lost all of his sons")
    |> mes("while developing a powerful weapon.")
    |> mes("The father survived alone from the tragedy.")
    |> next()
    |> mes("[Citizen]")
    |> mes("How sad it will be for the father...")
    |> mes("Because of the incident, the weapon smith")
    |> mes("retired from his work and hid himself somewhere.")
    |> mes("After that, no one could ever see")
    |> mes("the powerful weapon that he and his sons were developing.")
    |> next()
    |> mes("[Citizen]")
    |> mes("I don't think that 4 sons of him")
    |> mes("went to the heaven with the anxiety.")
    |> close()
  end
end
