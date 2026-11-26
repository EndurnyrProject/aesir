defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.AssassinGuildsman do
  @moduledoc """
  An Assassin Guildsman directs investigators to a poison specialist.

  ## Behavior

  - At the relevant quest stage, sends the player to Marjana; otherwise offers ordinary conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
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
        map: "moc_fild16",
        x: 201,
        y: 295,
        dir: 5,
        sprite: 884,
        name: "Assassin Guildsman",
        scope: :shared,
        unique_name: "Assassin Guildsman#poiso"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :prt_curse, 0) == 23 do
      {ctx, choice} =
        ctx
        |> mes("[Assassin Guildsman]")
        |> mes("What business")
        |> mes("brings you here?")
        |> next()
        |> select(["Poison", "Nothing"])

      if choice == 1 do
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("I need to talk to")
        |> mes("a poison specialist.")
        |> mes("I'm investigating")
        |> mes("something for the")
        |> mes("Prontera Church,")
        |> mes("possibly a murder.")
        |> next()
        |> mes("[Assassin Guildsman]")
        |> mes("...")
        |> mes("......")
        |> mes(".........")
        |> next()
        |> mes("[Assassin Guildsman]")
        |> mes("Listen carefully.")
        |> mes("I will only tell this")
        |> mes("to you one time.")
        |> next()
        |> mes("[Assassin Guildsman]")
        |> mes("There is an")
        |> mes("Assassin's Private Pub")
        |> mes("in the 7 o'clock direction")
        |> mes("in Morocc. Go find someone")
        |> mes("named ^3131FFMarjana^000000 inside.")
        |> set_char_var(:prt_curse, 24)
        |> close()
      else
        ctx
        |> mes("[Assassin Guildsman]")
        |> mes("No. That look in")
        |> mes("your eyes. I'm sure")
        |> mes("there is a reason that")
        |> mes("you have come here...")
        |> close()
      end
    else
      ctx
      |> mes("[Assassin Guildsman]")
      |> mes("It's very dry and")
      |> mes("windy today. I like this")
      |> mes("weather. It feels like it")
      |> mes("perfectly matches the soul")
      |> mes("of a true Assassin, the loner")
      |> mes("that hides in the shadows.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
