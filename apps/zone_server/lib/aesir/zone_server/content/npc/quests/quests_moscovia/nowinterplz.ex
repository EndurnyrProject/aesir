defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Nowinterplz do
  @moduledoc """
  The town center is the site of a seasonal magic ritual.

  ## Behavior

  - At the right quest stage, the medicine is used to change the season.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moscovia",
        x: 224,
        y: 190,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#nowinterplz"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :mos_nowinter, 0) != 19 ->
        ctx

      Rathena.truthy?(count_item(ctx, 7765)) ->
        use_medicine(ctx)

      true ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ah, where did I place")
        |> mes("the magic bottle that Baba Yaga gave to me...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp use_medicine(ctx) do
    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("This place must be")
      |> mes("the center of town...")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ok, let's do it!")
      |> next()
      |> mes("-I drop the magic bottle")
      |> mes("containing Baba Yaga's")
      |> mes("Secret Medicine.-")
      |> delitem(7765, 1)
      |> specialeffect(:barrier)
      |> set_char_var(:mos_nowinter, 20)
      |> changequest(18078, 18079)
      |> next()
      |> mes("-You feel like your")
      |> mes("body is heating up.")
      |> mes("It's much hotter")
      |> mes("than before.-")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I'm sure that the season has changed")
      |> mes("But how can I confirm this?")
      |> next()

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("First I'm going to see the Csar.")
    |> mes("He would like to hear about this.")
    |> close()
  end
end
