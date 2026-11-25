defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Chest do
  @moduledoc """
  A chest holds a utility axe for the cube room puzzle.

  ## Behavior

  - Lets the player take the axe at the appropriate puzzle stage.

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
        x: 248,
        y: 179,
        dir: 0,
        sprite: 111,
        name: "Chest",
        scope: :shared,
        unique_name: "Chest#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_sincube, 0)

    cond do
      stage < 7 ->
        ctx
        |> mes("^3355FFYou've found a chest")
        |> mes("with an axe laid on")
        |> mes("top. The axe's purpose")
        |> mes("is completely utilitarian")
        |> mes("and isn't suited for battle.^000000")
        |> close()

      stage == 7 ->
        take_axe(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is just a normal")
        |> mes("chest. There used to be")
        |> mes("a utility ^000000Axe^3355FF on top of")
        |> mes("it until you picked it up.^000000")
        |> close()
    end
  end

  defp take_axe(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFYou've found a chest,")
      |> mes("but more importantly,")
      |> mes("there is a utility Axe")
      |> mes("laid on top of it.^000000")
      |> next()
      |> select(["Take the utility Axe.", "Cancel"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("^3355FFWithout shame or")
        |> mes("an ounce of guilt, you")
        |> mes("pick up the utility ^000000Axe^3355FF")
        |> mes("and claim it as your own.^000000")
        |> set_char_var(:lhz_sincube, 8)
      else
        ctx
      end

    close(ctx)
  end
end
