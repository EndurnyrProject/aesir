defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.WantedNotice do
  @moduledoc """
  A wanted notice introduces the hunt for the Z Gang.

  ## Behavior

  - Reading the notice starts the quest, and later interactions reflect its completion.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prontera",
        x: 150,
        y: 326,
        dir: 0,
        sprite: 111,
        name: "Wanted Notice",
        scope: :shared,
        unique_name: "Wanted Notice#edq"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx) do
    enablenpc(ctx, "Wanted Notice#edq")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    disablenpc(ctx, "Wanted Notice#edq")
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :zdan_edq, 0)

    cond do
      progress > 18 -> completed_notice(ctx)
      progress == 0 -> ctx |> notice() |> setquest(3119) |> set_char_var(:zdan_edq, 1) |> close()
      true -> ctx |> notice() |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp notice(ctx) do
    ctx
    |> mes("====National Wanted Notice====")
    |> mes("Please report any information")
    |> mes("regarding these criminals to")
    |> mes("the Rune-Midgarts Kingdom's")
    |> mes("Homeland Security Office.")
    |> next()
    |> mes("====National Wanted Notice====")
    |> mes("^0000ffLouis Von Silokens^000000 - Human Male")
    |> mes("^0000ffMartha Hertizan^000000 - Human Female")
    |> mes("^0000ffCatfoii^000000 - Pet Cat")
    |> next()
    |> mes("====National Wanted Notice====")
    |> mes("These infamous members")
    |> mes("of the Z Gang are suspected")
    |> mes("of stealing national treasure,")
    |> mes("committing fraud, forgery,")
    |> mes("and promoting overall")
    |> mes("depravity and immorality.")
    |> next()
    |> mes("====National Wanted Notice====")
    |> mes("Anyone that captures")
    |> mes("the listed criminals will")
    |> mes("be rewarded with the Book")
    |> mes("of Forbidden Mystery, one")
    |> mes("of the kingdom's treasures.")
  end

  defp completed_notice(ctx) do
    ctx
    |> mes("[Chief Officer]")
    |> mes("Ever since you captured")
    |> mes("the Z Gang, crime has gone")
    |> mes("down to an all time low.")
    |> mes("Thanks for helping us out~")
    |> next()
    |> mes("[Chief Officer]")
    |> mes("Peace never lasts long...")
    |> mes("Some other fiends will")
    |> mes("replace the Z Gang soon.")
    |> mes("When that happens, I hope")
    |> mes("we can count on you again.")
    |> close()
  end
end
