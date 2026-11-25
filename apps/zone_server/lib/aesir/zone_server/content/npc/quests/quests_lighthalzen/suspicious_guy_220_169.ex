defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.SuspiciousGuy220169 do
  @moduledoc """
  A pickpocket steals from passersby and may flee.

  ## Behavior

  - Attempts to steal zeny when a player approaches.
  - Moves to another location when caught.

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
        x: 220,
        y: 169,
        dir: 3,
        sprite: 870,
        name: "Suspicious Guy",
        scope: :shared,
        unique_name: "Suspicious Guy#lhz_02",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Suspicious Guy#lhz_02")

  def on_event("OnTouch_", ctx) do
    case Enum.random(1..3) do
      1 -> steal(ctx, 100) |> unnoticed()
      2 -> steal(ctx, 200) |> suspicious()
      3 -> steal(ctx, 10) |> caught()
      _ -> ctx
    end
  end

  defp steal(ctx, amount) do
    ctx = ctx |> mes("^3355FF*SHHHHHHUK!*^000000") |> specialeffect(:steal)
    ctx = if zeny(ctx) >= amount, do: pay_zeny(ctx, amount), else: ctx

    ctx
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Huh...?")
  end

  defp unnoticed(ctx) do
    ctx
    |> mes("I sense something...")
    |> mes("No. It might just")
    |> mes("be my imagination.")
    |> next()
    |> mes("[?????]")
    |> mes("^333333Heh heh heh heh...^000000")
    |> close()
  end

  defp suspicious(ctx) do
    ctx
    |> mes("I could have sworn")
    |> mes("that these pockets full")
    |> mes("of zeny were heavier")
    |> mes("just a second ago...")
    |> next()
    |> mes("[?????]")
    |> mes("^333333Heh heh heh heh...^000000")
    |> close()
  end

  defp caught(ctx) do
    ctx =
      ctx
      |> mes("What the?!")
      |> mes("That guy, did he just...?")
      |> mes("He did! Hey! That guy")
      |> mes("stole some of my money!")
      |> next()
      |> mes("[Suspicious Guy]")
      |> mes("Oh crap!")
      |> mes("Gotta scram!")
      |> mes("Eat my dust, good guy!")

    ctx =
      if Enum.random(1..4) == 1 do
        ctx |> enablenpc("Suspicious Guy#lhz_03") |> disablenpc("Suspicious Guy#lhz_02")
      else
        ctx |> enablenpc("Suspicious Guy#lhz_01") |> disablenpc("Suspicious Guy#lhz_02")
      end

    close(ctx)
  end
end
