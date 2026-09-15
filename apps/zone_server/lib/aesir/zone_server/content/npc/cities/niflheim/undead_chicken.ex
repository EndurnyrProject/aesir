defmodule Aesir.ZoneServer.Content.Npc.Cities.Niflheim.UndeadChicken do
  @moduledoc """
  Bites visitors while celebrating its undead existence.

  ## Behavior

  - Drains five percent of the visitor's HP before speaking.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fyrien
    - Dizzy
    - PKGINGO
    - Celest

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nif_in",
        x: 16,
        y: 27,
        dir: 1,
        sprite: 800,
        name: "Undead Chicken",
        scope: :shared,
        unique_name: "Undead Chicken#nif"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> percent_heal(hp: -5, sp: 0)
      |> mes("[Undead Chicken]")
      |> mes(
        "I lived a peaceful life as a normal chicken. But then came the day I was tragically killed and eaten by humans. Well... Heh heh~! Now it's my turn! *Cackles*"
      )
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ouch...!")
    |> mes("A chicken...")
    |> mes("It bit me!")
    |> next()
    |> mes("[Undead Chicken]")
    |> mes("Ho ho~!")
    |> mes("I can talk AND feast")
    |> mes("on living humans!")
    |> mes("Being a zombie is great!")
    |> mes("*Cackles*")
    |> close()
  end
end
