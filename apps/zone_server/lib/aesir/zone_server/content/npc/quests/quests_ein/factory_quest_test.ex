defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.FactoryQuestTest do
  @moduledoc """
  A GM control for the factory quest's pollution state.

  ## Behavior

  - Offers pollution settings and enables the smog alert for authorized GMs.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 127,
        y: 86,
        dir: 3,
        sprite: 851,
        name: "Factory Quest Test",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  alias Aesir.ZoneServer.Script.Todo

  @impl true
  def on_talk(ctx) do
    result = Todo.call!(:callfunc, ["F_GM_NPC", 8028, 0, 0, 9000])
    ctx = set_local(ctx, :i, result)

    case get_local(ctx, :i, 0) do
      -2 ->
        ctx |> mes("[Test1]") |> mes("Boo~ya.") |> close()

      -1 ->
        ctx |> mes("[Test1]") |> mes("Do you want") |> mes("to cancel~?") |> close()

      0 ->
        ctx |> mes("[Test1]") |> mes("Whoa...") |> mes("That is") |> mes("sooo wrong!") |> close()

      _ ->
        choose_pollution(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp choose_pollution(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Test1]")
      |> mes("The current value")
      |> mes("of the global variable")
      |> mes("for the Factory Quest")
      |> mes(
        Rathena.concat(Rathena.concat("is... ^3355FF", get_char_var(ctx, :z, 0)), "^000000.")
      )
      |> mes("You wanna change?")
      |> next()
      |> select(["0", "10", "Invade"])

    case choice do
      1 ->
        ctx
        |> mes("[Test1]")
        |> mes("Okay...!")
        |> mes("It's been")
        |> mes("changed to ''0.''")
        |> set_server_var("EinPolution", 0)
        |> close()

      2 ->
        ctx
        |> mes("[Test2]")
        |> mes("Okay...!")
        |> mes("It's been")
        |> mes("changed to ''10.''")
        |> set_server_var("EinPolution", 10)
        |> close()

      3 ->
        ctx |> donpcevent("Einbroch Smog Alert::OnEnable") |> close()

      _ ->
        ctx
    end
  end
end
