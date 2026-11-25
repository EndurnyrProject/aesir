defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Lyozienswitch do
  @moduledoc """
  A password-protected switch controls Lyozien's availability.

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
        map: "airplane_01",
        x: 10,
        y: 10,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#LyozienSwitch"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo

  @impl true
  def on_talk(ctx) do
    ctx =
      ctx
      |> todo(:callfunc, ["F_GM_NPC"])
      |> mes("[Lyozien Switch]")
      |> mes("Input password.")
      |> mes("Enter 0 to cancel.")
      |> next()

    password_result = Todo.call!(:callfunc, ["F_GM_NPC", 1028, 0, 0, 4000])
    ctx = set_local(ctx, :i, password_result)

    case get_local(ctx, :i, 0) do
      -2 -> ctx |> mes("[Lyozien Switch]") |> mes("Incorrect.") |> close()
      -1 -> ctx |> mes("[Lyozien Switch]") |> mes("Canceled.") |> close()
      0 -> close(ctx)
      _ -> switch_lyozien(ctx)
    end
  end

  defp switch_lyozien(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lyozien Switch]")
      |> mes("Do you want to")
      |> mes("turn the Lyozien")
      |> mes("NPC ON or OFF?")
      |> next()
      |> select(["On", "OFF"])

    case choice do
      1 ->
        ctx
        |> set_local(:"str$", "activated")
        |> donpcevent("Man#Lyozien::OnEnable")
        |> show_result()

      2 ->
        ctx
        |> set_local(:"str$", "deactivated")
        |> donpcevent("Man#Lyozien::OnDisable")
        |> show_result()

      _ ->
        ctx
    end
  end

  defp show_result(ctx) do
    ctx = ctx |> mes("[Lyozien Switch]") |> mes("Lyozien NPC is")

    ctx
    |> mes(Rathena.concat(Rathena.concat("now ", get_local(ctx, :"str$", "")), "."))
    |> mes(" ")
    |> mes("/mm airplane_01.gat 96 48")
    |> close()
  end
end
