defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.Liotzburg do
  @moduledoc """
  Liotzburg oversees the Einbroch factory.

  ## Behavior

  - Responds to repair requests and reacts to heavy pollution.

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
        map: "einbroch",
        x: 132,
        y: 84,
        dir: 3,
        sprite: 853,
        name: "Liotzburg",
        scope: :shared,
        unique_name: "Liotzburg#ein",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch_", ctx) do
    react_to_pollution(ctx)
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :EinFactory, 0) == 13 or get_char_var(ctx, :EinFactory, 0) == 14 do
      ctx =
        if isbegin_quest(ctx, 8029) == 1 do
          changequest(ctx, 8029, 8030)
        else
          ctx
        end

      ctx
      |> set_char_var(:EinFactory, 14)
      |> mes("[Liotzburg]")
      |> mes("What...?")
      |> mes("Factory Repair")
      |> mes("budget? No way!")
      |> next()
      |> mes("[Liotzburg]")
      |> mes("Why waste money?")
      |> mes("We haven't had any")
      |> mes("problems so far! Look,")
      |> mes("everything's fine! Why")
      |> mes("are you exaggerating")
      |> mes("such small details?")
      |> next()
      |> mes("[Liotzburg]")
      |> mes("The field overseer,")
      |> mes("Zelmeto, just came by to")
      |> mes("ask for a budget increase.")
      |> mes("Well, I think he's lying!")
      |> mes("Everything's perfect!")
      |> close()
    else
      ctx
      |> mes("[Liotzburg]")
      |> mes("I'm the plant")
      |> mes("superintendant of this")
      |> mes("factory. Most of my employees")
      |> mes(
        "are diligent workers. I can't say that of everyone, but overall we're doing an excellent job. Ha ha ha~!"
      )
      |> next()
      |> mes("[Liotzburg]")
      |> mes("So long as this factory")
      |> mes("is well maintained, we won't")
      |> mes("have to worry about this city's")
      |> mes("safety. The field overseer,")
      |> mes("Zelmeto, is also very reliable.")
      |> next()
      |> mes("[Liotzburg]")
      |> mes("I can trust Zelmeto")
      |> mes("to look after things,")
      |> mes("so there's no need for")
      |> mes("me to go inside the factory.")
      |> mes("Delegating work is great!")
      |> next()
      |> mes("[Liotzburg]")
      |> mes("Our factory will")
      |> mes("continue to develop")
      |> mes("and everyone will be")
      |> mes("proud of the progress")
      |> mes("we're making. Yes, I can")
      |> mes("assure you of that!")
      |> close()
    end
  end

  defp react_to_pollution(ctx) do
    if get_server_var(ctx, "EinPolution", 0) > 9 and
         not Rathena.truthy?(get_server_temp_var(ctx, "AlrdEinPoll", 0)) do
      ctx =
        ctx
        |> mes("[Liotzburg]")
        |> mes("What's going on?!")
        |> mes("Who's responsible?!")
        |> mes("God, I can't believe")
        |> mes("this is happening!")
        |> mes("^333333*Cough Cough!*^000000")
        |> next()
        |> mes("[Liotzburg]")
        |> mes("I need to get out of here!")
        |> mes("You! D-do something and")
        |> mes("fix this! I gotta hide and find")
        |> mes("someplace safe!")
        |> close()

      ctx =
        if get_server_var(ctx, "EinPolution", 0) > 9 and
             not Rathena.truthy?(get_server_temp_var(ctx, "AlrdEinPoll", 0)) do
          ctx |> donpcevent("Einbroch Smog Alert::OnEnable") |> hideonnpc("Liotzburg#ein")
        else
          ctx
        end

      ctx
    else
      ctx
    end
  end
end
