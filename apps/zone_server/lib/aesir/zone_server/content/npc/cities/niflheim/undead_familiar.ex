defmodule Aesir.ZoneServer.Content.Npc.Cities.Niflheim.UndeadFamiliar do
  @moduledoc """
  Drinks visitors' blood and boasts about its undead powers.

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
        y: 30,
        dir: 4,
        sprite: 799,
        name: "Undead Familiar",
        scope: :shared,
        unique_name: "Undead Familiar#nif"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> percent_heal(hp: -5, sp: 0)
      |> mes("[Vatoman]")
      |> mes("Oooh, how handy, a living")
      |> mes("human~! Fresh blood is")
      |> mes("always tasty...! I think I'll just")
      |> mes("take a liiittle sip.")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Ow! My vein!")
    |> mes("Did you just")
    |> mes("suck my blood?!")
    |> next()
    |> mes("[Vatoman]")
    |> mes("Mwahahaha~")
    |> mes("Foolish mortal!")
    |> mes("Beware my powers!")
    |> close()
  end
end
