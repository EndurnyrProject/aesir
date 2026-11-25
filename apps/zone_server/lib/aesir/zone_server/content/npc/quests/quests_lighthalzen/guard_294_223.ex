defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Guard294223 do
  @moduledoc """
  A guard controls passage between the city and the slums.

  ## Behavior

  - Allows pass holders through and may be evaded when distracted.
  - Triggers a gangster alert after too many intrusions.

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
        map: "lighthalzen",
        x: 294,
        y: 223,
        dir: 7,
        sprite: 868,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#lhz02"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      count_item(ctx, 7350) > 0 ->
        ctx
        |> mes("[Guard]")
        |> mes("Hold it right th--!")
        |> mes("Oh. I'm sorry. I didn't")
        |> mes("realize you were carrying")
        |> mes("a pass and had authorization.")
        |> close2()
        |> warp("lighthalzen", 260, 199)

      get_server_temp_var(ctx, "Lhz_Gangster_Alert", 0) >= 100 ->
        alert(ctx, false)

      get_server_temp_var(ctx, "Lhz_Gangster_Alert", 0) > 14 ->
        alert(ctx, true)

      gettime(ctx, 3) >= 22 or gettime(ctx, 3) < 2 ->
        ctx
        |> mes("[Guard]")
        |> mes("Zzzz... Zzz...")
        |> mes("ZZZzzzzzzzzzz...")
        |> next()
        |> mes("^3355FFThis guard is")
        |> mes("dozing off, so this is")
        |> mes("the perfect opportunity")
        |> mes("to sneak past him.^000000")
        |> sneak_past()

      Enum.random(1..6) == 3 ->
        ctx
        |> mes("^3355FFThe guard seems distracted")
        |> mes("and is looking elsewhere. Now's")
        |> mes("your chance to sneak past him!^000000")
        |> sneak_past()

      true ->
        ctx
        |> mes("[Guard]")
        |> mes("Hold it right there!")
        |> mes("I can't permit anyone to")
        |> mes("enter Uptown Lighthalzen!")
        |> mes("If you don't have a pass,")
        |> mes("then move on out of here!")
        |> close()
    end
  end

  defp alert(ctx, trigger?) do
    ctx =
      ctx
      |> mes("[Guard]")
      |> mes("Recently too many people")
      |> mes("have been traveling between")
      |> mes("Uptown and the ghetto, so")
      |> mes("we've heightened security")
      |> mes("around here. But how can")
      |> mes("so many sneak through us?")

    ctx =
      if trigger? do
        ctx
        |> donpcevent("Law Enforcement::OnEnable")
        |> set_server_temp_var("Lhz_Gangster_Alert", 100)
      else
        ctx
      end

    close(ctx)
  end

  defp sneak_past(ctx) do
    ctx = close2(ctx)

    ctx
    |> set_server_temp_var(
      "Lhz_Gangster_Alert",
      get_server_temp_var(ctx, "Lhz_Gangster_Alert", 0) + 1
    )
    |> warp("lighthalzen", 260, 199)
  end
end
