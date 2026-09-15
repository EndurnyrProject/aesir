defmodule Aesir.ZoneServer.Content.Npc.Cities.Lutie.SantaClaus do
  @moduledoc """
  Welcomes visitors to Lutie and explains how to leave for Al de Baran.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "xmas_in", x: 100, y: 96, dir: 4, sprite: 718, name: "Santa Claus", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Santa Claus]")
    |> mes("Ho Ho Ho~")
    |> mes("Meeeerry Christmas !!")
    |> next()
    |> mes("^3355FFIt's...^000000")
    |> mes("^3355FFIt's the original Santa Claus!^000000")
    |> next()
    |> mes("[Santa Claus]")
    |> mes("Ho Ho Ho~")
    |> mes("I'm Santa Claus, and I bring gifts to every good boy and girl on Christmas!")
    |> next()
    |> mes("[Santa Claus]")
    |> mes(
      "If you want to leave Lutie, go outside town and head south to the first field that you see. You'll be able to find a magical warp that will take you to Al de Baran."
    )
    |> next()
    |> mes("[Santa Claus]")
    |> mes("Ho ho ho~")
    |> mes("Meeeeeeerry Christmas!")
    |> close()
  end
end
