defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Guard do
  @moduledoc """
  Guards the entrance to the volcano camp.

  ## Behavior

  - Admits the student during the appropriate investigation stages.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_thor",
        x: 145,
        y: 66,
        dir: 3,
        sprite: 939,
        name: "Guard",
        scope: :shared,
        unique_name: "VeinsGuard",
        hidden_name: "vol"
      },
      %{
        map: "que_thor",
        x: 136,
        y: 66,
        dir: 3,
        sprite: 939,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#vol2"
      },
      %{
        map: "que_thor",
        x: 127,
        y: 60,
        dir: 5,
        sprite: 939,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#vol3"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :aru_vol, 0) do
      11 ->
        ctx =
          ctx
          |> mes("[Guard]")
          |> mes("Only authorized")
          |> mes("personnel can enter this")
          |> mes("area. Identify yourself!")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I'm a research student working")
        |> mes("under Director Gio for the")
        |> mes("Veins Geological Research")
        |> mes("Institute. Would you please")
        |> mes("stamp this temperature")
        |> mes("report for me?")
        |> next()
        |> mes("[Guard]")
        |> mes("Oh, I see. Well, I'm")
        |> mes("not the one that stamps")
        |> mes("reports. Go inside and")
        |> mes("ask Sahedi to help you.")
        |> mes("He's at the airship just")
        |> mes("south of the train station.")
        |> changequest(2120, 2121)
        |> set_char_var(:aru_vol, 12)
        |> close2()
        |> warp("thor_camp", 248, 190)

      stage when stage > 11 and stage < 24 ->
        ctx =
          ctx
          |> mes("[Guard]")
          |> mes("Oh, you're that student")
          |> mes("from the institute. I don't")
          |> mes("think we're expecting")
          |> mes("any reports soon.")
          |> next()

        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oh, we just found out")
        |> mes("that the instruments we")
        |> mes("used were faulty, so we")
        |> mes("had to revise our report.")
        |> next()
        |> mes("[Guard]")
        |> mes("Your tools were broken")
        |> mes("the first time? Okay, okay,")
        |> mes("I can understand that.")
        |> mes("Alright, you can pass.")
        |> close2()
        |> warp("thor_camp", 248, 190)

      _ ->
        ctx |> mes("[Guard]") |> mes("Who are you?!") |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
