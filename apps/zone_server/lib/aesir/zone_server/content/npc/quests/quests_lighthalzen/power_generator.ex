defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.PowerGenerator do
  @moduledoc """
  A power generator controls the cube room status light.

  ## Behavior

  - Lets the player switch off the generator with the yellow key.

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
        x: 224,
        y: 192,
        dir: 0,
        sprite: 111,
        name: "Power Generator",
        scope: :shared,
        unique_name: "Power Generator#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret01, 0)

    if stage <= 6 do
      operate_generator(ctx, stage)
    else
      ctx |> mes("^3355FFIt's a giant machine.^000000") |> close()
    end
  end

  defp operate_generator(ctx, stage) do
    {ctx, answer} =
      ctx
      |> mes("^3355FFThis is a noisily")
      |> mes("operating huge machine")
      |> mes("with a front panel that has")
      |> mes("a strange mark. There is a")
      |> mes("keyhole on the machine")
      |> mes("right next to this panel.^000000")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    ctx =
      if stage == 6 and get_local(ctx, :"input$", "") == "Yellow Key" do
        ctx
        |> mes("^3355FFYou insert the")
        |> mes("Yellow Key into the")
        |> mes("keyhole and turn it,")
        |> mes("causing the machine")
        |> mes("to sputter and deactivate.^000000")
        |> next()
        |> mes("^3355FFYou notice that the")
        |> mes("^000000Status Light ^3355FFnext to the")
        |> mes("bed has now turned off.^000000")
        |> set_char_var(:lhz_secret01, 7)
      else
        ctx
        |> mes("^3355FFNothing happened.")
        |> mes("You probably need")
        |> mes("to find the right key to")
        |> mes("insert into the keyhole.^000000")
      end

    close(ctx)
  end
end
