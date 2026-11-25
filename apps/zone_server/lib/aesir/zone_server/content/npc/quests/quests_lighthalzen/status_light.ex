defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.StatusLight do
  @moduledoc """
  A status light conceals a key in the cube room.

  ## Behavior

  - Allows the player to retrieve the key once the generator is off.

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
        x: 244,
        y: 201,
        dir: 0,
        sprite: 111,
        name: "Status Light",
        scope: :shared,
        unique_name: "Status Light#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret01, 0)

    cond do
      stage < 7 ->
        ctx
        |> mes("^3355FFThe Status Light is")
        |> mes("on. It looks like there's")
        |> mes("something inside the")
        |> mes("bulb, but you can't get")
        |> mes("near it since it generates")
        |> mes("incredibly scorching heat.^000000")
        |> next()
        |> mes("^3355FFNow, if you could")
        |> mes("somehow shut down the")
        |> mes("Power Generator in this")
        |> mes("room, the bulb would be")
        |> mes("cool enough for you to touch...^000000")
        |> close()

      stage == 7 ->
        smash_light(ctx)

      true ->
        ctx
        |> mes("^3355FFYou find the remains")
        |> mes("of a broken light bulb.^000000")
        |> close()
    end
  end

  defp smash_light(ctx) do
    {ctx, choice} =
      ctx
      |> mes("The Status Light")
      |> mes("is now off and the")
      |> mes("bulb has cooled down.")
      |> next()
      |> select(["Smash the light bulb.", "Cancel"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("^3355FFYou smash the")
        |> mes("Status Light's bulb")
        |> mes("and discover another key.")
        |> mes("You obtained a ^000000Black Key^3355FF.^000000")
        |> set_char_var(:lhz_secret01, 8)
      else
        ctx
      end

    close(ctx)
  end
end
