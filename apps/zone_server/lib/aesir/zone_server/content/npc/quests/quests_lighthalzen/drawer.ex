defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Drawer do
  @moduledoc """
  A locked drawer contains a jackknife for the cube room puzzle.

  ## Behavior

  - Accepts the red key and advances the puzzle.

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
        x: 242,
        y: 201,
        dir: 0,
        sprite: 111,
        name: "Drawer",
        scope: :shared,
        unique_name: "Drawer#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret01, 0)

    cond do
      stage < 1 ->
        ctx
        |> mes("^3355FFThe drawer here")
        |> mes("looks interesting,")
        |> mes("but it's locked and")
        |> mes("you can't open it.^000000")
        |> close()

      stage == 1 ->
        unlock_drawer(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is the drawer")
        |> mes("in which you found the")
        |> mes("^000000Jackknife^3355FF. It is now empty")
        |> mes("and devoid of purpose.^000000")
        |> close()
    end
  end

  defp unlock_drawer(ctx) do
    {ctx, answer} =
      ctx
      |> mes("^3355FF The drawer here")
      |> mes("looks interesting, but")
      |> mes("it's locked. Hopefully, you")
      |> mes("can figure how to open it.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    ctx =
      if get_local(ctx, :"input$", "") == "Red Key" do
        ctx
        |> mes("^3355FFYou insert the Red Key")
        |> mes("into the lock and open the")
        |> mes("drawer. Inside, you find a")
        |> mes("^000000Jackknife^3355FF that you decide")
        |> mes("to take. After all, it might")
        |> mes("be handy sometime.^000000")
        |> set_char_var(:lhz_secret01, 2)
      else
        ctx
        |> mes("^3355FFUnfortunately, you")
        |> mes("can't open or break")
        |> mes("the lock on the drawer")
        |> mes("by doing that. You need")
        |> mes("to try something else.^000000")
      end

    close(ctx)
  end
end
