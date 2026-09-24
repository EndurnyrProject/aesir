defmodule Aesir.ZoneServer.Content.Npc.PreRe.Guides.GuidesAldebaran.Soldier do
  @moduledoc """
  Al De Baran guard who marks the city's facilities on the mini-map.

  ## Behavior

  - Offers to mark six locations at once or ends the conversation with a farewell.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - MasterOfMuppets
    - erKURITA
    - Silent
    - Samuray22
    - Playtester

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "aldebaran",
        x: 139,
        y: 63,
        dir: 4,
        sprite: 105,
        name: "Soldier",
        scope: :pre_renewal,
        unique_name: "Soldier#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("prt_soldier", 2)
      |> mes("[Al De Baran Guard]")
      |> mes("I'm just an ordinary guard")
      |> mes("that you could find in any other city. I don't think I even have a name...")
      |> next()
      |> mes("[Al De Baran Guard]")
      |> mes(
        "I am in charge of the Service Guides from the Al De Baran Garrison. Let me guide you"
      )
      |> mes("through our town!")
      |> next()
      |> select(["Get Location Guide.", "End conversation."])

    case choice do
      1 ->
        ctx
        |> viewpoint(1, 61, 229, 0, 0xFF6633)
        |> viewpoint(1, 72, 197, 1, 0x0000FF)
        |> viewpoint(1, 223, 222, 2, 0x00FFFF)
        |> viewpoint(1, 233, 105, 3, 0x515151)
        |> viewpoint(1, 197, 70, 4, 0x3355FF)
        |> viewpoint(1, 60, 60, 5, 0xFF5555)
        |> mes("^FF6633+^000000 -> Kafra Main Office ")
        |> mes("^0000FF+^000000 -> Weapon Shop ")
        |> mes("^00FFFF+^000000 -> Sorcerer Guild (Closed)")
        |> mes("^515151+^000000 -> Pub")
        |> mes("^3355FF+^000000 -> Item Shop")
        |> mes("^FF5555+^000000 -> Alchemist Guild")
        |> close()
        |> cutin("prt_soldier", 255)

      _ ->
        ctx
        |> mes("[Al De Baran Guard]")
        |> mes(
          "We are sworn to protect Al De Baran! May the forces of evil always be crushed by the"
        )
        |> mes("righteous fist of good!")
        |> close()
        |> cutin("prt_soldier", 255)
    end
  end
end
