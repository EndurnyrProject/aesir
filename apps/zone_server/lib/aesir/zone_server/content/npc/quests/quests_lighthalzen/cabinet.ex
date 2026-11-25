defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Cabinet do
  @moduledoc """
  A cabinet holds a polygon for the cube room puzzle.

  ## Behavior

  - Opens a drawer when the player uses the green key.

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
        x: 249,
        y: 191,
        dir: 0,
        sprite: 111,
        name: "Cabinet",
        scope: :shared,
        unique_name: "Cabinet#cube"
      }
    ]

  @impl true
  def on_talk(ctx) do
    stage = get_char_var(ctx, :lhz_secret03, 0)

    cond do
      stage < 2 ->
        locked_cabinet(ctx)

      stage == 2 ->
        unlock_cabinet(ctx)

      true ->
        ctx
        |> mes("^3355FFThis is the locker")
        |> mes("where you used the")
        |> mes("Green Key to open one")
        |> mes("of the Drawers and obtained")
        |> mes("a ^000000Polygon^3355FF. You're pretty happy")
        |> mes("with your Polygon and don't")
        |> mes("need to open the other drawers.^000000")
        |> close()
    end
  end

  defp describe_cabinet(ctx) do
    ctx
    |> mes("^3355FFYou've found a")
    |> mes("cabinet that contains")
    |> mes("many drawers. Perhaps")
    |> mes("something useful is inside?")
    |> next()
  end

  defp locked_cabinet(ctx) do
    {ctx, choice} = ctx |> describe_cabinet() |> select(["Open", "Cancel"])

    ctx =
      if choice == 1 do
        {ctx, answer} = input(ctx, :string)

        ctx
        |> set_local(:"input$", answer)
        |> mes("^3355FFUnfortunately, the")
        |> mes("cabinet has been locked.")
        |> mes("You'll need the right key")
        |> mes("in order to open the drawers.^000000")
      else
        ctx
      end

    close(ctx)
  end

  defp unlock_cabinet(ctx) do
    {ctx, answer} = ctx |> describe_cabinet() |> input(:string)
    ctx = set_local(ctx, :"input$", answer)

    ctx =
      if get_local(ctx, :"input$", "") == "Green Key" do
        ctx
        |> mes("^3355FFYou take the Green Key")
        |> mes("and finds that it fits into")
        |> mes("one of the drawer keyholes.")
        |> mes("You open the drawer and")
        |> mes("obtain a strange ^000000Polygon^3355FF.^000000")
        |> set_char_var(:lhz_secret03, 3)
      else
        ctx
        |> mes("^3355FFWhatever you tried")
        |> mes("did not succeed in")
        |> mes("opening this cabinet.")
        |> mes("Think. Think of how")
        |> mes("locks are unlocked...")
        |> mes("Then you'll find the")
        |> mes("answer you seek.^000000")
      end

    close(ctx)
  end
end
