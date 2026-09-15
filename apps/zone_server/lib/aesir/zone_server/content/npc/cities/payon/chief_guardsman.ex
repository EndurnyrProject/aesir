defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.ChiefGuardsman do
  @moduledoc """
  Disarms visitors who enter the Payon chief's protected chambers.

  ## Behavior

  - Says nothing when spoken to directly.
  - Warns and unequips visitors who enter the guarded area.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad Dib
    - Darkchild
    - DracoRPG
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "payon_in03",
        x: 96,
        y: 116,
        dir: 3,
        sprite: 708,
        name: "Chief Guardsman",
        scope: :shared,
        unique_name: "Chief Guardsman#payon",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx
    |> mes("[Chief Guardsman]")
    |> mes("What brings")
    |> mes("you here? ")
    |> next()
    |> mes("[Chief Guardsman]")
    |> mes(
      "I can see that you are not one of the Payon locals. I would just like to remind you to conduct yourself in an orderly manner. Remember,"
    )
    |> mes("you are a guest here.")
    |> next()
    |> mes("[Chief Guardsman]")
    |> mes(
      "In the interest of protecting the public peace, I will disarm your equipment. Thank you for your cooperation."
    )
    |> nude()
    |> close()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
