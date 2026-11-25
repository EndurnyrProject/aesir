defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Goblet do
  @moduledoc """
  A goblet hides a rusty key in the cube room.

  ## Behavior

  - Lets the player discover the key before the puzzle progresses.

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
        x: 229,
        y: 184,
        dir: 0,
        sprite: 111,
        name: "Goblet",
        scope: :shared,
        unique_name: "Goblet#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :lhz_sincube, 0) >= 10 ->
        ctx
        |> mes("^3355FFThis is goblet cup where")
        |> mes("you found that ^000000Rusty Key^3355FF.^000000")
        |> close()

      get_char_var(ctx, :lhz_secret03, 0) == 0 ->
        examine_goblet(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is the goblet where")
        |> mes("you found that ^000000Rusty Key^3355FF.^000000")
        |> close()
    end
  end

  defp examine_goblet(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou see an empty")
      |> mes("bottle and a goblet.")
      |> mes("It looks like you")
      |> mes("missed the party.^000000")
      |> next()
      |> select(["Examine the goblet.", "Cancel"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("^3355FFInside the goblet,")
        |> mes("you find a ^000000Rusty Key^3355FF")
        |> mes("which you decide to keep.")
        |> mes("However, you'll need to get")
        |> mes("rid of that rust somehow.")
        |> mes("Perhaps you can dip the key")
        |> mes("in some corrosive chemical?^000000")
        |> set_char_var(:lhz_secret03, 1)
      else
        ctx
      end

    close(ctx)
  end
end
