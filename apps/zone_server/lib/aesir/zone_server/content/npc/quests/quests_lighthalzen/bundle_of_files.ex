defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.BundleOfFiles do
  @moduledoc """
  A bundle of files conceals a key in the cube room.

  ## Behavior

  - Lets the player discover the red key during the puzzle.

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
      %{
        map: "lhz_cube",
        x: 237,
        y: 198,
        dir: 0,
        sprite: 111,
        name: "Bundle of Files",
        scope: :shared,
        unique_name: "Bundle of Files#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_sincube, 0)

    cond do
      stage < 7 ->
        ctx
        |> mes("^3355FFThere are a bunch")
        |> mes("of files scattered")
        |> mes("on the ground.^000000")
        |> close()

      stage < 10 and get_char_var(ctx, :lhz_secret01, 0) < 1 ->
        search_files(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is the place")
        |> mes("where you found the")
        |> mes("^000000Red Key^3355FF while you were")
        |> mes("looking through the files")
        |> mes("scattered on the ground.^000000")
        |> close()
    end
  end

  defp search_files(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThere are a bunch")
      |> mes("of files scattered")
      |> mes("on the ground. They")
      |> mes("seem to contain all")
      |> mes("sorts of information,")
      |> mes("but they're all mixed up.^000000")
      |> next()
      |> select(["Rummage through the files.", "Cancel"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("^3355FFWhile you are")
        |> mes("rummaging through")
        |> mes("the files, a Red Key")
        |> mes("drops to the ground")
        |> mes("with a clink. You decide")
        |> mes("to keep this ^000000Red Key^3355FF.^000000")
        |> set_char_var(:lhz_secret01, 1)
      else
        ctx
      end

    close(ctx)
  end
end
