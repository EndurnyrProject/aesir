defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.Drawer85118 do
  @moduledoc """
  A temple drawer holds the geological reports.

  ## Behavior

  - Lets the player take the report during the investigation or recover a lost copy.

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
        map: "ra_temin",
        x: 85,
        y: 118,
        dir: 3,
        sprite: 111,
        name: "Drawer",
        scope: :shared,
        unique_name: "Drawer#vol3"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :aru_vol, 0) == 4 ->
        inspect_reports(ctx)

      get_char_var(ctx, :aru_vol, 0) == 5 and count_item(ctx, 7342) < 1 ->
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oh! Here's another")
        |> mes("copy of that report")
        |> mes("I wanted! Pretty lucky~")
        |> give_item(7342, 1)
        |> close()

      true ->
        report_description(ctx) |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp inspect_reports(ctx) do
    {ctx, choice} =
      ctx |> report_description() |> next() |> select(["Check the Reports", "Cancel"])

    if choice == 1 do
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Well, it might not to")
        |> mes("the most moral thing,")
        |> mes("but I get the feeling")
        |> mes("that I should at least")
        |> mes("check some of these out.")
        |> next()
        |> mes("^3355FFYou started shuffling")
        |> mes("through the documents,")
        |> mes("glancing at a few that")
        |> mes("catch your interest.^000000")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ooh...")
      |> mes("This might be")
      |> mes("what I'm looking for.")
      |> next()
      |> mes("^3355FFYou take the thick report")
      |> mes("labeled ''Veins Geological")
      |> mes("Research Institute'' on")
      |> mes("the cover, and then you")
      |> mes("close the drawer.^000000")
      |> changequest(2114, 2115)
      |> set_char_var(:aru_vol, 5)
      |> give_item(7342, 1)
      |> close()
    else
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Forget it.")
      |> mes("I didn't get permission")
      |> mes("to look through these files.")
      |> close()
    end
  end

  defp report_description(ctx) do
    ctx
    |> mes("^3355FFYou find a thick pile")
    |> mes("of reports submitted")
    |> mes("to the high priest")
    |> mes("inside this drawer.^000000")
  end
end
