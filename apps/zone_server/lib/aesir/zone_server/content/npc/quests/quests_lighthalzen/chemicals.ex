defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Chemicals do
  @moduledoc """
  Corrosive chemicals can clean the cube room key.

  ## Behavior

  - Removes rust from the key when the player uses it on the chemicals.

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
        x: 231,
        y: 202,
        dir: 0,
        sprite: 111,
        name: "Chemicals",
        scope: :shared,
        unique_name: "Chemicals#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret03, 0)

    if stage < 2 do
      use_chemicals(ctx, stage)
    else
      ctx
      |> mes("^3355FFThese are the chemicals")
      |> mes("that you used to clean the")
      |> mes("Rusty Key so that it was")
      |> mes("restored to its original glory,")
      |> mes("becoming the ^000000Green Key^3355FF.^000000")
      |> close()
    end
  end

  defp use_chemicals(ctx, stage) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFThere is a bottle")
      |> mes("containing slightly")
      |> mes("corrosive chemicals")
      |> mes("that is sitting on the ledge.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    ctx =
      if stage == 1 and get_local(ctx, :"input$", "") == "Rusty Key" do
        ctx
        |> mes("^3355FFPouring the chemicals")
        |> mes("on the Rusty Key removes")
        |> mes("the rust, making it usable")
        |> mes("again. Now that it is clean,")
        |> mes("the Rusty Key has become")
        |> mes("a sparkling ^000000Green Key^3355FF.^000000")
        |> set_char_var(:lhz_secret03, 2)
      else
        ctx
        |> mes("^3355FFWhatever you tried to")
        |> mes("pour the chemicals on")
        |> mes("wasn't affected at all.")
        |> mes("You should try pouring the")
        |> mes("chemicals on something else.^000000")
      end

    close(ctx)
  end
end
