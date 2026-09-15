defmodule Aesir.ZoneServer.Content.Npc.Cities.Niflheim.Gigantia do
  @moduledoc """
  Watches for visitors wearing horns and admonishes them to keep the headgear straight.

  ## Behavior

  - Calls out to nearby visitors wearing one of three horn items.
  - Gives horn-wearing visitors special dialogue when approached.

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
        map: "niflheim",
        x: 195,
        y: 211,
        dir: 6,
        sprite: 796,
        name: "Gigantia",
        scope: :shared,
        unique_name: "Gigantia#nif",
        trigger: {3, 3}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if wearing_horns?(ctx) do
      ctx
      |> mes("[Gigantia]")
      |> mes("Hey, wait!")
      |> close()
    else
      ctx
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if wearing_horns?(ctx) do
      straighten_horns(ctx)
    else
      warn_about_death(ctx)
    end
  end

  defp wearing_horns?(ctx) do
    Rathena.truthy?(is_equipped(ctx, 5038)) or Rathena.truthy?(is_equipped(ctx, 2257)) or
      Rathena.truthy?(is_equipped(ctx, 2256))
  end

  defp straighten_horns(ctx) do
    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("What's up?")
    |> next()
    |> mes("[Gigantia]")
    |> mes("Just...")
    |> mes("Come over here.")
    |> mes("I have something")
    |> mes("I must do for you.")
    |> next()
    |> mes("[Gigantia]")
    |> mes("Your horn is crooked.")
    |> mes("Always make sure your horn")
    |> mes("is worn straight and neat.")
    |> mes("The Lord of Death is always")
    |> mes("looking at you.")
    |> close()
  end

  defp warn_about_death(ctx) do
    ctx
    |> mes("[Gigantia]")
    |> mes("The Lord of Death knows")
    |> mes("and sees all. It's useless")
    |> mes("to hide, and escape from")
    |> mes("Death's sweet embrace.")
    |> close()
  end
end
