defmodule Aesir.ZoneServer.Content.Npc.Cities.Payon.Guardsman do
  @moduledoc """
  Disarms visitors who enter Payon's Central Palace.

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
        map: "payon",
        x: 158,
        y: 246,
        dir: 3,
        sprite: 708,
        name: "Guardsman",
        scope: :shared,
        unique_name: "Guardsman#payon",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    ctx
    |> mes("[Guardsman]")
    |> mes(
      "This is the Central Palace of Payon. This place is open to the public, but in accordance with our laws, you must behave in an orderly fashion once inside."
    )
    |> next()
    |> mes("[Guardsman]")
    |> mes(
      "In the interest of protecting the peace, we will disarm your equipment once you enter."
    )
    |> mes("Your cooperation is")
    |> mes("much appreciated.")
    |> nude()
    |> close()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
